"""Guarded suite orchestration: explicit local credentials, no arbitrary commands."""
import argparse
import json
import os
import secrets
import shutil
import subprocess
import sys
import time
import staging as st
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

COMMANDS={
 'sql': [[sys.executable,'supabase/tests/backend_hardening.py','--workdir',str(st.WORK)]],
 'flutter': [['flutter','analyze','--no-pub'],['flutter','test','--no-pub']],
 'realtime': [['flutter','test','--no-pub','test/supabase_realtime_local_integration_test.dart']],
 'web': [['npm','run','typecheck'],['npm','run','lint'],['npm','test'],['npm','run','test:integration'],['npm','run','build']],
 'browser': [['npm','run','test:browser','--','--workers=1']],
 'edge': [['node','--import','./web-dashboard/node_modules/tsx/dist/loader.mjs','--test','supabase/tests/edge_hardening.test.mts'],
          ['npx','--yes','deno','check','supabase/functions/maskan-password/index.ts','supabase/functions/maskan-delete-account/index.ts']],
}

COMMANDS['web-regression'] = COMMANDS['web'][:-1]

def execute(command, env, cwd, label, results):
    command=list(command)
    command[0]=shutil.which(command[0]+'.bat') or shutil.which(command[0]+'.cmd') or shutil.which(command[0]) or command[0]
    started=time.monotonic()
    result=subprocess.run(command,cwd=cwd,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600)
    (st.WORK/(label+'.private.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
    entry={'suite':label,'exit_code':result.returncode,'seconds':round(time.monotonic()-started,2)}
    results.append(entry)
    (st.WORK/(label+'-result.json')).write_text(json.dumps(entry,indent=2))
    (st.WORK/'suite-results.json').write_text(json.dumps(results,indent=2))
    print(json.dumps(entry),flush=True)
    # All service keys remain in child environment, never in command arguments/log summaries.
    tail=(result.stdout+result.stderr).splitlines()[-10:]
    for line in tail:
        for key in ('ANON_KEY','SERVICE_ROLE_KEY','JWT_SECRET'):
            line=line.replace(st.settings_cache[key],'[REDACTED]')
        print(line,flush=True)
    if result.returncode: raise SystemExit(result.returncode)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('suite',choices=[*COMMANDS,'shared'])
    args=parser.parse_args()
    st.db_guard();st.validate_compose();st.wait_ready()
    settings=st.settings();st.settings_cache=settings
    env=st.cli_env()
    env.update({'MASKAN_TEST_SUPABASE_URL':st.API,'MASKAN_TEST_ANON_KEY':settings['ANON_KEY'],
      'LOCAL_SUPABASE_API_URL':st.API,'LOCAL_SUPABASE_ANON_KEY':settings['ANON_KEY'],
      'NEXT_PUBLIC_SUPABASE_URL':st.API,'NEXT_PUBLIC_SUPABASE_ANON_KEY':settings['ANON_KEY']})
    results=json.loads((st.WORK/'suite-results.json').read_text()) if (st.WORK/'suite-results.json').exists() else []
    if args.suite=='shared':
        env['MASKAN_STAGING_GROUP']='staging-shared-'+secrets.token_hex(8)
        env['MASKAN_STAGING_PASSWORD']='Synthetic-'+secrets.token_hex(12)
        for phase,language in [('seed','web'),('join','flutter'),('finish','web'),('verify','flutter')]:
            env['MASKAN_STAGING_PHASE']=phase
            command=['npx','--no-install','tsx','tests/staging/shared-client.ts'] if language=='web' else ['flutter','test','--no-pub','test/staging_client_integration_test.dart']
            execute(command,env,st.ROOT/'web-dashboard' if language=='web' else st.ROOT,'shared-'+phase,results)
    else:
        if args.suite=='flutter':
            # General suite retains explicit integration skips; run each integration separately.
            env.pop('LOCAL_SUPABASE_API_URL');env.pop('LOCAL_SUPABASE_ANON_KEY')
        for i,command in enumerate(COMMANDS[args.suite]):
            execute(command,env,st.ROOT/'web-dashboard' if args.suite in ('web','web-regression','browser') else st.ROOT,args.suite+'-'+str(i),results)
if __name__=='__main__':main()
