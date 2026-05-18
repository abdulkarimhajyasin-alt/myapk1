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
   - `maskan-debug-apk`
   - `maskan-supabase-debug-apk` when Supabase secrets are configured

The workflow also keeps the existing local release APK artifact for continuity.

## Two-Phone Supabase Test

1. Install the `maskan-supabase-debug-apk` artifact on both Android
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

## QR Invite and Deep Link Test

Cloud QR joining is designed for Supabase builds. Local mode still supports the
manual join form, but scanning a QR invite explains that QR joining requires
cloud mode because local data exists only on one device.

1. Install the Supabase APK on two phones.
2. On phone A, create or open a cloud network.
3. Open **Invite Members** and confirm the screen shows:
   - a QR code
   - the canonical invite link `maskan://join/{networkId}`
   - copy and share actions
   - explanatory text telling the recipient to install Maskan first
4. On phone B, tap **Scan Invite** / **مسح دعوة** on the home screen.
5. Allow the camera permission and scan phone A's QR code.
6. Confirm the join screen opens with the invite context and no website 404 is
   shown.
7. Enter the member name, network password, and personal password, then join.

Supported invite formats:

- `maskan://join/{networkId}` is the primary QR/share payload.
- `https://karamixlabs.com/maskan/join?network={networkId}` is accepted when
  delivered to the app as a compatibility deep link, but the app does not show
  it as a normal website fallback because that web route is not currently
  hosted.

Invalid QR codes should show a localized error instead of navigating.

## Settlement PDF Export

Open the settlement screen and export a PDF in English and Arabic. The PDF now
embeds the bundled Noto Naskh Arabic fonts from `assets/fonts`, so Arabic text
is rendered with real glyphs instead of square placeholders in Android PDF
viewers, Google Drive preview, Telegram, and WhatsApp. Check that the report
contains the Maskan header, network info, total expenses card, member settlement
table, settlement instructions, and Karamix Labs footer.

## Known Limitation

iOS/TestFlight readiness exists in the repository, but iOS distribution remains
deferred. Android local and Supabase test APKs are the active validation target.
# Settlement PDF and cycles

The settlement screen can export the current settlement through Android's
share/print sheet. Resetting expenses now starts a new cycle only after every
member from the request-time snapshot approves. Old expenses are archived by
cycle, not hard-deleted. See `docs/settlement_cycles.md` for the full behavior
and Supabase schema notes.
