# Maskan Play Store Readiness

## App Identity

- App name: Maskan
- Android applicationId: `com.expensenetwork.app`
- Data source: Supabase cloud only
- Publisher/brand footer: Karamix Labs

## Release Build Checklist

- Confirm compileSdk and targetSdk are API 36.
- Build signed APK:
  `flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
- Build Android App Bundle:
  `flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
- Keep the existing permanent release keystore and GitHub Actions signing secrets.
- Do not change `applicationId` for existing installs.
- Verify Arabic and English screenshots on Android.
- Verify notification permission prompt on Android 13+.
- Verify camera permission copy appears when using **Scan Invite**.
- Verify Supabase production anon key, schema, realtime publication, and RLS policies.
- Verify QR invite scanning and custom deep links open the shared cloud join flow.
- Verify settlement PDF export in Arabic and English with embedded Arabic fonts.

## Store Listing Assets Needed

- 512 x 512 app icon
- Feature graphic: 1024 x 500
- Phone screenshots in Arabic and English
- Short description in Arabic and English
- Full description in Arabic and English
- Privacy policy URL
- Public account-deletion URL:
  https://karamixlabs.com/maskan/delete-account
- Support contact email

## Data Safety Notes

- Supabase stores network, member, expense, reset, notification, session, and
  optional profile metadata.
- Passwords must remain hashed and salted; raw passwords are not stored.
- The app does not require a service-role key in the client.
- Push-1 notifications are local notifications triggered by in-app realtime events.
- Production background push requires FCM/server-side delivery in a later Push-2 phase.
- Camera access is used only for scanning Maskan invite QR codes.
- Invite QR codes and share messages use
  `https://karamixlabs.com/maskan/join?network={networkId}` because chat apps
  reliably auto-link HTTPS URLs. The app also keeps parsing
  `maskan://join/{networkId}` for direct app opens.
- The Karamix Labs website should host `/maskan/join` before launch or clearly
  document that the page is an install/copy-code landing page, not a full web
  version of Maskan.
- Leaving a network is membership-only and is available only to a non-owner
  when shared active expenses are settled.
- Delete Account is a separate re-authenticated path. It deletes the Supabase
  Auth user and account-specific data; a sole member explicitly confirms full
  network deletion, while an owner with other members must transfer ownership.
- Settlement PDFs embed Amiri so Arabic reports do not depend on viewer/system
  fonts and avoid square placeholder glyphs.

## Final Manual Checks

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
- `flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
- `flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
