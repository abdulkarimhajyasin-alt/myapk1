# Maskan Web Dashboard

Arabic-first RTL user application for the existing Maskan backend. This is an isolated Next.js/TypeScript frontend, not a replacement Android app or an admin portal.

**Delivery status: local implementation, not approved for production deployment.** Read [the architecture and security review](docs/architecture-security.md) and [validation checklist](docs/validation.md). Backend cycle/archival findings require review before public launch.

## Run locally

Use Node.js 22.13+ (validated with Node 24.15.0).

~~~powershell
cd F:\myapkprojekt\web-dashboard
npm ci
Copy-Item .env.example .env.local
# Set NEXT_PUBLIC_SUPABASE_ANON_KEY to the existing project's public legacy anon JWT key.
npm run dev
~~~

Open http://127.0.0.1:3000. In this delivered workspace, an ignored .env.local was prepared from the existing Android development configuration using only its verified public key; do not overwrite it unnecessarily.

~~~powershell
npm run typecheck
npm run lint
npm test
npm run build
npm start
~~~

Only NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY are required. The deployed maskan-password function (version 3) has verify_jwt=true, so this existing backend requires the legacy public anon JWT; new sb_publishable keys are rejected until the function gateway configuration is separately reviewed. The template points to skngodvomygvxemfaefn. Never place service-role keys, secret keys, user passwords, or deployment credentials in public environment variables.

## Features

- Existing member login, create group/owner, join group; same AuthV2 identity and password Edge Function as Android.
- Database-authorized membership, complete paginated group data, integer input parsing and Android-compatible settlements.
- Add expenses for any member; author-only active expense editing/deletion; duplicate-submission IDs; history and cycle/member filters.
- Financial overview, contributions chart, settlement details, notifications with read/delete actions.
- Owner direct cycle start, member reset requests, snapshot approvals and existing completion RPC.
- Profile initials/color settings, owner password reset for other members, logout, leave group, password-confirmed account deletion.
- Debounced Realtime invalidation, resubscribe refresh, 20-second foreground refresh, online/focus recovery.
- Responsive mobile/desktop RTL, light/dark modes, touch targets, dialog keyboard behavior.
- PWA manifest and PNG icons for home-screen installation. No offline financial cache, no service worker.

The only synthetic users/figures are isolated test fixtures under tests/. The production UI contains no sample statistics.

## Existing backend boundaries

There is one Auth identity per member, not a universal multi-group account. Switch groups by signing out and logging into another existing membership. Password recovery is owner-mediated; no email recovery or self-reset for the owner is supported by the existing backend. Account deletion may refuse an owner while other members remain; the backend has no ownership transfer UI/API implemented here.

The web client treats the pending reset request as authoritative. Production does not grant UPDATE on expense_cycles.status, so it does not repeat Android's denied pending-marker write. Completion still uses the original server RPC and original approval snapshot. No production schema changes were made.

## Browser checks

~~~powershell
npx playwright install chromium webkit
npm run test:browser
~~~

These tests use synthetic intercepted HTTP responses and a fake anon-format key; they do not access production user data. They exercise desktop Chromium and an iPhone viewport using WebKit. They are not physical Safari/iPhone testing.

## Four-client backend integration

The integration test deliberately refuses remote databases. Prepare a **disposable local** Supabase instance using the repository's migrations and both maskan-password and maskan-delete-account Edge Functions; enable the same app-managed sign-up behavior as Android. Verify CLI flags with --help for your installed CLI. Docker must be running. Do not reset a database containing valuable local data.

~~~powershell
$env:MASKAN_TEST_SUPABASE_URL = "http://127.0.0.1:54321"
$env:MASKAN_TEST_ANON_KEY = "<local anon key>"
npm run test:integration
~~~

Without both variables the test is explicitly skipped. Fixtures have unique web-test- prefixes and are retained for inspection. Reset only the disposable local test instance yourself after inspection. No production cleanup is attempted. One protocol client stands in for Android; three independent clients represent web memberships.

## Deployment preparation

Build this directory as a standalone Node-hosted Next.js application. Configure the two public environment values at build time, HTTPS, security headers, domain ownership and DNS for maskan.karamixlabs.com. A managed Next.js host or a Node reverse-proxy deployment can host it. No hosting account or DNS records were changed.

Do not deploy until backend security/cycle issues are reviewed, live isolated integration tests pass, and the cross-device checklist is completed. Existing karamixlabs.com/maskan/join links need an intentional landing-page routing update for the new domain while preserving Android deep links. Public deployment and main-branch merge require separate authorization.

## Remaining scope

- Live local integration could not run without Docker; backend concurrency and destructive workflows are not certified.
- Browser tests are fixtures; real account login/create/join/reset/delete must be checked in an isolated backend.
- Profile photo upload/camera QR scanning, push delivery, native PDF sharing and owner password self-recovery are not implemented in this web frontend. Core profile fields and in-app notifications are implemented.
- Group data is loaded fully to preserve totals; very large histories would benefit from a reviewed aggregate RPC and paginated history UI. REST snapshots are eventually consistent, not a database transaction.
- Request creation, approvals, and notifications follow existing multi-step contracts; interrupted operations may require refresh and approval retry. No new atomic RPC or outbox was invented.
- Tab-scoped session storage requires login in a separate tab/new installed-app context. Theme alone uses localStorage.
- Five high-severity development dependency findings trace to an unpatched braces dependency in Next's lint tooling. Runtime-only audit was clean; see security review.
