# Android Testing Readiness

`DATA_MODE=local` remains the default. Use Supabase mode only for cloud testing
builds where the public Supabase URL and anon key are supplied with Dart
defines.

## Build a Local APK

```bash
flutter clean
flutter pub get
dart run flutter_launcher_icons
flutter build apk --debug --dart-define=DATA_MODE=local
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Build a Supabase Test APK

```bash
flutter clean
flutter pub get
dart run flutter_launcher_icons
flutter build apk --debug \
  --dart-define=DATA_MODE=supabase \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Only use the public anon key. Never use a service-role key in Flutter, GitHub
Actions, APK inputs, source code, or logs.

## GitHub Actions Secrets

In GitHub:

1. Open the repository.
2. Go to `Settings` -> `Secrets and variables` -> `Actions`.
3. Add repository secret `SUPABASE_URL`.
4. Add repository secret `SUPABASE_ANON_KEY`.

The Android workflow always builds the local debug APK. If either Supabase
secret is missing, the Supabase debug APK step is skipped with a warning instead
of breaking the local build.

## Download APK Artifacts

1. Open the repository `Actions` tab.
2. Select the latest `Build Android APK` workflow run.
3. Download:
   - `shared-housing-local-debug-apk`
   - `shared-housing-supabase-debug-apk` when Supabase secrets are configured

The workflow also keeps the existing local release APK artifact for continuity.

## Two-Phone Supabase Test

1. Install the `shared-housing-supabase-debug-apk` artifact on both Android
   phones.
2. Confirm the home screen shows `Cloud test mode`.
3. On phone A, create a network with a network password and personal password.
4. On phone B, join the same network name with the same network password and a
   different member name.
5. Add an expense on phone A.
6. Refresh/open the dashboard, member history, or notifications on phone B and
   confirm the cloud data is visible.

If cloud operations fail, check the device internet connection, Supabase URL,
anon key, schema, and Phase 5 RLS policies.

## Known Limitation

iOS/TestFlight readiness exists in the repository, but iOS distribution remains
deferred. Android local and Supabase test APKs are the active validation target.
