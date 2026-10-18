"""Offline-only staging lifecycle. No caller-selected URLs, projects or SQL paths.
All credentials, dumps and generated Compose config stay in .codex_tmp.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import hmac
import json
import os
import re
import secrets
import shutil
import subprocess
import time
import tomllib
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.codex_tmp' / 'maskan-staging-validation'
PROJECT = 'maskan-staging-validation'
NETWORK = 'maskan-staging-validation-network'
DB = 'supabase_db_' + PROJECT
RECOVERY = 'maskan-staging-recovery'
RECOVERY_NETWORK = RECOVERY + '-network'
API = 'http://127.0.0.1:56321'
PRODUCTION = 'skngodvomygvxemfaefn'
MIGRATION = '20261017194224_harden_expense_cycles_and_reset_workflows.sql'
COMPOSE = WORK / 'compose.private.json'
SECRETS = WORK / 'credentials.private.json'
NPX = shutil.which('npx.cmd') or shutil.which('npx')

def run(args, *, input=None, timeout=120, check=True, binary=False, env=None):
    result = subprocess.run(args, input=input, capture_output=True, text=not binary,
                            timeout=timeout, env=env)
    if check and result.returncode:
        # Errors may contain connection credentials. Persist locally, never echo them.
        WORK.mkdir(parents=True, exist_ok=True)
        data = result.stdout + result.stderr if binary else (result.stdout + result.stderr).encode('utf-8')
        (WORK / 'last-error.private.log').write_bytes(data)
        raise RuntimeError('Local command failed; inspect ignored last-error.private.log')
    return result

def docker_guard():
    if os.environ.get('DOCKER_HOST') and not os.environ['DOCKER_HOST'].startswith(('npipe:////./pipe/', 'unix:///')):
        raise ValueError('Remote Docker is forbidden')
    context = json.loads(run(['docker', 'context', 'inspect']).stdout)[0]
    if not context['Endpoints']['docker']['Host'].startswith(('npipe:////./pipe/', 'unix:///')):
        raise ValueError('Remote Docker context is forbidden')

def target_guard(project=PROJECT, url=API):
    if project != PROJECT or url != API or PRODUCTION in project + url:
        raise ValueError('Only the fixed isolated staging project and URL are allowed')
    if WORK.resolve() != ROOT.resolve() / '.codex_tmp' / PROJECT:
        raise ValueError('Unexpected staging workspace or symlink')
    if (WORK / 'supabase' / '.temp' / 'project-ref').exists():
        raise ValueError('Linked projects are forbidden in staging')
    if (WORK / 'supabase' / 'config.toml').exists():
        config = tomllib.loads((WORK / 'supabase/config.toml').read_text())
        if config['project_id'] != PROJECT or config['api']['port'] != 56321 or config['db']['port'] != 56322:
            raise ValueError('Staging config identity/ports changed')
        if 'remotes' in config:
            raise ValueError('Remote config overrides forbidden')
    docker_guard()

def inspect(name):
    return json.loads(run(['docker', 'inspect', name]).stdout)[0]

def db_guard(recovery=False):
    target_guard()
    name = RECOVERY if recovery else DB
    data = inspect(name)
    labels = data['Config'].get('Labels') or {}
    if labels.get('maskan.validation') != PROJECT:
        raise ValueError('Container does not belong to staging')
    mounts = [m for m in data['Mounts'] if m['Destination'].startswith('/var/lib/postgresql')]
    if not mounts or any(PROJECT not in m.get('Name', '') and RECOVERY not in m.get('Name', '') for m in mounts):
        raise ValueError('Unexpected database volume')
    if set(data['NetworkSettings']['Networks']) != {RECOVERY_NETWORK if recovery else NETWORK}:
        raise ValueError('Unexpected Docker network')
    for bindings in (data['HostConfig']['PortBindings'] or {}).values():
        for binding in bindings or []:
            if binding['HostIp']!='127.0.0.1' or binding['HostPort'] not in ('56322','57322'):
                raise ValueError('Database port is not staging loopback only')

    return name

def sql(statement, *, recovery=False, database='postgres', timeout=30, check=True):
    name = db_guard(recovery)
    if database not in ('postgres', 'template1'):
        raise ValueError('Unexpected database')
    return run(['docker', 'exec', '-i', name, 'psql', '-XqAt', '-U', 'supabase_admin' if database=='template1' else 'postgres', '-d', database,
                '-v', 'ON_ERROR_STOP=1'], input=statement, timeout=timeout, check=check)

def credentials():
    data = json.loads(SECRETS.read_text())
    if 'anon_key' not in data:
        enc = lambda x: base64.urlsafe_b64encode(json.dumps(x, separators=(',', ':')).encode()).decode().rstrip('=')
        for key, role in [('anon_key', 'anon'), ('service_role_key', 'service_role')]:
            body = enc({'alg':'HS256','typ':'JWT'})+'.'+enc({'iss':'supabase-demo','role':role,'exp':1983812996})
            data[key] = body+'.'+base64.urlsafe_b64encode(hmac.new(data['jwt_secret'].encode(),body.encode(),hashlib.sha256).digest()).decode().rstrip('=')
        SECRETS.write_text(json.dumps(data))
    return data

def cli_env():
    # Never inherit a linked project, cloud token, DB URL, proxy, or CLI override.
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith(('SUPABASE_', 'MASKAN_'))
           and k.upper() not in ('DATABASE_URL', 'PGHOST', 'PGPORT', 'PGPASSWORD', 'PGDATABASE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')}
    for k, v in credentials().items():
        env['MASKAN_STAGING_' + k.upper()] = v
    return env

def cli(*args, timeout=300):
    target_guard()
    # Private call site allowlist, no generic CLI passthrough.
    if args not in (('start','--exclude','studio,postgres-meta,logflare,vector,supavisor,imgproxy,edge-runtime'), ('status','--output','json'), ('functions','serve')):
        raise ValueError('CLI action forbidden; use guarded lifecycle commands')
    result = run([NPX, '--yes', 'supabase@2.115.0', *args, '--workdir', str(WORK), '--network-id', NETWORK],
                 timeout=timeout, env=cli_env())
    (WORK / ('cli-' + args[0] + '.private.log')).write_text(result.stdout + result.stderr)
    return result

def initialize():
    target_guard()
    WORK.mkdir(parents=True, exist_ok=True)
    if not SECRETS.exists():
        SECRETS.write_text(json.dumps({
            'jwt_secret': secrets.token_hex(32), 'db_password': secrets.token_hex(24),
            'root_key': secrets.token_hex(32), 'secret_key': 'sb_secret_' + secrets.token_urlsafe(32),
            'publishable_key': 'sb_publishable_' + secrets.token_urlsafe(32),
        }))
    config = '''project_id = "maskan-staging-validation"
[api]
port = 56321
schemas = ["public", "graphql_public"]
extra_search_path = ["public", "extensions"]
max_rows = 1000
[db]
port = 56322
shadow_port = 56320
major_version = 17
root_key = "env(MASKAN_STAGING_ROOT_KEY)"
[db.seed]
enabled = false
[studio]
enabled = false
[local_smtp]
port = 56324
[auth]
site_url = "http://127.0.0.1:3200"
additional_redirect_urls = ["http://127.0.0.1:3200"]
jwt_secret = "env(MASKAN_STAGING_JWT_SECRET)"
anon_key = "env(MASKAN_STAGING_ANON_KEY)"
service_role_key = "env(MASKAN_STAGING_SERVICE_ROLE_KEY)"
secret_key = "env(MASKAN_STAGING_SECRET_KEY)"
publishable_key = "env(MASKAN_STAGING_PUBLISHABLE_KEY)"
[auth.email]
enable_confirmations = false
[edge_runtime]
inspector_port = 8085
[functions.maskan-delete-account]
verify_jwt = false
[analytics]
enabled = false
'''
    (WORK / 'supabase/migrations').mkdir(parents=True, exist_ok=True)
    (WORK / 'supabase/config.toml').write_text(config)
    shutil.copytree(ROOT / 'supabase/functions', WORK / 'supabase/functions', dirs_exist_ok=True)
    existing = run(['docker', 'network', 'inspect', NETWORK], check=False)
    if existing.returncode:
        run(['docker', 'network', 'create', '--label', 'maskan.validation=' + PROJECT,
             '--opt', 'com.docker.network.bridge.host_binding_ipv4=127.0.0.1', NETWORK])
    network = json.loads(run(['docker', 'network', 'inspect', NETWORK]).stdout)[0]
    if network.get('Labels', {}).get('maskan.validation') != PROJECT:
        raise ValueError('Unexpected network; refusing to reuse it')
    print('Staging workspace initialized; credentials remain private.')


def validate_compose():
    data=json.loads(COMPOSE.read_text())
    if set(data['networks'])!={NETWORK}: raise ValueError('Unexpected Compose network')
    for name, service in data['services'].items():
        if not name.startswith('supabase_') or not name.endswith('_'+PROJECT) or service['container_name']!=name:
            raise ValueError('Unexpected Compose container')
        if set(service['networks'])!={NETWORK} or service['labels'].get('maskan.validation')!=PROJECT:
            raise ValueError('Unexpected Compose ownership')
        for port in service.get('ports',[]):
            if not re.fullmatch(r'127\.0\.0\.1:5632[124]:[0-9]+/tcp',port):
                raise ValueError('Unexpected published port')
        for mount in service.get('volumes',[]):
            source=mount['source']
            if mount['type']=='volume' and not source.endswith('_'+PROJECT):
                raise ValueError('Unexpected volume')
            if mount['type']=='bind' and not Path(source).resolve().is_relative_to(WORK.resolve()):
                raise ValueError('Unexpected bind mount')
    network=json.loads(run(['docker','network','inspect',NETWORK]).stdout)[0]
    if network.get('Labels',{}).get('maskan.validation')!=PROJECT:
        raise ValueError('Unexpected network ownership')

def compose(*args, timeout=180):
    target_guard()
    validate_compose()
    return run(['docker', 'compose', '-p', PROJECT, '-f', str(COMPOSE), *args], timeout=timeout)

def bootstrap():
    initialize()
    if COMPOSE.exists():
        repair_compose(); compose('up', '-d'); wait_ready(); save_bootstrap(); start_existing_edge(); return
    # Bootstrap EMPTY infrastructure only. Historical/app migrations are applied later.
    if any((WORK / 'supabase/migrations').iterdir()):
        raise ValueError('Bootstrap migration directory must be empty')
    if run(['docker', 'inspect', DB], check=False).returncode != 0:
        cli('start', '--exclude', 'studio,postgres-meta,logflare,vector,supavisor,imgproxy,edge-runtime')
    # CLI does not expose a configurable DB password. Materialize its pinned local
    # containers as private Compose, replacing the shared development DB credentials.
    names = run(['docker', 'ps', '-a', '--filter', 'label=com.supabase.cli.project=' + PROJECT,
                 '--format', '{{.Names}}']).stdout.splitlines()
    if DB not in names or any(not n.endswith('_' + PROJECT) for n in names):
        raise ValueError('Unexpected bootstrap container set')
    password = credentials()['db_password']
    roles = run(['docker', 'exec', '-i', DB, 'psql', '-XqAt', '-U', 'postgres'],
                input="select rolname from pg_roles where rolcanlogin and rolname !~ '^pg_';").stdout.splitlines()
    alter = ''.join('ALTER ROLE "' + role.replace('"', '""') + '" PASSWORD ' + "'" + password + "';\n" for role in roles)
    run(['docker', 'exec', '-i', DB, 'psql', '-XqAt', '-U', 'supabase_admin', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'], input='BEGIN;'+alter+'COMMIT;')
    services, volumes = {}, {}
    for name in names:
        data = inspect(name)
        if set(data['NetworkSettings']['Networks']) != {NETWORK}:
            raise ValueError('Unexpected bootstrap network')
        cfg = data['Config']
        env = {}
        for entry in cfg['Env']:
            key, value = entry.split('=', 1)
            value = value.replace(':postgres@', ':' + password + '@')
            if 'PASSWORD' in key and value == 'postgres': value = password
            env[key] = value
        mounts = []
        for m in data['Mounts']:
            if m['Type'] == 'volume':
                if PROJECT not in m['Name']: raise ValueError('Non-staging volume')
                volumes[m['Name']] = {'external': True}
                mounts.append({'type': 'volume', 'source': m['Name'], 'target': m['Destination']})
            elif m['Type'] == 'bind':
                # CLI uses Windows host paths mounted into the shared daemon.
                if PROJECT not in m['Source']: raise ValueError('Non-staging bind mount')
                mounts.append({'type': 'bind', 'source': m['Source'], 'target': m['Destination'], 'read_only': not m['RW']})
        ports = []
        for target, bindings in (data['HostConfig']['PortBindings'] or {}).items():
            for binding in bindings or []:
                if binding['HostIp'] in ('', '0.0.0.0', '127.0.0.1'):
                    ports.append('127.0.0.1:' + binding['HostPort'] + ':' + target)
        service = {'image': cfg['Image'], 'container_name': name, 'environment': env,
                   'networks': {NETWORK: {'aliases': [name]}}, 'volumes': mounts,
                   'ports': ports, 'labels': {'maskan.validation': PROJECT},
                   'mem_limit': '1024m' if name == DB else '512m', 'cpus': 1.5 if name == DB else 1,
                   'restart': 'no'}
        for source, destination in [('Entrypoint', 'entrypoint'), ('Cmd', 'command'), ('User', 'user'), ('WorkingDir', 'working_dir')]:
            if cfg.get(source): service[destination] = cfg[source]
        if cfg.get('Healthcheck'):
            h = cfg['Healthcheck']
            service['healthcheck'] = {'test': h['Test'], 'interval': '5s', 'timeout': '5s', 'retries': 30}
        services[name] = service
    COMPOSE.write_text(json.dumps({'services': services, 'volumes': volumes,
                                   'networks': {NETWORK: {'external': True}}}, indent=2).replace('$', '$$'))
    run(['docker', 'stop', *names], timeout=120)
    run(['docker', 'rm', *names])
    repair_compose()
    compose('up', '-d')
    wait_ready()
    save_bootstrap()

def start_existing_edge():
    name='supabase_edge_runtime_'+PROJECT
    if run(['docker','inspect',name],check=False).returncode != 0: return
    data=inspect(name)
    if (data['Config'].get('Labels') or {}).get('com.supabase.cli.project')!=PROJECT or set(data['NetworkSettings']['Networks'])!={NETWORK}:
        raise ValueError('Unexpected Edge ownership/network')
    run(['docker','update','--memory','768m','--memory-swap','768m','--cpus','1',name])
    run(['docker','start',name])

def save_bootstrap():
    if (WORK / 'bootstrap.private.dump').exists(): return
    dump = run(['docker', 'exec', DB, 'pg_dump', '-U', 'supabase_admin', '-Fc', 'postgres'], binary=True)
    (WORK / 'bootstrap.private.dump').write_bytes(dump.stdout)
    print('Empty staging bootstrap saved with unique database/API credentials.')

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise ValueError('External redirects are forbidden in staging')

def wait_ready():
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        r = run(['docker', 'exec', DB, 'pg_isready', '-U', 'postgres'], check=False)
        if r.returncode == 0:
            db_guard(); break
        time.sleep(2)
    else: raise TimeoutError('Staging database did not become ready')
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    while time.monotonic()<deadline:
        try:
            request=urllib.request.Request(API+'/auth/v1/health',headers={'apikey':credentials()['anon_key']})
            with opener.open(request,timeout=3) as response:
                if response.status==200: return
        except (OSError, urllib.error.URLError): pass
        time.sleep(2)
    raise TimeoutError('Staging API did not become healthy')

def settings():
    db_guard()
    data = credentials()
    return {'API_URL': API, 'ANON_KEY': data['anon_key'], 'SERVICE_ROLE_KEY': data['service_role_key'], 'JWT_SECRET': data['jwt_secret']}

def repair_compose():
    data=json.loads(COMPOSE.read_text())
    creds=credentials()
    # Declarative local gateway: every route stays on the dedicated Docker network.
    routes=[('auth','auth',9999,'/auth/v1',''),('rest','rest',3000,'/rest/v1',''),
            ('storage','storage',5000,'/storage/v1',''),('functions','edge_runtime',8081,'/functions/v1',''),
            ('realtime','realtime',4000,'/realtime/v1','/socket')]
    gateway={'_format_version':'2.1','consumers':[
        {'username':'anon','keyauth_credentials':[{'key':creds['anon_key']}]},
        {'username':'service_role','keyauth_credentials':[{'key':creds['service_role_key']}]}],
        'plugins':[{'name':'cors'}], 'services':[]}
    for label,service,port,path,target in routes:
        gateway['services'].append({'name':label,'url':f'http://'+('realtime-dev.supabase-realtime' if service=='realtime' else f'supabase_{service}_{PROJECT}')+f':{port}{target}',
            'routes':[{'name':label,'paths':[path],'strip_path':True}],
            'plugins':[{'name':'key-auth','config':{'hide_credentials':False}}]})
    gateway_path=WORK/'gateway.private.json';gateway_path.write_text(json.dumps(gateway))
    for name, service in data['services'].items():
        service['networks'][NETWORK]['aliases']=[name,name.removeprefix('supabase_').removesuffix('_'+PROJECT)]
        if name=='supabase_realtime_'+PROJECT: service['networks'][NETWORK]['aliases'].append('realtime-dev.supabase-realtime')
        if name!=DB: service['depends_on']={DB:{'condition':'service_healthy'}}
        if name=='supabase_kong_'+PROJECT:
            service['environment'].pop('KONG_SSL_CERT',None)
            service['environment'].pop('KONG_SSL_CERT_KEY',None)
            service['environment']['KONG_PLUGINS']='cors,key-auth'
            service['environment']['KONG_DECLARATIVE_CONFIG']='/home/kong/kong.json'
            service['entrypoint']=['/docker-entrypoint.sh']
            service['command']=['kong','docker-start']
            service['volumes']=[{'type':'bind','source':str(gateway_path),'target':'/home/kong/kong.json','read_only':True}]
    data['services']['supabase_kong_'+PROJECT]['labels']['maskan.gateway.sha256']=hashlib.sha256(gateway_path.read_bytes()).hexdigest()
    COMPOSE.write_text(json.dumps(data,indent=2))


def reset(baseline=False):
    db_guard()
    config = json.loads(COMPOSE.read_text())
    others = [n for n in config['services'] if n != DB]
    compose('stop', *others)
    edge = 'supabase_edge_runtime_' + PROJECT
    if run(['docker', 'inspect', edge], check=False).returncode == 0:
        run(['docker', 'stop', edge])
    try:
        sql("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='postgres' AND pid<>pg_backend_pid();", database='template1')
        sql('DROP DATABASE postgres WITH (FORCE); CREATE DATABASE postgres OWNER postgres;', database='template1')
        dump = (WORK / 'bootstrap.private.dump').read_bytes()
        run(['docker', 'exec', '-i', DB, 'pg_restore', '-U', 'supabase_admin', '-d', 'postgres', '--exit-on-error'], input=dump, binary=True)
        timings = []
        for path in sorted((ROOT / 'supabase/migrations').glob('*.sql')):
            if baseline and path.name >= MIGRATION: break
            start = time.monotonic()
            sql(path.read_text(encoding='utf-8'), timeout=120)
            timings.append({'migration': path.name, 'seconds': round(time.monotonic()-start, 3)})
        (WORK / ('baseline-timings.json' if baseline else 'clean-timings.json')).write_text(json.dumps(timings, indent=2))
        print(json.dumps(timings))
    finally:
        compose('start', *others)

def summary():
    db_guard()
    data = inspect(DB)
    print(json.dumps({'project': PROJECT, 'api': API, 'database_port': 56322,
                      'network': NETWORK, 'volumes': [m.get('Name') for m in data['Mounts'] if m['Type']=='volume'],
                      'credential_fingerprint': hashlib.sha256(credentials()['jwt_secret'].encode()).hexdigest()[:12]}, indent=2))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['start','stop','reset','reset-baseline','inspect','serve'])
    args = parser.parse_args()
    target_guard()
    if args.action == 'start': bootstrap()
    elif args.action == 'stop':
        db_guard(); compose('stop')
        edge = 'supabase_edge_runtime_' + PROJECT
        if run(['docker','inspect',edge],check=False).returncode == 0: run(['docker','stop',edge])
        if run(['docker','inspect',RECOVERY],check=False).returncode == 0:
            db_guard(recovery=True); run(['docker','stop',RECOVERY])
    elif args.action in ('reset','reset-baseline'): reset(args.action == 'reset-baseline')
    elif args.action == 'inspect': summary()
    else: cli('functions','serve', timeout=43200)

if __name__ == '__main__': main()
