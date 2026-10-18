"""Full synthetic staging dump -> separate recovery container, with parity checks."""
import hashlib
import json
from pathlib import Path
import secrets
import re
import time
import staging as st

SCHEMA_SQL = """
select jsonb_build_object(
 'columns',(select jsonb_agg(x order by x::text) from (select to_jsonb(c) x from information_schema.columns c where table_schema in ('public','private','auth','storage')) q),
 'indexes',(select jsonb_agg(x order by x::text) from (select jsonb_build_array(schemaname,tablename,indexname,indexdef) x from pg_indexes where schemaname in ('public','private','auth','storage')) q),
 'rls',(select jsonb_agg(x order by x::text) from (select jsonb_build_array(n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity,(select jsonb_agg(x order by x::text) from (select jsonb_build_array(pg_get_userbyid(a.grantor),case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,a.privilege_type,a.is_grantable) x from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a) acl)) x from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private','auth','storage') and c.relkind in ('r','v')) q),
 'policies',(select jsonb_agg(x order by x::text) from (select to_jsonb(p) x from pg_policies p where schemaname in ('public','private','auth','storage')) q),
 'functions',(select jsonb_agg(x order by x::text) from (select jsonb_build_array(n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),pg_get_functiondef(p.oid),p.prosecdef,p.proconfig,p.proacl::text,pg_get_userbyid(p.proowner)) x from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prokind='f') q)
);
"""

def snapshot(recovery=False):
    schema=st.sql(SCHEMA_SQL,recovery=recovery).stdout.strip()
    tables=st.sql("select quote_ident(table_schema)||'.'||quote_ident(table_name) from information_schema.tables where table_schema in ('public','private','auth','storage') and table_type='BASE TABLE' order by 1;",recovery=recovery).stdout.splitlines()
    # Compare canonical row digests, never publish row data or tokens.
    queries=[]
    for table in tables:
        queries.append(f"select '{table}' name, count(*)||':'||md5(coalesce(string_agg(to_jsonb(t)::text,E'\\n' order by to_jsonb(t)::text),'')) digest from {table} t")
    digests=json.loads(st.sql('select jsonb_object_agg(name,digest) from ('+' union all '.join(queries)+') q;',recovery=recovery,timeout=60).stdout)
    return {'schema':json.loads(schema),'rows':digests}

def prepare_recovery():
    st.db_guard()
    network=st.run(['docker','network','inspect',st.RECOVERY_NETWORK],check=False)
    if network.returncode:
        st.run(['docker','network','create','--label','maskan.validation='+st.PROJECT,
                '--opt','com.docker.network.bridge.host_binding_ipv4=127.0.0.1',st.RECOVERY_NETWORK])
    else:
        assert json.loads(network.stdout)[0].get('Labels',{}).get('maskan.validation')==st.PROJECT
    existing=st.run(['docker','inspect',st.RECOVERY],check=False)
    if not existing.returncode:
        st.db_guard(recovery=True)
        st.run(['docker','start',st.RECOVERY])
        wait_recovery()
        return
    source=st.inspect(st.DB)
    credfile=st.WORK/'recovery-credentials.private.json'
    creds={'db_password':secrets.token_hex(24),'jwt_secret':secrets.token_hex(32)}
    if credfile.exists(): creds=json.loads(credfile.read_text())
    else: credfile.write_text(json.dumps(creds))
    env={}
    for entry in source['Config']['Env']:
        k,v=entry.split('=',1)
        v=v.replace(st.credentials()['db_password'],creds['db_password']).replace(st.credentials()['jwt_secret'],creds['jwt_secret'])
        env[k]=v
    envfile=st.WORK/'recovery.private.env';envfile.write_text('\n'.join(k+'='+v for k,v in env.items()))
    volume=st.RECOVERY+'-data'
    v=st.run(['docker','volume','inspect',volume],check=False)
    if v.returncode:st.run(['docker','volume','create','--label','maskan.validation='+st.PROJECT,volume])
    else:assert json.loads(v.stdout)[0].get('Labels',{}).get('maskan.validation')==st.PROJECT
    st.run(['docker','run','-d','--name',st.RECOVERY,'--label','maskan.validation='+st.PROJECT,
            '--network',st.RECOVERY_NETWORK,'--memory','1024m','--cpus','1',
            '-p','127.0.0.1:57322:5432','--env-file',str(envfile),
            '-v',volume+':/var/lib/postgresql/data','--entrypoint','sh',source['Config']['Image'],*source['Config']['Cmd']],timeout=90)
    wait_recovery()

def wait_recovery():
    deadline=time.monotonic()+90
    stable=0
    while time.monotonic()<deadline:
        result=st.run(['docker','exec',st.RECOVERY,'psql','-XqAt','-U','supabase_admin','-d','template1','-c',
                      "select count(*) from pg_roles where rolname in ('postgres','anon','authenticated','service_role');"],check=False)
        stable=stable+1 if result.returncode==0 and result.stdout.strip()=='4' else 0
        if stable>=5:
            st.db_guard(recovery=True);return
        time.sleep(2)
    raise TimeoutError('Recovery database initialization did not stabilize')

def main():
    st.db_guard()
    # Stop API writers to obtain a quiescent comparison across dump and snapshots.
    cfg=json.loads(st.COMPOSE.read_text());others=[n for n in cfg['services'] if n!=st.DB]
    st.compose('stop',*others)
    try:
        before=snapshot()
        start=time.monotonic()
        dump=st.run(['docker','exec',st.DB,'pg_dump','-U','supabase_admin','-Fc','postgres'],binary=True,timeout=90).stdout
        (st.WORK/'staging-backup.private.dump').write_bytes(dump)
        dump_seconds=round(time.monotonic()-start,3)
        prepare_recovery()
        roles=st.run(['docker','exec',st.DB,'pg_dumpall','-U','supabase_admin','--roles-only','--no-role-passwords']).stdout
        existing=set(st.sql('select rolname from pg_roles;',recovery=True).stdout.splitlines())
        def create_role(match):
            raw=match.group(1)
            name=raw.strip('"').replace('""','"')
            return '' if name in existing else match.group(0)
        roles=re.sub(r'^CREATE ROLE (.+);$',create_role,roles,flags=re.MULTILINE)
        (st.WORK/'staging-roles.private.sql').write_text(roles)
        st.run(['docker','exec','-i',st.RECOVERY,'psql','-XqAt','-U','supabase_admin','-d','template1','-v','ON_ERROR_STOP=1'],input=roles)
        recovery_password=json.loads((st.WORK/'recovery-credentials.private.json').read_text())['db_password']
        logins=st.sql("select rolname from pg_roles where rolcanlogin and rolname !~ '^pg_';",recovery=True).stdout.splitlines()
        rotate=''.join('ALTER ROLE "'+role.replace('"','""')+'" PASSWORD '+"'"+recovery_password+"';" for role in logins)
        st.run(['docker','exec','-i',st.RECOVERY,'psql','-XqAt','-U','supabase_admin','-d','template1','-v','ON_ERROR_STOP=1'],input='BEGIN;'+rotate+'COMMIT;')
        st.sql("select pg_terminate_backend(pid) from pg_stat_activity where datname='postgres' and pid<>pg_backend_pid();",recovery=True,database='template1')
        st.sql('DROP DATABASE postgres WITH (FORCE); CREATE DATABASE postgres OWNER postgres;',recovery=True,database='template1')
        start=time.monotonic()
        st.run(['docker','exec','-i',st.RECOVERY,'pg_restore','-U','supabase_admin','-d','postgres','--exit-on-error'],input=dump,binary=True,timeout=120)
        restore_seconds=round(time.monotonic()-start,3)
        after=snapshot(recovery=True)
        # Save only parity metadata. On failure, retain digests for diagnosis, not rows.
        equal={k:before[k]==after[k] for k in before}
        if not all(equal.values()):
            (st.WORK/'restore-comparison.private.json').write_text(json.dumps({'before':before,'after':after},indent=2))
        assert all(equal.values()),'Backup/restore parity failed'
        totals=st.sql("select json_build_object('expenses',count(*),'amount_cents',coalesce(sum(amount_cents),0),'archived',count(*) filter(where archived_at is not null)) from public.expenses;").stdout.strip()
        cycles=int(st.sql('select count(*) from public.expense_cycles;').stdout.strip())
        result={'backup_bytes':len(dump),'backup_sha256':hashlib.sha256(dump).hexdigest(),
                'dump_seconds':dump_seconds,'restore_seconds':restore_seconds,'tables_compared':len(before['rows']),
                'schema_indexes_rls_function_privileges_equal':equal['schema'],'all_row_digests_equal':equal['rows'],
                'financial_totals':json.loads(totals),'cycles':cycles,'recovery_port':57322}
        (st.WORK/'backup-results.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
    finally:
        st.compose('start',*others)
        st.wait_ready()
if __name__=='__main__':main()
