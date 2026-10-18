"""Rehearse upgrade on the dedicated local stack at migration 20260826000000.
Reset that disposable stack to the baseline before invoking this script.
No remote connection or production data is used.
"""
from pathlib import Path
import json
import os
import subprocess
from backend_hardening import CONTAINER, group, sql, uid, check

assert not os.environ.get('DOCKER_HOST') or os.environ['DOCKER_HOST'].startswith(('npipe://','unix://')), 'Remote DOCKER_HOST is forbidden'
endpoint=json.loads(subprocess.check_output(['docker','context','inspect'],text=True))[0]['Endpoints']['docker']['Host']
assert endpoint.startswith(('npipe://','unix://')), 'Requires local Docker'
assert sql("select to_regprocedure('public.maskan_request_expense_reset(uuid,uuid)') is null;")=='t', 'Requires pre-hardening baseline'
n,c,u,m=group()
r=uid()
sql(f"insert into public.expense_reset_requests(id,network_id,cycle_id,requested_by_member_id,requested_by_member_name,required_member_ids) values('{r}','{n}','{c}','{m[1]}','Member 1',array['{m[1]}'::uuid]);")
migration=Path(__file__).resolve().parents[1]/'migrations/20261017194224_harden_expense_cycles_and_reset_workflows.sql'
def apply():
    return subprocess.run(['docker','exec','-i',CONTAINER,'psql','-XqAt','-U','postgres','-v','ON_ERROR_STOP=1'],input=migration.read_text(encoding='utf-8'),text=True,capture_output=True,timeout=90)
failed=apply()
check('unsafe legacy snapshot blocks upgrade',failed.returncode!=0 and 'unsafe historical' in failed.stderr)
check('failed upgrade rolls back schema',sql("select to_regprocedure('public.maskan_request_expense_reset(uuid,uuid)') is null;")=='t')
# Repair only our synthetic fixture to model an interrupted but valid old-client request.
ids=','.join("'"+x+"'::uuid" for x in m)
sql(f"update public.expense_reset_requests set required_member_ids=array[{ids}] where id='{r}';")
result=apply()
assert result.returncode==0,result.stderr
check('existing pending request receives initiator vote',sql(f"select count(*) from public.expense_reset_approvals where reset_request_id='{r}';")=='1')
check('existing pending request receives missing notices',sql(f"select count(*) from public.network_notifications where reset_request_id='{r}';")=='2')
check('existing pending cycle marker repaired',sql(f"select status from public.expense_cycles where id='{c}';")=='pending_reset')
check('upgrade does not complete historical pending request',sql(f"select status from public.expense_reset_requests where id='{r}';")=='pending')
print('6 upgrade checks passed')
