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
- Verify Supabase mode with production anon key and RLS policies.

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

## Final Manual Checks

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build apk --debug --dart-define=DATA_MODE=supabase --dart-define=SUPABASE_URL=test --dart-define=SUPABASE_ANON_KEY=test`
- `flutter build apk --release`
- `flutter build appbundle --release`
