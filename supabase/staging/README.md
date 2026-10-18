ï»؟# Isolated Maskan staging validation

This tooling is specific to `validation/maskan-staging-readiness`, based on security commit `df1fbfb4f9c3ad5bccdbeb0c6555bb57061588c4`. It does not deploy application code or modify hosted Supabase. Application sources and the reviewed migration remain unchanged.

## Architecture and prerequisites

Use Python 3.11+, Docker Desktop with the local Linux engine, Node/npm, Flutter, and the installed web dependencies. Supabase CLI is pinned to 2.115.0. The first start may download free public images/packages. No cloud account, cloud access token or paid infrastructure is required.

| Resource | Staging | Recovery |
|---|---|---|
| Identity | maskan-staging-validation | maskan-staging-recovery |
| API | http://127.0.0.1:56321 | none |
| PostgreSQL | 127.0.0.1:56322 | 127.0.0.1:57322 |
| Mail capture | 127.0.0.1:56324 | none |
| Docker network | maskan-staging-validation-network | maskan-staging-recovery-network |
| DB volume | supabase_db_maskan-staging-validation | maskan-staging-recovery-data |
| Storage volume | supabase_storage_maskan-staging-validation | none |

The previous `maskan-hardening-local` stack and ports 553xx are not reused or mutated. All fixtures are generated, never copied from production.

The CLI bootstraps empty Supabase infrastructure with a generated JWT secret, generated API keys and a generated database root key. Because the pinned CLI does not expose a configurable PostgreSQL password, the tooling materializes those pinned service images into private Compose configuration and rotates login-role passwords transactionally using the local administrator. No password is copied into tracked code. The gateway configuration is generated locally with key authentication, local-only upstreams and the Realtime tenant hostname. Edge runs through the pinned CLI local function runtime on its actual internal port 8081.

An `internal` Docker network failed to provide the required host connectivity on this Docker Desktop setup. The working network is a dedicated bridge with published ports bound to 127.0.0.1. This is not an outbound firewall: HTTP test transports separately reject external origins and redirects. Do not claim complete OS-level egress filtering. No production connection parameters are accepted by these commands.

## Safety guarantees and limits

- Fixed project, workspace, API, container, network and volume allowlists; production project `skngodvomygvxemfaefn`, the old local project and other addresses are rejected.
- Reject remote Docker TCP/SSH contexts and remote Windows named pipes. Only local Unix sockets or `npipe:////./pipe/` are accepted.
- Reject linked-project marker files and remote config blocks. Scrub inherited cloud CLI overrides and credentials before invoking local CLI commands.
- CLI action allowlist contains only exact bootstrap start, local status and local functions serve. No db push, linked reset, deployment or generic passthrough.
- Inspect live Docker ownership, database mounts and loopback bindings before SQL/reset. Compose mutations validate container names, ports, mounts and network ownership.
- Python test HTTP disables proxies/redirects; web test fetch rejects other origins/redirects; Flutter uses `LocalOnlyTestClient`. Staging runners inject only the fixed 56321 URL.
- PostgreSQL is tested over TCP with the generated password and with a deliberately incorrect password. Gateway valid/invalid API-key checks are included.
- Four load workers maximum, bounded retries, request and subprocess timeouts. Run heavy suites sequentially. Browser tests use one worker without weakened assertions/timeouts.
- Administrative Docker socket access is trusted. These guards prevent accidental targeting; they are not a security boundary against an administrator intentionally modifying the scripts, Docker daemon or host files.

Credentials, private Compose/gateway files, fixture logs and dumps stay under `.codex_tmp/maskan-staging-validation/`, excluded from Git. Never publish that directory. The local backup contains synthetic Auth and private credential records; still treat it as sensitive. No volume deletion command is exposed.

## Lifecycle

From the repository root:

```powershell
python supabase/staging/staging.py start
python supabase/staging/staging.py inspect
python supabase/staging/staging.py reset
```

`reset` stops staging writers, restores the empty infrastructure snapshot, and replays every migration with psql ON_ERROR_STOP. It destroys only synthetic staging database contents. It neither deletes the previous local test database nor modifies hosted migration history. Rehearsal timing/checksum artifacts replace a hosted migration history for this custom local harness.

Serve Edge in a separate terminal after start/reset:

```powershell
python supabase/staging/staging.py serve
```

Verify actual isolation and test safeguards:

```powershell
python supabase/staging/isolation_check.py
python -m unittest discover -s supabase/staging -p test_safety.py -v
```

Stop staging core, Edge and recovery containers while retaining volumes:

```powershell
python supabase/staging/staging.py stop
```

`start` preserves the existing staging data. Start Edge again in its separate terminal. Recovery is started by the backup/restore command when needed. Do not run lifecycle reset/stop while a test suite is writing.

## Rehearsal and controlled load

```powershell
python supabase/staging/validate.py rehearse
python supabase/staging/staging.py serve
# In another terminal, after rehearsal finishes:
python supabase/staging/run_suite.py sql
python supabase/staging/validate.py load
```

Rehearsal resets staging twice: clean full chain, then pre-hardening baseline. It generates 4,000 synthetic historical expenses, tests three rejected historical states, terminates a migration connection after real DDL, measures the migration's own lock timeout, and performs a valid pending-request upgrade. It does not auto-complete old pending requests or alter the migration file.

Load uses 32 submissions for 16 operation IDs, four workers, two automatic retries, eight competing closure requests and an interrupted expense transaction. Initial exhausted retries are reported separately; explicit subsequent retries preserve IDs. Latencies are local workload observations, not production capacity estimates.

## Backup and restore

```powershell
python supabase/staging/backup_restore.py
```

This is the exact guarded backup/recovery entry point. It stops staging API writers, calls `docker exec supabase_db_maskan-staging-validation pg_dump -U supabase_admin -Fc postgres`, captures **binary bytes in Python**, and writes `staging-backup.private.dump`. Avoid PowerShell text redirection for binary dumps.

Role definitions/grants are obtained with `pg_dumpall --roles-only --no-role-passwords`. Existing recovery roles are preserved; missing roles and grants are recreated, and login passwords are set to distinct recovery-only values. `pg_restore --exit-on-error` restores only into `maskan-staging-recovery` after its database is recreated. The second container has a separate network, loopback port, volume and generated password. No production URL or arbitrary restore path is accepted.

Verification compares columns, indexes, RLS flags/policies, normalized ACLs, function definitions/owners/privileges and canonical row digests for public/private/auth/storage tables. ACL comparison expands default owner privileges so equivalent explicit/default forms are compared semantically; it does not discard permissions. Financial totals, archive count and cycle count are recorded. The full database archive includes service schemas; Storage object binaries are not covered by PostgreSQL dumps. No avatar object fixture is claimed restored.

A failed parity check raises an error and retains private diagnostic digests. Production recovery still requires separately verified hosted backups/PITR and Storage recovery, approval and a maintenance plan.

## Client and final checks

Run these sequentially, with staging Edge serving:

```powershell
python supabase/staging/run_suite.py shared
python supabase/staging/run_suite.py realtime
python supabase/staging/run_suite.py web
python supabase/staging/run_suite.py flutter
python supabase/staging/run_suite.py edge
python supabase/staging/run_suite.py sql
python supabase/staging/run_suite.py browser
```

`shared` creates a synthetic group from the web repository, injects a lost response after a real committed expense, joins and writes through the **actual updated Flutter repository**, exercises its legacy reset request path, approves from web, deletes a synthetic account through the actual local Edge handler, then verifies archived integrity and member departure from Flutter. This is not physical Android device evidence.

`web` runs TypeScript, ESLint, unit tests, actual four-client staging integration and a local production build. `flutter` runs analysis and the full ordinary suite; opt-in integrations are explicitly skipped there and run separately by `shared`/`realtime`. `browser` runs Chromium and iPhone WebKit emulation serially, separate from database load. No dashboard is published.

`run_suite.py` records command exit codes/durations and preserves previous failures in `suite-results.json`; private logs are not Git artifacts. See the Arabic readiness report and device checklist for conclusions and remaining gates.

References: [Supabase CLI source at the pinned version](https://github.com/supabase/cli/tree/v2.115.0/apps/cli-go), [PostgreSQL pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html), [PostgreSQL pg_restore](https://www.postgresql.org/docs/17/app-pgrestore.html), [Supabase changelog](https://supabase.com/changelog).

For test-transport-only changes, `python supabase/staging/run_suite.py web-regression` repeats TypeScript, ESLint, unit and integration checks without repeating the unchanged application build. Run `python supabase/staging/validate.py locks` for observed advisory-lock contention. Execute suites sequentially so the cumulative history remains ordered; individual command results are also saved separately.
