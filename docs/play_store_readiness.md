# Maskan Play Store Readiness

## App Identity

- App name: Maskan
- Android applicationId: `com.expensenetwork.app`
- Default mode: local
- Cloud mode: opt-in with `DATA_MODE=supabase`
- Publisher/brand footer: Karamix Labs

## Release Build Checklist

- Build signed APK: `flutter build apk --release`
- Build Android App Bundle: `flutter build appbundle --release`
- Keep the existing permanent release keystore and GitHub Actions signing secrets.
- Do not change `applicationId` for existing installs.
- Verify Arabic and English screenshots on Android.
- Verify notification permission prompt on Android 13+.
- Verify camera permission copy appears when using **Scan Invite**.
- Verify Supabase mode with production anon key and RLS policies.
- Verify QR invite scanning and custom deep links open the join flow in
  Supabase mode.
- Verify settlement PDF export in Arabic and English with embedded Arabic fonts.

## Store Listing Assets Needed

- 512 x 512 app icon
- Feature graphic: 1024 x 500
- Phone screenshots in Arabic and English
- Short description in Arabic and English
- Full description in Arabic and English
- Privacy policy URL
- Support contact email

## Data Safety Notes

- Local mode stores network, member, expense, notification, and session metadata on the device.
- Supabase mode stores network, member, expense, reset, notification, and optional profile metadata in Supabase.
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
- Leaving a network removes only the current member after total expenses are
  zero and there are no pending reset/sync blockers.
- Settlement PDFs embed Amiri so Arabic reports do not depend on viewer/system
  fonts and avoid square placeholder glyphs, including Arabic presentation
  forms, mixed Arabic, Latin, punctuation, and euro-symbol content.

## Final Manual Checks

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build apk --debug --dart-define=DATA_MODE=supabase --dart-define=SUPABASE_URL=test --dart-define=SUPABASE_ANON_KEY=test`
- `flutter build apk --release`
- `flutter build appbundle --release`
