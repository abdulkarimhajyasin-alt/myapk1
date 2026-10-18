"""Integration checks on a dedicated local Supabase container; never accepts a DB URL.
Run: python supabase/tests/backend_hardening.py --workdir .codex_tmp/maskan-hardening-local
Apply migrations to this disposable stack first. All fixtures are synthetic.
"""
import argparse
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
import urllib.error
import urllib.request
import uuid

CONTAINER = "supabase_db_maskan-hardening-local"
checks = 0
validate_target = None

def configure_staging():
    global CONTAINER, validate_target
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "staging"))
    import staging
    staging.db_guard()
    CONTAINER = staging.DB
    validate_target = staging.db_guard
    urllib.request.install_opener(urllib.request.build_opener(urllib.request.ProxyHandler({}), staging.NoRedirect()))
    return staging.settings()


def sql(statement, user=None, expect_error=False):
    if validate_target: validate_target()
    prefix = ""
    if user:
        prefix = f"set local role authenticated; set local request.jwt.claim.sub='{user}'; set local request.jwt.claim.role='authenticated';"
    command = f"begin; set local statement_timeout='10s'; {prefix} {statement} commit;"
    result = subprocess.run(["docker", "exec", "-i", CONTAINER, "psql", "-XqAt", "-U", "postgres", "-v", "ON_ERROR_STOP=1"], input=command, text=True, capture_output=True, timeout=25)
    if expect_error:
        assert result.returncode != 0, "Expected server-side rejection"
        return result.stderr
    if result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout.strip()

def check(name, condition):
    global checks
    assert condition, name
    checks += 1
    print("PASS", name, flush=True)

def uid():
    return str(uuid.uuid4())

def group(size=3):
    network, cycle = uid(), uid()
    users, members = [uid() for _ in range(size)], [uid() for _ in range(size)]
    statement = f"insert into public.networks(id,name,normalized_name) values('{network}','hardening-{network}','hardening-{network}');"
    for i, (user, member) in enumerate(zip(users, members)):
        statement += f"insert into auth.users(id,email,aud,role) values('{user}','{user}@example.invalid','authenticated','authenticated');"
        statement += f"insert into public.network_members(id,network_id,auth_user_id,name,normalized_name) values('{member}','{network}','{user}','Member {i}','member {i}');"
    statement += f"update public.networks set created_by_member_id='{members[0]}' where id='{network}'; insert into public.expense_cycles(id,network_id,cycle_number) values('{cycle}','{network}',1);"
    sql(statement)
    return network, cycle, users, members

def expense(network, cycle, member, id=None):
    id = id or uid()
    cycle_value = "null" if cycle is None else f"'{cycle}'"
    return id, f"insert into public.expenses(id,network_id,cycle_id,paid_by_member_id,paid_by_member_name,added_by_member_id,added_by_member_name,amount_cents) values('{id}','{network}',{cycle_value},'{member}','forged','{member}','forged',4000) returning id;"

def complete(n, c):
    return f"select public.maskan_complete_expense_cycle('{n}','{c}',null);"

def held(statement, user, network):
    if validate_target: validate_target()
    # Read an explicit lock-acquired marker before issuing the competing request.
    command = f"begin; set local statement_timeout='10s'; set local role authenticated; set local request.jwt.claim.sub='{user}'; select pg_advisory_xact_lock(hashtextextended('maskan-finance:{network}',0)); select 'LOCKED'; select pg_sleep(1.5); {statement} commit;"
    process = subprocess.Popen(["docker","exec","-i",CONTAINER,"psql","-XqAt","-U","postgres","-v","ON_ERROR_STOP=1"],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    process.stdin.write(command)
    process.stdin.close()
    while process.stdout.readline().strip() != "LOCKED":
        if process.poll() is not None:
            raise AssertionError(process.stderr.read())
    return process

def finish(process):
    output = process.stdout.read().strip()
    error = process.stderr.read()
    assert process.wait(timeout=20) == 0, error
    return output

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--workdir', required=True)
    args=parser.parse_args()
    assert not os.environ.get('DOCKER_HOST') or os.environ['DOCKER_HOST'].startswith(('npipe://','unix://')), 'Remote DOCKER_HOST is forbidden'
    endpoint=json.loads(subprocess.check_output(['docker','context','inspect'],text=True))[0]['Endpoints']['docker']['Host']
    if not endpoint.startswith(('npipe://','unix://')):
        raise SystemExit('Refusing a nonlocal Docker context')
    workdir = Path(args.workdir).resolve()
    staging_dir = Path(__file__).resolve().parents[2] / '.codex_tmp' / 'maskan-staging-validation'
    if workdir == staging_dir.resolve():
        settings = configure_staging()
    else:
        config=workdir/'supabase'/'config.toml'
        if 'project_id = "maskan-hardening-local"' not in config.read_text():
            raise SystemExit('Requires a dedicated disposable local project')
        status=subprocess.run([shutil.which('npx.cmd') or shutil.which('npx'),'--yes','supabase@2.115.0','status','--workdir',str(workdir),'--output','json'],capture_output=True,text=True,check=True)
        settings=json.loads(status.stdout)
        if settings['API_URL'] != 'http://127.0.0.1:55321':
            raise SystemExit('Refusing nonlocal or unexpected API URL')
    api=settings['API_URL']
    jwt_secret=settings['JWT_SECRET']
    def token(user):
        enc=lambda x:base64.urlsafe_b64encode(json.dumps(x).encode()).decode().rstrip('=')
        body=enc({'alg':'HS256','typ':'JWT'})+'.'+enc({'role':'authenticated','sub':user,'exp':int(time.time())+600})
        return body+'.'+base64.urlsafe_b64encode(hmac.new(jwt_secret.encode(),body.encode(),hashlib.sha256).digest()).decode().rstrip('=')
    def rest(path, user, method='GET', data=None):
        request=urllib.request.Request(api+'/rest/v1/'+path,method=method,data=None if data is None else json.dumps(data).encode(),headers={'apikey':settings['ANON_KEY'],'Authorization':'Bearer '+token(user),'Content-Type':'application/json','Prefer':'return=representation'})
        try:
            with urllib.request.urlopen(request,timeout=12) as response:
                raw=response.read();return response.status,json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            return error.code,json.loads(error.read())

    n,c,u,m=group()
    other,other_c,ou,om=group(1)
    e,insert=expense(n,c,m[0]);sql(insert,u[0])
    check('insert normalizes names and retains active cycle',sql(f"select paid_by_member_name='Member 0' and cycle_id='{c}' from public.expenses where id='{e}';")=='t')
    check('author REST active edit',rest('expenses?id=eq.'+e,u[0],'PATCH',{'amount_cents':4100})[0]==200)
    check('other member cannot edit author expense',rest('expenses?id=eq.'+e,u[1],'PATCH',{'amount_cents':1})[1]==[])
    check('cross-network expense isolation',rest('expenses?network_id=eq.'+n,ou[0])[1]==[])
    for field,value in [('cycle_id',other_c),('archived_at','2026-01-01T00:00:00Z'),('paid_by_member_id',m[1]),('added_by_member_id',m[1])]:
        check('protected REST field '+field,rest('expenses?id=eq.'+e,u[0],'PATCH',{field:value})[0]>=400)
    check('nonowner direct completion rejected','owner_required' in sql(complete(n,c),u[1],True))
    check('cross-network completion rejected','membership_required' in sql(complete(n,c),ou[0],True))
    sql(complete(n,c),u[0])
    check('archived REST edit affects no row',rest('expenses?id=eq.'+e,u[0],'PATCH',{'note':'mutated'})[1]==[])
    check('archived REST delete affects no row',rest('expenses?id=eq.'+e,u[0],'DELETE')[1]==[])
    check('archived record preserved',sql(f"select amount_cents=4100 and archived_at is not null from public.expenses where id='{e}';")=='t')
    check('repeat completion returns no-op',sql(complete(n,c),u[0])=='f')
    check('repeat created only one next cycle',sql(f"select count(*) from public.expense_cycles where network_id='{n}';")=='2')
    _,stale=expense(n,c,m[0]);check('stale-cycle insertion rejected','stale_expense_cycle' in sql(stale,u[0],True))
    _,legacy=expense(n,None,m[0]);sql(legacy,u[0])
    check('legacy null cycle assigned active',sql(f"select count(*) from public.expenses where network_id='{n}' and cycle_id is null;")=='0')

    n,c,u,m=group()
    request=uid()
    # Legacy request lies about voters; the server must derive all three members.
    sql(f"insert into public.expense_reset_requests(id,network_id,cycle_id,requested_by_member_id,requested_by_member_name,required_member_ids) values('{request}','{n}','{c}','{m[1]}','forged',array['{m[1]}'::uuid]);",u[1])
    check('server captures complete approval snapshot',sql(f"select cardinality(required_member_ids) from public.expense_reset_requests where id='{request}';")=='3')
    check('initiator approval is atomic',sql(f"select count(*) from public.expense_reset_approvals where reset_request_id='{request}';")=='1')
    check('pending marker is atomic',sql(f"select status from public.expense_cycles where id='{c}';")=='pending_reset')
    approval=f"insert into public.expense_reset_approvals(reset_request_id,network_id,member_id,member_name) values('{request}','{n}','{m[1]}','retry')"
    sql(approval+';',u[1]);sql(approval+' on conflict(reset_request_id,member_id) do update set network_id=excluded.network_id,member_id=excluded.member_id,reset_request_id=excluded.reset_request_id,member_name=excluded.member_name,approved_at=excluded.approved_at;',u[1])
    check('legacy plain insert and merge-upsert retries preserve vote',sql(f"select count(*) from public.expense_reset_approvals where reset_request_id='{request}';")=='1')
    sql(f"update public.expense_cycles set status='pending_reset',requested_by_member_id='{m[1]}',requested_by_member_name='retry' where id='{c}';",u[1])
    check('atomic request RPC returns same request on retry',sql(f"select (public.maskan_request_expense_reset('{n}','{c}')).id;",u[1])==request)
    check('owner cannot bypass pending approval','pending_request' in sql(complete(n,c),u[0],True))
    check('outsider approval RPC denied','membership_required' in sql(f"select public.maskan_approve_expense_reset('{n}','{request}');",ou[0],True))
    sql(f"select public.maskan_approve_expense_reset('{n}','{request}');",u[0])
    check('insufficient votes leave cycle pending',sql(f"select status from public.expense_cycles where id='{c}';")=='pending_reset')
    sql(f"insert into public.expense_reset_approvals(reset_request_id,network_id,member_id,member_name) values('{request}','{n}','{m[2]}','legacy');",u[2])
    check('last legacy vote completes even if client disconnects',sql(f"select status from public.expense_reset_requests where id='{request}';")=='completed')
    check('approve retry after completion is safe',sql(f"select public.maskan_approve_expense_reset('{n}','{request}');",u[2])=='t')
    check('reset and completion notifications committed once',sql(f"select count(*) from public.network_notifications where network_id='{n}';")=='5')
    sql(f"insert into public.network_notifications(network_id,recipient_member_id,actor_member_name,amount_cents,currency_symbol,kind) values('{n}','{m[0]}','legacy',0,'$','cycleStarted');",u[0])
    check('legacy notifications do not duplicate server events',sql(f"select count(*) from public.network_notifications where network_id='{n}';")=='5')
    check('forged new open cycle blocked','duplicate' in sql(f"insert into public.expense_cycles(network_id,cycle_number,status) values('{n}',99,'active');",expect_error=True))

    n,c,u,m=group()
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        results=list(pool.map(lambda _:sql(complete(n,c),u[0]),range(2)))
    check('concurrent completions perform exactly once',sorted(results)==['f','t'])
    check('concurrent completion preserves one open cycle',sql(f"select count(*) from public.expense_cycles where network_id='{n}' and status in ('active','pending_reset');")=='1')
    n,c,u,m=group();e,insert=expense(n,c,m[0])
    process=held(insert,u[0],n)
    # Insertion commits first, so completion must archive it.
    sql(complete(n,c),u[0]);finish(process)
    check('in-flight insert is included before closure',sql(f"select archived_at is not null from public.expenses where id='{e}';")=='t')
    n,c,u,m=group();e,insert=expense(n,c,m[0]);sql(insert,u[0])
    process=held(complete(n,c),u[0],n)
    _,insert=expense(n,c,m[0])
    check('insert during closing receives retryable conflict','network_busy_retry' in sql(insert,u[0],True))
    check('edit during closing avoids inverse-lock deadlock','network_busy_retry' in sql(f"update public.expenses set amount_cents=5000 where id='{e}';",u[0],True))
    finish(process)
    check('closing transaction still succeeds',sql(f"select status from public.expense_cycles where id='{c}';")=='closed')
    n,c,u,m=group();e,insert=expense(n,c,m[0]);sql(insert,u[0])
    sql(complete(n,c)+"do $$ begin raise exception 'forced rollback'; end $$;",u[0],True)
    check('failed transaction leaves cycle and money intact',sql(f"select status='active' and (select archived_at is null from public.expenses where id='{e}') from public.expense_cycles where id='{c}';")=='t')


    n,c,u,m=group();e,insert=expense(n,c,m[1]);sql(insert,u[1])
    check('active author REST delete remains supported',len(rest('expenses?id=eq.'+e,u[1],'DELETE')[1])==1)
    _,insert=expense(n,c,m[1]);sql(insert,u[1])
    request=sql(f"select (public.maskan_request_expense_reset('{n}','{c}')).id;",u[1])
    check('request RPC creates canonical pending state',sql(f"select status from public.expense_cycles where id='{c}';")=='pending_reset')
    sql(f"delete from public.expense_reset_requests where id='{request}';",u[1])
    check('request cancellation restores active marker',sql(f"select status from public.expense_cycles where id='{c}';")=='active')
    request=sql(f"select (public.maskan_request_expense_reset('{n}','{c}')).id;",u[1])
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        results=list(pool.map(lambda i:sql(f"select public.maskan_approve_expense_reset('{n}','{request}');",u[i]),[0,2]))
    check('concurrent votes close exactly one cycle',sql(f"select count(*) from public.expense_cycles where network_id='{n}';")=='2')
    check('completed reset is not client-deletable',rest('expense_reset_requests?id=eq.'+request,u[1],'DELETE')[1]==[])
    # Verified privacy redaction is the intentional exception to financial-history immutability.
    deletion=uid();digest=hashlib.sha256(deletion.encode()).hexdigest()
    sql(f"select public.maskan_authorize_account_deletion('{u[1]}','{digest}');")
    check('another member cannot consume deletion token','reauthentication_required' in sql(f"select public.maskan_delete_account_data('{deletion}',false);",u[2],True))
    sql(f"select public.maskan_delete_account_data('{deletion}',false);",u[1])
    check('verified nonowner deletion preserves archived amounts',sql(f"select count(*) from public.expenses where network_id='{n}' and amount_cents=4000 and archived_at is not null and paid_by_member_id is null;")=='1')
    check('deleted membership cannot access group using old JWT',rest('expenses?network_id=eq.'+n,u[1])[1]==[])
    check('deletion token is single-use','reauthentication_required' in sql(f"select public.maskan_delete_account_data('{deletion}',false);",u[1],True))
    n,c,u,m=group()
    call=f"select (public.maskan_request_expense_reset('{n}','{c}')).id;"
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        results=list(pool.map(lambda _:sql(call,u[1]),range(2)))
    check('concurrent request retries return the same request',results[0]==results[1])
    sql(f"select public.maskan_leave_network('{n}');",u[2])
    check('membership leave cancels pending snapshot safely',sql(f"select status from public.expense_cycles where id='{c}';")=='active')
    renewed=sql(f"select (public.maskan_request_expense_reset('{n}','{c}')).id;",u[1])
    check('a cancelled request does not block a fresh reset',renewed!=results[0])
    n,c,u,m=group()
    sql(f"select public.maskan_request_expense_reset('{n}','{c}'); do $$ begin raise exception 'forced rollback'; end $$;",u[1],True)
    check('interrupted request transaction leaves no votes or notices',sql(f"select (select count(*) from public.expense_reset_requests where network_id='{n}')+(select count(*) from public.expense_reset_approvals where network_id='{n}')+(select count(*) from public.network_notifications where network_id='{n}');")=='0')

    # Permission inventory and bearer capability replay protection.
    check('anon cannot execute application SECURITY DEFINER functions',sql("select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosecdef and has_function_privilege('anon',p.oid,'execute');")=='0')
    check('all application definers have fixed search_path',sql("select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prosecdef and not exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%');")=='0')
    check('service-only password RPC rejects authenticated',bool(sql("select public.maskan_password_lookup_network(null,'anything');",u[0],True)))
    claim=uid();digest=hashlib.sha256(claim.encode()).hexdigest()
    sql(f"select public.maskan_password_issue_claim('{m[0]}','{u[0]}','{digest}');")
    sql(f"select public.maskan_claim_member('{m[0]}','{claim}');",u[0])
    check('claim token cannot be replayed',bool(sql(f"select public.maskan_claim_member('{m[0]}','{claim}');",u[0],True)))
    sql(f"select public.maskan_password_issue_claim('{m[0]}','{u[0]}','{digest}'); update private.member_claim_tokens set expires_at=clock_timestamp()-interval '1 second' where member_id='{m[0]}';")
    check('expired claim token rejected',bool(sql(f"select public.maskan_claim_member('{m[0]}','{claim}');",u[0],True)))
    check('deletion requires one-use verified capability','reauthentication_required' in sql("select public.maskan_delete_account_data('invalid',true);",u[1],True))
    deletion=uid();digest=hashlib.sha256(deletion.encode()).hexdigest()
    sql(f"select public.maskan_authorize_account_deletion('{u[0]}','{digest}');")
    check('owner deletion with other members refused','owner_transfer_required' in sql(f"select public.maskan_delete_account_data('{deletion}',true);",u[0],True))
    print(f'{checks} integration checks passed. Synthetic fixtures retained only in {CONTAINER}.')

if __name__=='__main__':
    main()
