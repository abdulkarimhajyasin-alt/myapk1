# Maskan Google Play Data Safety Inventory

Last verified against the repository: 2026-08-26

This is an implementation inventory for completing Google Play's Data safety
form. It is not a substitute for checking the exact Play Console questions and
service-provider exemptions at submission time.

## Processing summary

- Cloud processor: Supabase (Auth, PostgreSQL, Realtime, Storage, Edge
  Functions, and operational logs).
- Transport: the production client uses Supabase HTTPS/WSS endpoints, so data
  is encrypted in transit.
- Advertising/analytics SDKs: none found in pubspec.yaml, Android Gradle
  dependencies, or application source.
- Background push tokens: not collected. Current Android notifications are
  local notifications generated from Supabase Realtime events while the app is
  active.
- Sale or advertising use: none implemented.
- Account deletion: available in the authenticated account screen. The trusted
  backend deletes the Auth user, private credential and claim rows, avatar
  objects, recipient notifications, and the member row.

## Data-type inventory

| Data type | Collected | Sent to server | Purpose | Required / optional | Service-provider processing | Encrypted in transit | Deletion behavior |
|---|---:|---:|---|---|---|---:|---|
| Supabase Auth user UUID and technical email | Yes | Yes | Authentication, account isolation, authorization | Required for a cloud account | Supabase Auth | Yes | Auth user is deleted by the trusted deletion Edge Function |
| Member/display name | Yes | Yes | Displaying the member in their private shared network | Required | Supabase database/realtime | Yes | Member row is deleted; retained shared history is relabeled “Deleted account” |
| Network name, network UUID, currency, ownership | Yes | Yes | Create/join and operate the shared expense network | Required to use the app | Supabase database/realtime | Yes | Sole-member deletion removes the full network; non-owner deletion preserves the other members' network |
| Expense amount, payer/actor, date, note, cycle | When entered | Yes | Shared expense tracking, settlement, and history | Optional until a member records an expense | Supabase database/realtime | Yes | Individual expenses can be deleted in-app; account deletion removes the account link/name but preserves shared financial history for other members |
| Reset requests and approvals | When used | Yes | Coordinating a new expense cycle | Optional | Supabase database/realtime | Yes | The deleted member's approvals are removed; pending affected requests are cancelled and member identity is removed |
| Notifications/activity rows | When activity occurs | Yes | In-app activity and local Android notification display | Optional/derived | Supabase database/realtime | Yes | Recipient-only rows are deleted; shared actor references are anonymized |
| Avatar color/initials | Yes | Yes | Profile display | Optional | Supabase database | Yes | Deleted with the member row |
| Avatar image and storage path/public URL | When uploaded | Yes | Optional profile photo | Optional | Supabase Storage/database | Yes | Every object under the member's storage prefix is deleted before account data deletion |
| Application credential digest and legacy migration material | Yes | Yes | Member/network password verification | Required for password-protected account/network flows | Supabase private schema and Edge Functions | Yes | Member credential cascades with member deletion; sole-member network deletion also removes the network credential |
| Short-lived member claim token hash | During login/claim | Yes | Bind a verified member to Supabase Auth | Temporary | Supabase private schema | Yes | Consumed on login, expires quickly, and cascades on member/Auth deletion |
| Supabase access/refresh session | Yes | Yes; token also cached locally | Keep the user authenticated and authorize RLS | Required while signed in | Supabase Auth; local app storage | Yes | Server sessions end when Auth user is deleted; cached tokens are cleared locally |
| Account-deletion authorization/rate-limit row | During deletion attempts | Yes | Reauthentication enforcement and abuse prevention | Required only for deletion flow | Supabase private schema/Edge Function | Yes | One-use authorization is consumed; rate-limit row is deleted with account data/Auth user or expires |
| Password-operation rate-limit hash/counters | During password operations | Yes | Brute-force protection | Required for protected operations | Supabase private schema/Edge Function | Yes | Keys are one-way hashes, contain no raw identifier, and expire after the short rate-limit window |
| Operational diagnostics | On errors/requests | Limited | Reliability and security operations | Derived | Supabase platform/Edge logs; local Flutter debug logs | Yes when sent | Edge code logs only a controlled failure classification; retention must be confirmed in the Supabase project settings |
| Analytics events or advertising identifiers | No | No | Not implemented | Not applicable | None | Not applicable | Not applicable |
| FCM/device push token | No | No | Background push is not implemented | Not applicable | None | Not applicable | Not applicable |
| Camera image/video | No | No | Camera is used only to scan an invite QR code | Optional action | On-device scanner | Not sent by the app | No capture is retained by Maskan |
| Settlement PDF | When generated | No automatic upload | User-requested report/export | Optional | Generated on device; destination is chosen by user | Depends on user-selected sharing destination | Controlled by the user/device destination |

## Shared-versus-collected notes

- Members of the same private network can see that network's member, expense,
  cycle, and activity data. This is an app function, not advertising.
- Supabase processes cloud data as the application's service provider. At form
  submission, confirm whether each disclosure qualifies for Google Play's
  service-provider exception before marking data as “shared.”
- User-entered network names and expense notes can contain content chosen by
  the user. The app does not infer whether free text contains personal data.

## Evidence paths

- pubspec.yaml
- android/app/src/main/AndroidManifest.xml
- lib/services/supabase_expense_network_repository.dart
- lib/services/member_avatar_photo_service.dart
- lib/services/push_notification_service.dart
- lib/services/supabase_session_repository.dart
- supabase/migrations/20260820000000_migrate_password_security.sql
- supabase/migrations/20260825000000_add_password_rate_limits.sql
- supabase/migrations/20260826000000_add_account_deletion.sql
- supabase/functions/maskan-password/index.ts
- supabase/functions/maskan-delete-account/index.ts
