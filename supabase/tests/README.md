# Phase 1 database isolation test

Run this only against a disposable local Supabase database. The isolation test
itself rolls back its fixtures, while the schema and migration remain applied.

```powershell
npx supabase start
npx supabase db reset
$env:PGPASSWORD = 'postgres'
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/phase_01_rls_isolation.sql
Remove-Item Env:PGPASSWORD
```

`db reset` must apply the ordered migration chain:

1. `20260807000000_baseline_pre_phase1.sql`
2. `20260807000100_harden_auth_membership_rls.sql`
3. `20260820000000_migrate_password_security.sql`
4. `20260825000000_add_password_rate_limits.sql`

Do not run `supabase link` or `supabase db push` for this validation.

A successful run ends with `ROLLBACK` and no raised exception. The script checks
Network A/Network B inverse isolation, allowed same-network expense CRUD,
cross-network read/write denial, actor-ID spoof denial, anonymous table denial,
sensitive-column privileges, and the SELECT visibility used by Realtime RLS.

# Phase 2 password-security integration test

Keep the local Edge Function server running in a separate terminal, then run
the synthetic matrix against the disposable local stack:

```powershell
npx supabase functions serve
powershell.exe -NoProfile -ExecutionPolicy Bypass -File supabase/tests/phase_02_password_security.ps1
```

The script never targets a linked project. It validates modern-only creation,
legacy upgrade-on-proof, reset/Auth synchronization, concurrency, isolation,
and durable five-failure rate limiting with HTTP 429 and expiry recovery.
