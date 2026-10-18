"""Synthetic restored-DB rollback and real SDK reconnection, never production."""
import base64
import concurrent.futures
import hashlib
import hmac
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import urllib.request
import staging as st

REST = 'maskan-recovery-audit-rest'
URL = 'http://127.0.0.1:57321'

def rest_guard():
    st.db_guard(recovery=True)
    d = st.inspect(REST)
    if d['Config']['Labels'].get('maskan.validation') != st.PROJECT:
        raise ValueError('Recovery REST ownership mismatch')
    if set(d['NetworkSettings']['Networks']) != {st.RECOVERY_NETWORK}:
        raise ValueError('Recovery REST network mismatch')
    if d['HostConfig']['PortBindings'] != {'3000/tcp': [{'HostIp':'127.0.0.1','HostPort':'57321'}]}:
        raise ValueError('Recovery REST must bind only its fixed loopback port')

def rollback():
    st.db_guard(recovery=True)
    assert st.sql("select to_regclass('private.recovery_rollback_probe') is null;",recovery=True).stdout.strip()=='t'
    command=['docker','exec','-i',st.RECOVERY,'psql','-XqAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1']
    script="set application_name='maskan_recovery_rollback'; begin; create table private.recovery_rollback_probe(value integer); insert into private.recovery_rollback_probe values(1); select pg_sleep(30); commit;"
    with concurrent.futures.ThreadPoolExecutor(1) as pool:
        pending=pool.submit(st.run,command,input=script,timeout=45,check=False)
        deadline=time.monotonic()+12
        pid=''
        while time.monotonic()<deadline:
            pid=st.sql("select pid from pg_stat_activity where application_name='maskan_recovery_rollback' and wait_event='PgSleep';",recovery=True).stdout.strip()
            if pid:break
            time.sleep(.2)
        assert pid.isdigit(), 'Synthetic transaction checkpoint was not reached'
        st.sql('select pg_terminate_backend('+pid+');',recovery=True)
        assert pending.result(timeout=12).returncode != 0
    assert st.sql("select to_regclass('private.recovery_rollback_probe') is null;",recovery=True).stdout.strip()=='t'

def start_rest():
    st.db_guard(recovery=True)
    existing=st.run(['docker','inspect',REST],check=False)
    if existing.returncode == 0:
        rest_guard();st.run(['docker','start',REST]);return
    creds=json.loads((st.WORK/'recovery-credentials.private.json').read_text())
    env={'PGRST_DB_URI':'postgres://authenticator:'+creds['db_password']+'@'+st.RECOVERY+':5432/postgres',
         'PGRST_DB_SCHEMAS':'public','PGRST_DB_ANON_ROLE':'anon','PGRST_JWT_SECRET':creds['jwt_secret']}
    path=st.WORK/'recovery-rest.private.env'
    path.write_text('\n'.join(k+'='+v for k,v in env.items()))
    source=st.inspect('supabase_rest_'+st.PROJECT)
    st.run(['docker','run','-d','--name',REST,'--label','maskan.validation='+st.PROJECT,
            '--network',st.RECOVERY_NETWORK,'--memory','256m','--cpus','1',
            '-p','127.0.0.1:57321:3000','--env-file',str(path),source['Config']['Image']])
    rest_guard()

def main():
    st.db_guard(recovery=True)
    rollback()
    fixture=json.loads(st.sql("select json_build_object('network',m.network_id,'user',m.auth_user_id,'expenses',(select count(*) from public.expenses e where e.network_id=m.network_id)) from public.network_members m where m.auth_user_id is not null and exists(select 1 from public.expenses e where e.network_id=m.network_id) order by (select count(*) from public.expenses e where e.network_id=m.network_id) asc limit 1;",recovery=True).stdout)
    assert 0 < fixture['expenses'] < 1000
    enc=lambda x:base64.urlsafe_b64encode(json.dumps(x).encode()).decode().rstrip('=')
    body=enc({'alg':'HS256','typ':'JWT'})+'.'+enc({'role':'authenticated','sub':fixture['user'],'exp':int(time.time())+900})
    secret=json.loads((st.WORK/'recovery-credentials.private.json').read_text())['jwt_secret']
    token=body+'.'+base64.urlsafe_b64encode(hmac.new(secret.encode(),body.encode(),hashlib.sha256).digest()).decode().rstrip('=')
    env=st.cli_env()
    env.update({'MASKAN_RECOVERY_URL':URL,'MASKAN_RECOVERY_TOKEN':token,'MASKAN_RECOVERY_NETWORK':fixture['network'],'MASKAN_RECOVERY_EXPENSES':str(fixture['expenses'])})
    results={'interrupted_transaction_rolled_back':True,'restored_database_only':True,'checks':[]}
    start_rest()
    try:
        opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),st.NoRedirect())
        deadline=time.monotonic()+30
        while True:
            try:
                with opener.open(URL+'/',timeout=3) as response:assert response.status==200
                break
            except Exception:
                if time.monotonic()>deadline:raise
                time.sleep(1)
        for label,command,cwd in [
            ('web',['npx','--no-install','tsx','tests/staging/recovery-client.ts'],st.ROOT/'web-dashboard'),
            ('flutter',['flutter','test','--no-pub','test/recovery_client_integration_test.dart'],st.ROOT)]:
            rest_guard()
            command[0]=shutil.which(command[0]+'.bat') or shutil.which(command[0]+'.cmd') or shutil.which(command[0])
            start=time.monotonic()
            r=subprocess.run(command,cwd=cwd,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=300)
            (st.WORK/('recovery-'+label+'.private.log')).write_text(r.stdout+r.stderr,encoding='utf-8')
            results['checks'].append({'client':label,'exit_code':r.returncode,'seconds':round(time.monotonic()-start,2)})
            (st.WORK/'recovery-client-results.json').write_text(json.dumps(results,indent=2))
            print(json.dumps(results['checks'][-1]),flush=True)
            assert r.returncode==0, 'Inspect ignored recovery client log'
    finally:
        rest_guard();st.run(['docker','stop',REST])
    print('PASS restored database rollback, client reconnection and RLS checks')

if __name__=='__main__':main()
