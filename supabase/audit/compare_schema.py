"""Compare catalog evidence only; no production connection or data access."""
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'staging'))
import staging as st

p=Path(__file__).parent
prod=json.loads((p/'production-metadata.json').read_text())['schema']
# Local migrations run as SQL files, so there is no CLI migration-history table.
query=(p/'production-schema-select.sql').read_text()
query=query.replace("(select jsonb_agg(jsonb_build_array(version,name) order by version) from supabase_migrations.schema_migrations)","'[]'::jsonb")
local=json.loads(st.sql(query,timeout=30).stdout)
def function_map(d):
    return {(f['schema'],f['name'],f['args']):f for f in d['functions']}
a=function_map(prod);b=function_map(local)
result={'production_functions':len(a),'staging_functions':len(b),
'new_staging_functions':sorted('.'.join(k[:2])+'('+k[2]+')' for k in b.keys()-a.keys()),
'changed_function_definitions':sorted('.'.join(k[:2])+'('+k[2]+')' for k in a.keys()&b.keys() if a[k]['definition_md5']!=b[k]['definition_md5']),
'production_anon_security_definers':[f['name'] for f in prod['functions'] if f['security_definer'] and f['anon_execute']],
'staging_anon_security_definers':[f['name'] for f in local['functions'] if f['security_definer'] and f['anon_execute']],
'new_staging_indexes':sorted(set(x[2] for x in local['indexes'])-set(x[2] for x in prod['indexes'])),
'production_not_valid_constraints':[c for c in prod['constraints'] if not c[4]],
'local_migration_history':'Not compared: SQL-file rehearsal does not populate CLI history'}
(p/'schema-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
