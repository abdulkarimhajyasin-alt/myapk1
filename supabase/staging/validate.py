"""Bounded real staging rehearsals; no arbitrary connection parameters."""
import argparse
import base64
import concurrent.futures
import hashlib
import hmac
import json
import math
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
import staging as st

sys.path.insert(0, str(st.ROOT / 'supabase/tests'))
import backend_hardening as backend

def setup():
    backend.configure_staging()
    return st.settings()

def record(name, value):
    path = st.WORK / (name + '.json')
    path.write_text(json.dumps(value, indent=2))
    print(json.dumps(value, indent=2), flush=True)

def apply_migration():
    start=time.monotonic()
    result=st.sql((st.ROOT/'supabase/migrations'/st.MIGRATION).read_text(), timeout=90, check=False)
    return result, round(time.monotonic()-start,3)

def interrupted_transaction(statement, marker):
    st.db_guard()
    command=['docker','exec','-i',st.DB,'psql','-XqAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1']
    # Application name makes termination target exact; no user sessions are touched.
    script=f"set application_name='{marker}'; begin; {statement} select pg_sleep(30); commit;"
    with concurrent.futures.ThreadPoolExecutor(1) as pool:
        pending=pool.submit(st.run,command,input=script,timeout=45,check=False)
        deadline=time.monotonic()+12
        pid=''
        while time.monotonic()<deadline:
            pid=st.sql(f"select pid from pg_stat_activity where application_name='{marker}' and wait_event='PgSleep';").stdout.strip()
            if pid: break
            time.sleep(.1)
        if not pid: raise AssertionError('Interrupted transaction did not reach its checkpoint')
        assert pid.isdigit()
        st.sql(f'select pg_terminate_backend({pid});')
        result=pending.result(timeout=10)
        assert result.returncode!=0

def rehearse():
    st.reset(False)
    st.reset(True)
    setup()
    n,c,u,m=backend.group()
    # Moderate historical synthetic volume: 4,000 records, never a production copy.
    st.sql(f"insert into public.expenses(network_id,cycle_id,paid_by_member_id,paid_by_member_name,added_by_member_id,added_by_member_name,amount_cents,note) select '{n}','{c}','{m[0]}','Fixture','{m[0]}','Fixture',100+i,'historical staging fixture' from generate_series(1,4000) i;")
    before=st.sql(f"select count(*)||':'||sum(amount_cents) from public.expenses where network_id='{n}';").stdout.strip()
    cases=[]
    extra=str(uuid.uuid4())
    st.sql(f"insert into public.expense_cycles(id,network_id,cycle_number,status) values('{extra}','{n}',2,'pending_reset');")
    result,seconds=apply_migration()
    assert result.returncode and 'duplicate open cycles' in result.stderr
    cases.append({'case':'duplicate open cycles safely rejected','seconds':seconds})
    st.sql(f"delete from public.expense_cycles where id='{extra}';")
    st.sql(f"update public.expense_cycles set status='closed' where id='{c}';")
    result,seconds=apply_migration()
    assert result.returncode and 'invalid active expense' in result.stderr
    cases.append({'case':'unarchived expense on closed cycle rejected','seconds':seconds})
    st.sql(f"update public.expense_cycles set status='active' where id='{c}';")
    r=str(uuid.uuid4())
    st.sql(f"insert into public.expense_reset_requests(id,network_id,cycle_id,requested_by_member_id,requested_by_member_name,required_member_ids) values('{r}','{n}','{c}','{m[1]}','Member 1',array['{m[1]}'::uuid]);")
    result,seconds=apply_migration()
    assert result.returncode and 'unsafe historical' in result.stderr
    cases.append({'case':'unsafe voter snapshot rejected','seconds':seconds})
    assert st.sql("select to_regprocedure('public.maskan_request_expense_reset(uuid,uuid)') is null;").stdout.strip()=='t'
    ids=','.join("'"+x+"'::uuid" for x in m)
    st.sql(f"update public.expense_reset_requests set required_member_ids=array[{ids}] where id='{r}';")
    # Interrupt after actual first migration DDL but before COMMIT.
    migration=(st.ROOT/'supabase/migrations'/st.MIGRATION).read_text()
    boundary= migration.index('-- RPCs take')
    prefix=migration[:boundary].replace('begin;', '', 1)
    interrupted_transaction(prefix, 'maskan_staging_interrupted_migration')
    assert st.sql("select to_regclass('public.expense_cycles_one_open_idx') is null;").stdout.strip()=='t'
    assert st.sql(f"select count(*)||':'||sum(amount_cents) from public.expenses where network_id='{n}';").stdout.strip()==before
    cases.append({'case':'terminated migration connection rolls back DDL and preserves money','passed':True})
    # Hold a real conflicting table lock longer than the migration's own 5s limit.
    with concurrent.futures.ThreadPoolExecutor(1) as pool:
        blocker=pool.submit(st.sql,"set application_name='maskan_staging_lock_holder'; begin; lock public.expense_cycles in access exclusive mode; select pg_sleep(8); commit;",timeout=15)
        deadline=time.monotonic()+5
        while time.monotonic()<deadline:
            if st.sql("select count(*) from pg_stat_activity where application_name='maskan_staging_lock_holder' and wait_event='PgSleep';").stdout.strip()=='1': break
            time.sleep(.1)
        result,seconds=apply_migration()
        assert result.returncode and 'lock timeout' in result.stderr, result.stderr
        blocker.result()
        cases.append({'case':'migration lock timeout safely rolls back','seconds':seconds})
    result,seconds=apply_migration()
    assert result.returncode==0,result.stderr
    assert st.sql(f"select count(*)||':'||sum(amount_cents) from public.expenses where network_id='{n}';").stdout.strip()==before
    assert st.sql(f"select status from public.expense_cycles where id='{c}';").stdout.strip()=='pending_reset'
    assert st.sql(f"select count(*) from public.expense_reset_approvals where reset_request_id='{r}';").stdout.strip()=='1'
    assert st.sql(f"select count(*) from public.network_notifications where reset_request_id='{r}';").stdout.strip()=='2'
    assert st.sql(f"select status from public.expense_reset_requests where id='{r}';").stdout.strip()=='pending'
    invalid=st.sql("select count(*) from pg_index i join pg_class c on c.oid=i.indrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and not i.indisvalid;").stdout.strip()
    assert invalid=='0'
    cases.append({'case':'valid upgrade including pending request and indexes','seconds':seconds,'historical_expenses':4000,'financial_snapshot':before,'invalid_indexes':0})
    record('migration-rehearsal',cases)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs): raise ValueError('Test redirects forbidden')

def client(settings, user):
    enc=lambda x:base64.urlsafe_b64encode(json.dumps(x).encode()).decode().rstrip('=')
    body=enc({'alg':'HS256','typ':'JWT'})+'.'+enc({'role':'authenticated','sub':user,'exp':int(time.time())+600})
    token=body+'.'+base64.urlsafe_b64encode(hmac.new(settings['JWT_SECRET'].encode(),body.encode(),hashlib.sha256).digest()).decode().rstrip('=')
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect())
    def request(path, method='GET', data=None):
        if settings['API_URL']!=st.API or not path.startswith(('expenses','rpc/')):
            raise ValueError('Unexpected mutation target')
        req=urllib.request.Request(st.API+'/rest/v1/'+path,method=method,
              data=None if data is None else json.dumps(data).encode(),
              headers={'apikey':settings['ANON_KEY'],'Authorization':'Bearer '+token,'Content-Type':'application/json','Prefer':'return=representation'})
        start=time.monotonic()
        try:
            with opener.open(req,timeout=12) as response:
                raw=response.read();return response.status,json.loads(raw) if raw else None,time.monotonic()-start
        except urllib.error.HTTPError as error:
            return error.code,json.loads(error.read()),time.monotonic()-start
    return request

def load():
    settings=setup(); n,c,u,m=backend.group(); request=client(settings,u[0])
    ids=[str(uuid.uuid4()) for _ in range(16)]
    latencies=[];conflicts=[];exhausted=[]
    def write(operation):
        payload={'network_id':n,'cycle_id':c,'paid_by_member_id':m[0],'paid_by_member_name':'Fixture',
                 'added_by_member_id':m[0],'added_by_member_name':'Fixture','amount_cents':1600,'note':'bounded load','client_generated_id':operation}
        for attempt in range(3):
            status,data,latency=request('expenses','POST',payload);latencies.append(latency)
            if status==201:return 'inserted'
            if data.get('code')=='23505':return 'duplicate-retry'
            if data.get('code')=='40001' and data.get('message')=='network_busy_retry':
                conflicts.append(1)
                if attempt<2:time.sleep(.1*(attempt+1));continue
                exhausted.append(operation);return 'bounded-retry-exhausted'
            raise AssertionError((status,data))
    start=time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(4) as pool:
        results=list(pool.map(write,ids+ids,timeout=90))
    # Explicit subsequent client retry, after initial bounded attempts have settled.
    for operation in sorted(set(exhausted)):
        assert write(operation) in ('inserted','duplicate-retry')
    rows=request('expenses?network_id=eq.'+n)[1]
    assert len(rows)==16 and sum(x['amount_cents'] for x in rows)==25600
    assert len({x['client_generated_id'] for x in rows})==16
    with concurrent.futures.ThreadPoolExecutor(4) as pool:
        closures=list(pool.map(lambda _:request('rpc/maskan_complete_expense_cycle','POST',{'p_network_id':n,'p_cycle_id':c,'p_reset_request_id':None}),range(8),timeout=60))
    assert all(x[0]==200 for x in closures), closures
    assert sum(x[1] is True for x in closures)==1
    assert st.sql(f"select count(*) from public.expense_cycles where network_id='{n}' and status in ('active','pending_reset');").stdout.strip()=='1'
    assert st.sql(f"select count(*) from public.expenses where network_id='{n}' and archived_at is not null;").stdout.strip()=='16'
    # Terminating a session mid-insert must roll back that expense.
    n2,c2,u2,m2=backend.group(); e,insert=backend.expense(n2,c2,m2[0])
    interrupted_transaction(insert,'maskan_staging_interrupted_expense')
    assert st.sql(f"select count(*) from public.expenses where id='{e}';").stdout.strip()=='0'
    latencies.sort()
    percentile=lambda p:round(latencies[min(len(latencies)-1,math.ceil(len(latencies)*p)-1)]*1000,2)
    record('load-results',{'max_workers':4,'logical_operations':16,'submissions':32,'http_attempts':len(latencies),
        'temporary_conflicts':len(conflicts),'initial_retry_exhaustions':len(exhausted),'distinct_expenses':16,'duplicate_expenses':0,
        'concurrent_closures':8,'successful_closure_effects':1,'interrupted_insert_rolled_back':True,
        'latency_ms':{'p50':percentile(.5),'p95':percentile(.95),'max':round(max(latencies)*1000,2)},
        'elapsed_seconds':round(time.monotonic()-start,3),'results':{x:results.count(x) for x in set(results)}})

def locks():
    settings=setup();n,c,u,m=backend.group();request=client(settings,u[0])
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        holder=pool.submit(st.sql,f"begin; set local application_name='maskan_staging_contention'; set local role authenticated; set local request.jwt.claim.sub='{u[0]}'; select pg_advisory_xact_lock(hashtextextended('maskan-finance:{n}',0)); select pg_sleep(4); select public.maskan_complete_expense_cycle('{n}','{c}',null); commit;",timeout=15)
        deadline=time.monotonic()+5
        while time.monotonic()<deadline:
            if st.sql("select count(*) from pg_stat_activity where application_name='maskan_staging_contention' and wait_event='PgSleep';").stdout.strip()=='1':break
        waiter=pool.submit(request,'rpc/maskan_complete_expense_cycle','POST',{'p_network_id':n,'p_cycle_id':c,'p_reset_request_id':None})
        time.sleep(.2)
        key=f"hashtextextended('maskan-finance:{n}',0)"
        waiting=int(st.sql(f"select count(*) from pg_locks where locktype='advisory' and not granted and classid=(({key}>>32)&4294967295)::oid and objid=({key}&4294967295)::oid;").stdout.strip())
        holder.result(timeout=12);status,result,seconds=waiter.result(timeout=12)
    assert waiting>=1 and status==200 and result is False
    record('lock-results',{'observed_waiting_advisory_locks':waiting,'waiter_latency_ms':round(seconds*1000,2),'waiter_idempotent_result':result,'deadlock':False})

def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['rehearse','load','locks'])
    args=parser.parse_args();st.target_guard()
    {'rehearse':rehearse,'load':load,'locks':locks}[args.action]()
if __name__=='__main__':main()
