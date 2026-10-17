# Validation checklist and manual test plan

## Commands

From web-dashboard:

~~~powershell
npm ci
npm run typecheck
npm run lint
npm test
npm run build
npm audit --omit=dev
npx playwright install chromium webkit
npm run test:browser
npm run test:integration
~~~

Backend integration is skipped unless both local test environment variables are supplied. Never point it at production. Tests refuse any non-loopback host or port other than 54321.

From repository root:

~~~powershell
flutter analyze
flutter test test/money_utils_test.dart test/settlement_service_test.dart test/supabase_repository_mapping_test.dart test/phase_02_password_security_test.dart test/supabase_security_test.dart
flutter build apk --debug
~~~

## Manual four-device scenario (not yet physically executed)

Use a dedicated test backend/group, one Android client and three separate iPhone/web accounts. Separate browser profiles or private contexts avoid accidental shared identities.

1. Create the group on Android; join independently from three web clients. Verify four members and one shared network ID.
2. Reopen each client and verify the same member identity. Test wrong password, logout and subsequent login. Ensure metadata edits cannot claim another member.
3. Add 40.00 as the Android owner. Verify total 40.00, individual share 10.00, owner balance +30.00 and each other member -10.00 on all four clients.
4. Add 20.00 from web member B on behalf of member C. Verify paid-by versus added-by attribution and total 60.00 on every client.
5. Double-click submit and simulate a lost HTTP response/retry. Verify one row with one client-generated operation ID.
6. Edit only an author's active expense, then delete it. Attempt the same actions as another member using direct REST; verify rejection or zero affected rows.
7. Disconnect one web client, add on another, reconnect and return to the foreground. Verify eventual convergence without double-counting, including deleted records via fallback refresh.
8. Create a reset request as a non-owner. Confirm requester's initial approval; approve from the other clients. A newly joined member must not change the original required approval snapshot.
9. Verify one completed cycle, archived history and zero active balances after completion. Repeat completion and race completion against a write on an isolated backend; treat any extra cycle or stale-cycle expense as a release blocker.
10. Verify owner direct cycle behavior separately, including refusing duplicate requests while a reset is pending.
11. Verify notification actor exclusion, read/delete ownership, expense-edit messages and cycle notifications.
12. Reset another member's password as owner, test old/new password behavior and denied non-owner resets. Owner self-recovery should remain explicitly unavailable.
13. Verify profile initials/color, theme persistence, group logout/switch by credentials, zero-total leave behavior.
14. Test account deletion only with disposable users: incorrect password, owner-with-others refusal, last-member group confirmation, successful cleanup and expired/revoked session behavior.
15. As an unrelated group member/unauthenticated caller, query expenses, members, cycles, requests and notifications. No foreign rows may be returned. Verify view security_invoker behavior.
16. Confirm archived expense mutation is rejected by the backend after the reviewed server fix; client-only restrictions are insufficient.

## Responsive/accessibility checklist

- iPhone Safari at 390px and a narrow 320px viewport; Android Chrome; desktop Chrome, Safari and Edge.
- Portrait/landscape, keyboard open, safe-area bottom navigation, home-screen launch.
- No horizontal scrolling; Arabic shaping/RTL order; mixed currency/number readability.
- Tab navigation, visible focus, Enter submission, Escape/modal focus restoration.
- Long member/group names, empty group, no expenses, many records, unread notices.
- Loading, invalid credentials, missing config, offline reconnect, partial notification failure.
- Light/dark contrast and reduced-motion preference.
- No financial records in localStorage, Cache Storage or service-worker caches.
- No secrets/tokens/passwords in logs, screenshots or exported files.

## Interpretation of automated checks

Domain tests verify Flutter-compatible calculations, identity hashing, archived edit permissions, login sequencing, pagination and owner-reset guard behavior. Repository unit tests use controlled mocks; they do not prove RLS.

Browser tests intercept test-host responses. WebKit emulates an iPhone viewport on Windows; it is not physical iPhone Safari or desktop Safari certification. Backend tests are the separate, guarded integration suite.

Current run results are recorded in delivery-report-ar.md. Do not mark physical checks complete from a screenshot or a unit-test result.

## Final responsive regression coverage

Eight browser checks pass across Chromium and WebKit. Long-content cases cover all five dashboard sections and the expense dialog at widths 320, 390, 768, 1024 and 1440. Entry forms cover 320, 390, 768 and 1440. Assertions inspect both document width and visible element bounds; they do not rely on overflow hiding. Screenshot review covers desktop, phone and narrow settings.

The existing Android debug build also passed with this temporary PowerShell invocation from android/, avoiding the Kotlin daemon issue without changing project configuration:

~~~powershell
.\gradlew.bat assembleDebug '-Pkotlin.compiler.execution.strategy=in-process' --max-workers=2 --console=plain
~~~

For a short manual local UI check: switch among all five sections, resize to 320px, open and close the expense dialog, toggle dark mode, and verify long group/member names wrap. Perform write workflows only in a disposable test backend; the delivered local configuration points to the existing backend.