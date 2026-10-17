# Architecture decision and security review — 2026-10-17

## Objective and affected files

Add web-dashboard/ as an independent Arabic-first user application sharing Android's exact Supabase project, membership records, expenses, notifications and cycles. All implementation, tests, assets and documents are inside web-dashboard/. Android source, root dependencies, migrations and Edge Functions remain unchanged. Pre-existing modified/untracked files are excluded from commits.

## Existing architecture and decision

Flutter screens call ExpenseNetworkRepository and SessionRepository. SupabaseExpenseNetworkRepository hydrates safe network/member views plus expenses, cycles and approval tables. SupabaseAuthIdentity bridges app credentials to deterministic Supabase Auth identities. SettlementService and MoneyUtils define financial semantics. SupabaseRealtimeService invalidates data. AccountDeletionService delegates destructive work to an authenticated Edge Function.

Choose Next.js + TypeScript for independent DOM-based RTL design, accessibility, responsive Safari behavior and isolated tooling. Flutter Web would reuse more widgets but couples a distinct dashboard design to Android screens/plugins. No business-rule migration or new user directory is introduced. Public UI is statically prerendered; private data is fetched only after browser authentication. No server-side privileged backend client exists.

Implementation layers: typed models; pure money/identity functions; Supabase repository; Realtime invalidation; React view components. This keeps authorization in the existing database/Edge Functions while avoiding UI-specific SQL and duplicate calculation rules.

## Audited contracts

| Area | Existing source and behavior | Web behavior |
| --- | --- | --- |
| Identity | supabase_auth_identity.dart, AuthV2 SHA-256 technical credential; maskan-memberId@auth.maskan.app | Exact UTF-8 derivation and email mapping |
| Password authority | maskan-password verify_member, PBKDF2, rate limits, expiring claim token | Verify first, sign in, claim; passwords never logged |
| Create/join | create_network/join_network Edge actions; transactional password RPCs | Same IDs, payloads, currency catalog and authenticated identity |
| Membership | network_members.auth_user_id; maskan_current_member_id | Server RPC resolves membership; metadata never authorizes |
| Read models | maskan_networks/maskan_network_members security_invoker views | Same views; no private credential table reads |
| Expenses | integer cents; payer can differ from author; author-only edit/delete; archived UI immutable | Same fields, author and archive filters, row-return verification |
| Totals | current unarchived expenses assigned to existing members | Same rule, including orphan exclusion |
| Settlements | equal fractional-cent share; >0.5-cent transfer threshold in member creation order | Golden tests match Flutter; no alternate rounding algorithm |
| Reset | owner immediate cycle; others snapshot member approvals | Same complete RPC; pending request drives display |
| Notifications | expense, expenseUpdated, resetRequest, cycleStarted | Same recipient payloads and enum spelling; partial notification failure surfaced |
| Leave | maskan_leave_network, only settled/zero active-total group | Existing RPC and precheck |
| Deletion | maskan-delete-account, re-verification, owner/last-member constraints | Password plus explicit confirmations; local session cleanup |
| Recovery | owner resets other member passwords | Same Edge action; no email system invented |

Registration and join retain operation identities for same-form retries. Expenses retain a client-generated ID and verify matching existing row on a uniqueness conflict. This prevents duplicate expense inserts after a lost response; it does not make notification delivery exactly once.

## Live read-only production audit

Inspected deployed Edge Function source/configuration, pg_policies, effective column privileges, safe-view options, relevant function definitions and Supabase security advisor output for skngodvomygvxemfaefn. No production rows were inserted, updated or deleted. No migration was applied.

Confirmed:
- RLS enabled on all seven public base tables.
- Both safe views have security_invoker=true.
- Membership resolves from auth.uid() and auth_user_id, not user-editable claims.
- Effective authenticated UPDATE on membership network_id is false; profile-only column grants prevent reassignment despite the broader self-update RLS predicate.
- Expense network/author IDs are not updateable by the authenticated role.
- Current-member claim checks authenticated identity, hashed claim token and expiry, then consumes the claim.
- Completion RPC checks caller membership, owner for direct completion, or full required approvals.
- Private rate-limit/authorization tables have RLS and no client policies; that is deliberate deny-by-default, not a reason to add policies.

## Findings requiring review before production launch

1. **Archived expense integrity:** live grants permit the expense author to update archived_at, cycle_id and payer fields. Update/delete policies do not require archived_at IS NULL. The web client forbids archived edits/deletes, but direct REST callers can bypass that client restriction. Review narrow grants and server-side active-expense restrictions without breaking the existing Android release.
2. **Cycle concurrency/idempotency:** maskan_complete_expense_cycle does not lock/verify an active cycle before all side effects and does not reject repeating direct completion of an already closed cycle. Concurrent completions or expense insertion during closing can race. Review a network/cycle lock shared by expense insertion and completion, an active-cycle uniqueness invariant, and idempotent completion. Do not auto-apply changes.
3. **Pending marker mismatch:** authenticated users cannot UPDATE expense_cycles.status in production. Existing Android code attempts that after creating the request/approval. Web uses the existing pending request to display the pending state and skips that denied write. A future reviewed atomic request RPC would improve both clients.
4. **Multi-step resets/notifications:** interrupted requests can leave a request without the initiating approval or without notifications; manual retry of approval is available. Notification failure is reported without falsely claiming the expense failed. Consider a transactional RPC/outbox in a separate reviewed change.
5. **Function privileges:** advisor reports 10 SECURITY DEFINER functions executable by anon and 21 by authenticated. Some authenticated calls are intentional and perform explicit checks. Revoke unnecessary anon grants after dependency review, particularly legacy phase5 predicate helpers. See [advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable).
6. **search_path:** phase5_prevent_notification_identity_update has mutable search_path. Review fixed qualification before deployment. [Guidance](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable).
7. **Leaked password protection disabled:** Supabase advisor flagged this. App passwords are verified in the custom Edge workflow, so enabling the Auth setting alone does not protect that original password; review the custom credential policy.
8. **Logout/revocation:** local scope revokes the web session, not other devices. Deletion uses existing server cleanup; already issued JWT expiry/revocation behavior needs isolated verification.
9. **Dependency tooling:** runtime npm audit --omit=dev reported zero vulnerabilities. Full audit reported five high findings in the eslint-config-next → fast-glob → micromatch → braces chain (one root advisory, [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm)). Registry braces latest was 3.0.3 with no patched release. Do not downgrade Next to an incompatible major or force an audit fix. Do not run lint against untrusted patterns; monitor upstream. ESLint 9 is retained for the current Next plugin peer ranges despite its upstream deprecation; upgrade the lint stack together when compatible plugin releases are available.

These are findings from definitions/grants, not claims that exploitation was exercised against production.

## Browser security and operational limits

Only public legacy anon JWT credentials enter the bundle. The deployed maskan-password version 3 has verify_jwt=true, so config rejects new publishable keys until that gateway is separately reviewed. The deployed maskan-delete-account version 5 has verify_jwt=false and authenticates the bearer inside its code. Config rejects service-role JWTs and sb_secret keys. Auth tokens use sessionStorage; financial data stays in memory; SDK fetch requests use cache:no-store. Theme alone persists in localStorage. No service worker caches responses. Rendering uses React text escaping; no raw HTML injection. CSP blocks framing/objects and limits connections to Supabase and local test API; no external font/image requests. Next's inline bootstrap currently requires unsafe-inline; a nonce-based SSR deployment would strengthen CSP in a future reviewed change. Dev only permits unsafe-eval for the dev runtime.

There is no cookie-authenticated BFF, so cookie SameSite/CSRF mechanics are not introduced. Token storage remains exposed to any same-origin script compromise; do not add untrusted scripts or analytics casually. Browser build success does not certify backend security.

## Validation and risk control

No Android functionality removed. No database duplication, authentication replacement, service-role browser client, production migrations, deployment or main merge. Existing working-tree changes preserved. Run exact commands and manual checks from validation.md. Deploy only after reviewed backend fixes and isolated integration verification.

Official implementation references: [Next.js installation](https://nextjs.org/docs/app/getting-started/installation), [Supabase function invocation](https://supabase.com/docs/reference/javascript/functions-invoke), [Realtime subscriptions](https://supabase.com/docs/reference/javascript/subscribe), [Supabase changelog](https://supabase.com/changelog).
