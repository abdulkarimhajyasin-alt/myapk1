# Read-only production recovery audit

Baseline: 1337c9ece0f6bd0be1439e4292ce7c6d6ae74795. No production writes or real-data exports are authorized.

The three `production-*-select.sql` files contain single SELECT statements for catalog metadata and aggregate counts. Review them before execution through the existing authorized Supabase SQL connector for project skngodvomygvxemfaefn. Never feed these files or production connection details into a mutating test runner. No generic production SQL executor is provided.

`production-metadata.json` and `production-privileges.json` contain schema metadata, function-definition fingerprints, policy definitions, and aggregate counts only. They contain no user rows or function bodies. `compare_schema.py` reads these snapshots and the fixed guarded LOCAL staging database. Function fingerprints detect textual changes, not semantic equivalence.

`backup_metadata.py` uses only a fixed HTTPS GET metadata endpoint when SUPABASE_ACCESS_TOKEN is already available. It disables proxies and redirects, retains only selected metadata fields, and has no backup download/restore capability. Do not paste tokens into code or command history. Missing authorization is recorded as unverified, not as an empty backup inventory.

Run checks sequentially from the repository root:

```powershell
python -m unittest discover -s supabase/audit -p test_audit_safety.py -v
python supabase/audit/backup_metadata.py
python supabase/audit/compare_schema.py
python supabase/staging/backup_restore.py
python supabase/staging/recovery_validation.py
```

The last two commands operate on synthetic data only. Recovery database is 127.0.0.1:57322; the temporary PostgREST container binds only 127.0.0.1:57321 on the separate recovery network. Real Flutter/JS SDKs use read-only transports, synthetic short-lived JWTs and repeated connections; Auth login, Edge and Realtime on the restored stack are NOT covered. The temporary REST container is stopped afterward. Private credentials and logs remain ignored under .codex_tmp; do not commit them.

See ../docs/production-recovery-audit-ar.md and ../docs/production-recovery-runbook-ar.md for evidence, device instructions, encryption requirements and separate approval gates. Full application suites passed in the previous staging task and were not repeated for documentation/test-only changes.
