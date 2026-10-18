# Backend hardening: design, verification, rollout and recovery

Source-only delivery on `security/maskan-backend-hardening`, based on dashboard commit `7fab19e`. No production SQL, project settings, Edge deployment or public web deployment has been performed. Unrelated working-tree changes are excluded.

## Objective and implementation plan

Keep the existing tables, Flutter AuthV2, REST payloads, RLS membership authority and boolean completion RPC. Enforce integrity on the server. Baseline checks precede edits; then review both clients, prepare one migration, test actual isolated SQL/REST/Auth concurrency, run client checks serially, inspect secrets, commit and push only the security branch. Production approval is separate.

Migration: `20261017194224_harden_expense_cycles_and_reset_workflows.sql`. It drops no table and deletes no financial row. Preflight aborts on duplicate open cycles, unarchived expenses assigned to closed/foreign cycles and unsafe historical pending voter snapshots. Existing valid pending requests receive a missing initiating vote, missing reset notices and pending marker. They are not auto-completed by migration. Inconsistent records require manual review, not guessed repairs.

## Server enforcement and locking

- Active expense authors retain amount/note edits and deletes. RLS excludes archived rows. An INVOKER trigger protects identity, payer, cycle, archive state and operation ID. New rows require an open cycle and server-derived names. Explicit stale cycles fail; legacy null cycles resolve to the current open cycle.
- An operation ID is scoped by network. Exact matching includes network, cycle, author, payer, amount, note and key. Different contents with the same key raise expense_operation_conflict, not a misleading unique/duplicate success. Different keys remain distinct expenses, even with identical contents.
- Verified account deletion can redact member identity while preserving archived amounts. Trusted lifecycle functions, administrators and cascades are intentional exceptions to client immutability. No user-controlled session flag bypasses guards.
- A partial unique index covers active and pending_reset. The existing cycle-number constraint remains. Completion returns true once and false on an authorized repeat. Direct owner completion cannot bypass pending votes.
- RPCs take a per-network transaction advisory lock before cycle/request/member row locks. Direct REST triggers use a try-lock because PostgreSQL may already hold a tuple lock: a conflict raises SQLSTATE 40001 instead of waiting in an inverse lock order. Networks operate independently; hash collisions merely serialize unrelated work.
- Closure, archive, next cycle, request completion and notices are one transaction. Last legacy approval completes even if the client disconnects. Failure rolls all effects back.
- Membership insertion/removal, leave and verified deletion share the network lock. After waiting, RPCs recheck durable membership. Cancellation restores the active marker; member removal cancels affected pending requests.

## Android and web compatibility

The published Android interfaces remain: direct request INSERT, initial approval INSERT, pending-marker UPDATE, merge-upsert approval and boolean completion RPC. Triggers derive voters, the initiating vote and notices. Narrow extra cycle/approval column grants are constrained by field-preserving triggers and own-member RLS. Duplicate votes become no-ops. Completed requests and approval votes are not client-deletable. Redundant legacy reset/cycle notifications are suppressed because the server writes them transactionally.

New web clients use maskan_request_expense_reset and maskan_approve_expense_reset, falling back only on PGRST202 before migration deployment. Permission/transport errors never trigger a second legacy write.

Web and updated Android retry network_busy_retry at most twice with the same operation key and original cycle. Stale-cycle, unknown transport and genuine operation conflicts are not silently retried. Both expense forms preserve the attempt key on unchanged resubmission and allocate a new key for changed input. Both clients verify all canonical fields when resolving an existing operation. Arabic/English Android and Arabic web messages explain conflicts. Published older Android binaries remain protocol-compatible, but do not gain the improved retry UX until a separately approved release. Physical-device testing is still required.

## Function and authentication audit

See [all 59 signatures with owner, security context and effective role grants](backend-function-inventory.md). The application functions in the local migration chain are owned by postgres. All SECURITY DEFINER functions have fixed search paths. No application SECURITY DEFINER function remains executable by anon.

| Function family | Legitimate caller and authority |
| --- | --- |
| current_member/current_network/is_network_member/is_current_member | Authenticated RLS helpers resolving auth.uid against durable membership; foreign targets return empty/false. |
| can_create_active_cycle | Authenticated initial-cycle policy: membership, no open cycle, exact next number; unique index handles races. |
| complete_expense_cycle | Authenticated member; owner or full matching-network vote snapshot; state/lock checks and idempotent side effects. |
| request_expense_reset / approve_expense_reset | Authenticated member, rechecked after lock; server voter snapshot, matching-network IDs, own durable vote. |
| claim_member | Authenticated user with hashed capability bound to member/Auth user; locked, one-use, wall-clock expiry and unique membership. |
| password_lookup_network/member/find_auth_user | Service-role Edge only; verification material never granted to client roles. |
| password_create_network/join_network | Service-role Edge after Auth/network-password verification; modern digest contract, exact verified network digest, unique membership/name constraints. |
| password_upgrade_network/member/mark_auth_synced | Service-role Edge; credential versions and downgrade trigger. Legacy FNV exists only for compatibility verification. |
| password_issue_claim/reset_context/reset_member | Service-role Edge; Auth binding, owner and same-network target, no owner self-reset, claim invalidation on password reset. |
| password_rate_limit_* | Service-role Edge; validated scope/hash and atomic counters. Account-normalized keys cannot be bypassed by changing forwarded IP headers. |
| account_deletion_context/rate_limit_check/rate_limit_failure | Authenticated own auth.uid, no caller-selected user ID. Rate-limit increments cannot authorize deletion. |
| authorize_account_deletion | Service-role Edge after reauthentication; short-lived hashed capability bound to Auth user. |
| delete_account_data / leave_network | Authenticated durable membership; one-use capability for deletion, owner/last-member constraints, deterministic network lock, authorized redaction/cascades. |
| Retired discover/verify/create/join/claim_legacy and phase5_reset_member_password | Preserved migration definitions; no anon/authenticated execution. |
| Nine phase5 lookup predicates | No longer referenced by current policies or clients; PUBLIC/anon/authenticated execution revoked. Definitions retained. |
| Private guard/finish functions | Trigger-only with client EXECUTE revoked. INVOKER guards protect writes; narrow DEFINER finish functions act after validation. |
| phase5_prevent_notification_identity_update | Empty search_path; clients can only change read state, trusted deletion can redact actors. |

Deletion uses the durable database context, not user_metadata. Only a retry after database deletion derives the UUID from Auth-verified technical email and reauthenticates the same Auth user. Global refresh-session revocation precedes Auth deletion. Already issued JWTs can remain cryptographically valid until expiry; removed membership blocks application reads immediately. Ordinary logout retains standard JWT-expiry semantics; strict session_id enforcement everywhere requires separate compatibility review.

Password logging uses fixed classifications; malformed JSON cannot echo request fragments. PBKDF2/technical AuthV2 behavior is preserved. Deno type fixes copy the salt into a compatible buffer and type response headers without changing derivation. No keys rotated and no live authentication setting changed.

## Performance and remaining risks

Ten justified FK indexes cover ownership/requester/cycle/member/notification references and claim Auth cleanup. Catalog inspection found no missing leading FK index in public/private. Existing indexes were not removed based on usage counters. Updated own-author policies use scalar helper subqueries; broad policy rewrites require measured plans.

Transactional indexes use lock_timeout 5s and statement_timeout 60s. Rehearse relation size and locks on staging; large/busy production may abort safely. A concurrent-index rollout would need a separate reviewed plan.

Full npm audit retains five high development-tool findings in the braces/Next lint chain. Runtime audit is clean. The suggested forced fix changes the Next lint major incompatibly; no forced upgrade was performed. Account quotas can temporarily lock out a target under deliberate abuse; monitor and review trusted-gateway throttling. Leaked-password protection, signup abuse controls, password policy and the legacy verify_jwt gateway remain settings/product review items.

Storage/Auth deletion spans services, so partial-failure recovery needs staging verification. Local tests do not certify physical Android/iPhone behavior or production-scale contention. No production finding is marked deployed/fixed by this source delivery.

## Rollout: explicit production approval required

1. Compare actual production definitions, owners, grants, migration history, trigger names and indexes read-only with this inventory. Review any preflight failures manually.
2. Take a verified backup/PITR point and securely record previous definitions/grants and Edge versions. Rehearse restoration and index creation on isolated staging.
3. Run the full migration chain and upgrade-path tests locally/staging; verify published Android payloads and physical clients manually.
4. After approval, apply only this reviewed migration in a quiet window through the approved process. Its transaction commits fully or rolls back. Verify cycle uniqueness, pending votes/markers, archived denial, active author edits, cross-network isolation, function privileges and search paths. Never run destructive fixtures on production.
5. Deploy reviewed Edge sources only with separate approval. Release Android/web separately after approval. Existing endpoints remain compatible and the web supports missing-RPC fallback. No secret rotation is needed.
6. Monitor 40001/23505, closure latency, pending age, duplicate events, rate limiting and deletion failures using counts/classifications, without passwords/tokens/user records.

## Rollback and recovery

- Failed SQL/preflight/index work rolls back atomically; fix the cause on staging.
- For application regressions, restore recorded Edge/web artifacts while keeping server integrity guards. Old client interfaces remain supported.
- After a committed migration, prefer a reviewed forward fix and temporarily suspend affected writes operationally. Never unarchive history, reset closed cycles or replay completion as a repair.
- Full rollback is not automatically safe after new votes/cycles/notices exist. Obtain approval, stop writes, restore a verified backup/PITR into an isolated recovery target, reconcile subsequent writes and cut over after integrity checks. Do not drop history or reinstate vulnerable grants with a blanket down migration.

## Reproduce verification

From the repository root with Docker running:

```powershell
powershell -ExecutionPolicy Bypass -File supabase/tests/run_backend_hardening.ps1 -ResetDisposableDatabase
node --import ./web-dashboard/node_modules/tsx/dist/loader.mjs --test supabase/tests/edge_hardening.test.mts
npx --yes deno check supabase/functions/maskan-password/index.ts supabase/functions/maskan-delete-account/index.ts
flutter analyze --no-pub
flutter test --no-pub
```

The harness uses only project maskan-hardening-local and API 127.0.0.1:55321. It rejects remote Docker/API targets. The explicit reset switch removes only this dedicated stack's synthetic fixtures. CLI startup keys stay in its ignored local log. Never share that log.

For actual Auth/Edge integration, serve functions in another terminal:

```powershell
npx --yes supabase functions serve --workdir .codex_tmp/maskan-hardening-local
```

Capture local CLI status into shell variables without printing credentials. Set MASKAN_TEST_SUPABASE_URL to http://127.0.0.1:55321 and MASKAN_TEST_ANON_KEY to that stack's public anon key. Run npm run test:integration from web-dashboard. Tests reject remote hosts and unexpected ports.

Run web typecheck, lint and unit checks, then npm run build and npm audit --omit=dev. Run npm run test:browser -- --workers=1 after heavy test processes finish. No timeout or assertion is weakened. Run browser tests separately from heavy database/Flutter concurrency checks; do not hide a failed assertion with retries. Browser fixtures are separate from real local Auth/REST tests.

References: [PostgreSQL locks](https://www.postgresql.org/docs/current/explicit-locking.html), [Supabase function security](https://supabase.com/docs/guides/database/functions), [Supabase security guidance](https://supabase.com/docs/guides/security/product-security).

### Additional real integration checks

The local harness includes Realtime. Set LOCAL_SUPABASE_API_URL and LOCAL_SUPABASE_ANON_KEY from captured local CLI status, then run flutter test --no-pub test/supabase_realtime_local_integration_test.dart. This tests actual Auth, Edge, REST and Realtime with synthetic accounts. Without those variables the general Flutter suite explicitly skips that one test.

For upgrade rehearsal, stop all test writers, reset only the dedicated stack to the previous migration, then run:

```powershell
npx --yes supabase db reset --local --no-seed --version 20260826000000 --workdir .codex_tmp/maskan-hardening-local --yes
python supabase/tests/upgrade_hardening.py
```

The upgrade script deliberately applies unsafe synthetic pending data first, verifies transactional rollback, repairs only its own fixture and verifies a valid upgrade. It applies SQL through the fixed local Docker container; its manual psql application does not record Supabase migration history. Afterwards use the harness reset to replay and record the full chain normally. Never use this test procedure on a shared or production database.
