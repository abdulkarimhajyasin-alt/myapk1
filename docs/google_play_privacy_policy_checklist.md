# Maskan Privacy Policy Consistency Checklist

Checked: 2026-08-26

Required public URL:
https://karamixlabs.com/maskan/privacy

The URL currently returns GitHub Pages “404 File not found.” Therefore public
policy consistency is not verified and publishing the updated page is a
mandatory external next step. This repository does not modify the Karamix Labs
website.

## Required public-policy content

- [ ] Identify Karamix Labs as controller/contact and provide a working privacy
  contact.
- [ ] List actual cloud categories: technical Auth identity, member/display
  name, network data, expenses/notes, cycles/resets/approvals, notifications,
  optional avatar, and session metadata.
- [ ] Explain Supabase processing: Auth, PostgreSQL, Realtime, Storage, Edge
  Functions, and limited operational logs.
- [ ] State that new application credentials use server-side
  PBKDF2-HMAC-SHA256 and that legacy material is migrated; raw application
  passwords are not stored.
- [ ] Explain the technical Supabase Auth identity and session purpose without
  exposing implementation secrets.
- [ ] State that current notifications are local notifications based on
  Realtime activity and that no device push token/FCM background push is
  collected.
- [ ] Explain optional avatar upload, its public Storage delivery behavior, and
  deletion of all member-prefix objects during account deletion.
- [ ] Document in-app account deletion and the external request URL
  https://karamixlabs.com/maskan/delete-account.
- [ ] State owner rules: sole member confirms deletion of the entire network;
  an owner with other members must transfer ownership first.
- [ ] State retention behavior: shared financial history remains for the other
  members but is detached from the deleted member and labeled “Deleted
  account”; recipient/private rows and credentials are removed.
- [ ] State the retention period/configuration for Supabase operational logs
  after checking the production project settings.
- [ ] Disclose camera use for QR scanning, Photo Picker use for avatars, and
  user-initiated PDF sharing.
- [ ] Match the final Google Play Data safety declarations.

## Repository draft

docs/privacy_policy.md is the current implementation-aligned draft. It is not
evidence that the public URL has been updated.
