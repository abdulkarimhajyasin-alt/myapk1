# Maskan Privacy Policy Draft

Last updated: August 26, 2026

This repository copy is an implementation-aligned draft. It must be published
and reviewed at https://karamixlabs.com/maskan/privacy before Google Play
submission.

Maskan helps private shared-housing groups track expenses and settlements.

## Information processed

Maskan stores a technical Supabase Auth identity, member/display name, network
name and settings, shared expenses and optional notes, cycles, reset requests
and approvals, activity notifications, optional avatar preferences/image, and
session metadata. Members of the same private network can see that network's
shared data.

Application credentials are verified on the server. New credentials use
versioned PBKDF2-HMAC-SHA256 digests; legacy hashes are migrated. Raw
application passwords are not stored. Short-lived hashed claim/deletion tokens
and short-lived rate-limit counters protect sensitive operations.

## Services and security

Supabase provides Auth, PostgreSQL, Realtime, Storage, Edge Functions, and
operational logging. Maskan uses encrypted HTTPS/WSS transport and does not put
the Supabase service-role key in the app.

Maskan does not include advertising or analytics SDKs. Current Android
notifications are local notifications created from Realtime activity while the
app is active; Maskan does not currently collect FCM/device push tokens.

Camera access is used only to scan invite QR codes. Optional avatars use the
system photo picker rather than broad media-library permission. Settlement
PDFs are generated on the device and shared only when the user chooses a
destination.

## Account deletion and retention

Users can choose Delete Account in the authenticated account screen and must
re-enter their account password. A sole member must explicitly confirm
deletion of the entire network. A network owner with other members must
transfer ownership before deletion.

Deletion removes the Supabase Auth user, private member credential/claim rows,
avatar objects, recipient notifications, and the member row. If other members
remain, shared financial history remains available to them but the deleted
member identifiers and display name are removed and replaced with “Deleted
account.” Affected pending reset requests are cancelled. If the deleted user
is the sole member, the network and its shared data are deleted.

An external account-deletion request page must be available at
https://karamixlabs.com/maskan/delete-account.

Supabase operational-log retention must be stated after confirming the
production project configuration.

## Data sharing

Maskan does not sell personal data or use it for advertising. Supabase
processes cloud data as Maskan's service provider. Users can intentionally
share generated PDFs through destinations they select on their device.

## Contact

Publish a working Karamix Labs privacy contact with the final public policy.
