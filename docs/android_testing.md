# Android Testing Readiness

Maskan is now a Supabase-only app. Every APK must be built with the public
Supabase URL and anon key; the app does not provide a local storage fallback.

## Build a Debug APK

```bash
flutter clean
flutter pub get
dart run flutter_launcher_icons
flutter build apk --debug \
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

## Download APK Artifacts

1. Open the repository `Actions` tab.
2. Select the latest `Build Android APK` workflow run.
3. Download the debug or signed release APK artifact.

## Two-Phone Cloud Test

1. Install the same Maskan APK on both Android phones.
2. Confirm the home/dashboard shows the cloud-connected indicator.
3. On phone A, create a network with a network password and personal password.
4. On phone B, join with the invite QR/link or the same network credentials.
5. Add an expense, notification, reset request, and settlement/cycle action.
6. Confirm both phones update through Supabase realtime without manual refresh.

If cloud operations fail, check the device internet connection, Supabase URL,
anon key, schema, realtime publication, and RLS policies. The app should show a
retry/reconnect state and must not create isolated local data.

## QR Invite and Deep Link Test

1. Install Maskan on two phones.
2. On phone A, create or open a network.
3. Open **Invite Members** and confirm the screen shows:
   - a QR code
   - the canonical invite link
     `https://karamixlabs.com/maskan/join?network={networkId}`
   - copy and share actions
4. On phone B, tap **Scan Invite** on the home screen.
5. Allow camera permission and scan phone A's QR code.
6. Confirm the join screen opens with the invite context.
7. Enter the member name, network password, and personal password, then join.

Supported invite formats:

- `https://karamixlabs.com/maskan/join?network={networkId}` is the primary
  QR/share payload because Telegram, WhatsApp, and SMS reliably auto-link HTTPS
  URLs.
- `maskan://join/{networkId}` remains supported as the direct app scheme.

## Leave Network Test

The dashboard exit action is a safe leave-network flow, not a silent logout.

1. Tap **Leave Network**.
2. Confirm the dialog text asks whether to delete the account and permanently
   leave the expense network.
3. If total expenses are not zero, confirm leaving is blocked with the localized
   settlement message.
4. If total expenses are zero and there is no pending reset, the current member
   is removed, the active Supabase session metadata is cleared, and the app
   returns to the home screen.
5. Confirm other members remain in the network.

## Settlement PDF Export

Open the settlement screen and export a PDF in English and Arabic. The PDF
embeds the bundled Amiri fonts from `assets/fonts`, so Arabic text is rendered
with real glyphs instead of square placeholders in Android PDF viewers.
