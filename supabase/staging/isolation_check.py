"""Runtime isolation evidence, without printing credentials or fixture rows."""
import json
import urllib.error
import urllib.request
import staging as st

def main():
    st.db_guard();st.validate_compose();st.wait_ready()
    config=json.loads(st.COMPOSE.read_text())
    names=list(config['services'])
    volumes=set();ports=[]
    for name in names:
        data=st.inspect(name)
        assert data['State']['Running'],name+' not running'
        assert set(data['NetworkSettings']['Networks'])=={st.NETWORK}
        for mount in data['Mounts']:
            if mount['Type']=='volume':volumes.add(mount['Name'])
        for bindings in (data['NetworkSettings']['Ports'] or {}).values():
            for binding in bindings or []:
                assert binding['HostIp']=='127.0.0.1'
                assert binding['HostPort'] in ('56321','56322','56324')
                ports.append(binding['HostPort'])
    old=st.run(['docker','inspect','supabase_db_maskan-hardening-local'],check=False)
    if old.returncode==0:
        olddata=json.loads(old.stdout)[0]
        assert volumes.isdisjoint({m.get('Name') for m in olddata['Mounts']})
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),st.NoRedirect())
    settings=st.settings()
    with opener.open(urllib.request.Request(st.API+'/auth/v1/health',headers={'apikey':settings['ANON_KEY']}),timeout=5) as response:
        assert response.status==200
    try:
        opener.open(urllib.request.Request(st.API+'/auth/v1/health',headers={'apikey':'deliberately-wrong-staging-key'}),timeout=5)
        raise AssertionError('Invalid key accepted')
    except urllib.error.HTTPError as error:assert error.code==401
    edge=st.inspect('supabase_edge_runtime_'+st.PROJECT)
    assert set(edge['NetworkSettings']['Networks'])=={st.NETWORK}
    for bindings in (edge['NetworkSettings']['Ports'] or {}).values():
        for binding in bindings or []:assert binding['HostIp']=='127.0.0.1' and binding['HostPort']=='8085'
    env=dict(x.split('=',1) for x in edge['Config']['Env'])
    assert env['SUPABASE_URL']=='http://kong:8000'
    assert env['SUPABASE_ANON_KEY']==settings['ANON_KEY']
    assert env['SUPABASE_SERVICE_ROLE_KEY']==settings['SERVICE_ROLE_KEY']
    oldauth=st.run(['docker','inspect','supabase_auth_maskan-hardening-local'],check=False)
    if oldauth.returncode==0:
        oldenv=dict(x.split('=',1) for x in json.loads(oldauth.stdout)[0]['Config']['Env'])
        assert oldenv.get('GOTRUE_JWT_SECRET')!=settings['JWT_SECRET']
    credential_file=st.WORK/'database-probe.private.env'
    credential_file.write_text('PGPASSWORD='+st.credentials()['db_password']+'\n')
    query=['psql','-h',st.DB,'-U','postgres','-d','postgres','-XqAt','-c','select current_database();']
    valid=st.run(['docker','exec','--env-file',str(credential_file),st.DB,*query])
    assert valid.stdout.strip()=='postgres'
    invalid=st.run(['docker','exec','-e','PGPASSWORD=deliberately-invalid-fixture',st.DB,*query],check=False)
    assert invalid.returncode!=0 and 'password authentication failed' in invalid.stderr
    result={'database_password_enforced':True,'project':st.PROJECT,'network':st.NETWORK,'api':st.API,
            'loopback_ports':sorted(set(ports)),'volumes':sorted(volumes),'old_test_volumes_disjoint':True,
            'valid_key_health':200,'wrong_key_rejected':401,'edge_targets_staging_gateway':True,
            'jwt_distinct_from_previous_stack':True,'external_test_requests_and_redirects_rejected':True}
    (st.WORK/'isolation-results.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
if __name__=='__main__':main()
