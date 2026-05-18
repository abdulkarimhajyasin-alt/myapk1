# Maskan

A Flutter mobile app for private expense-sharing networks. The first version is Android APK-first and uses local persistent storage through `shared_preferences`, with repository interfaces that can later be backed by Firebase or Supabase.

The app includes a global footer shortcut to the Karamix Labs company website.
It opens `https://karamixlabs.com` in the external browser through
`url_launcher`.

## Run

```bash
flutter pub get
flutter run
```

## Build APK

```bash
flutter clean
flutter pub get
flutter build apk --release --dart-define=DATA_MODE=local
```

For Android local and Supabase test APK workflows, see
[`docs/android_testing.md`](docs/android_testing.md).

## Android Release Signing

Android only installs an APK update over an existing app when both APKs use the
same `applicationId` and the same signing certificate. If a previous APK was
installed with a different debug or temporary release signature, Android may show
`التطبيق ليس مثبتًا` / `App not installed`. Keep one permanent upload keystore
and use it for every release APK.

The package name is `com.expensenetwork.app`. Do not change it for app updates.

### Generate a permanent keystore

Run this once and keep `upload-keystore.jks` in a secure password manager or
backup location. Do not commit it to Git.

```powershell
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Use a strong keystore password and key password. Losing this keystore means
future APKs cannot update installations signed with it.

### Local release signing

Copy the template and fill in your local values:

```powershell
Copy-Item android/key.properties.example android/key.properties
```

Example local `android/key.properties`:

```properties
storeFile=../upload-keystore.jks
storePassword=your-keystore-password
keyAlias=upload
keyPassword=your-key-password
```

Place the real keystore at `android/upload-keystore.jks` for the example path
above, or update `storeFile` to your local path. `android/key.properties` and
keystore files are ignored by Git and must never be committed.

Build a locally signed release APK:

```powershell
flutter build apk --release --dart-define=DATA_MODE=local
```

The signed output is:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### GitHub Actions signed APK

Convert the keystore to Base64 on Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Out-File keystore_base64.txt
```

Add these repository secrets in GitHub:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

Use the contents of `keystore_base64.txt` for `ANDROID_KEYSTORE_BASE64`. Use the
same alias and passwords created with `keytool`.

When all four secrets exist, the `Build Android APK` workflow decodes the
keystore into a temporary runner file, signs the release APK, and uploads:

```text
maskan-release-signed.apk
```

The workflow always builds the debug artifact:

```text
maskan-debug.apk
```

If Supabase secrets are configured, it also builds:

```text
maskan-supabase-debug.apk
```

If Android signing secrets are missing, the signed release step is skipped with
a warning and debug APK builds continue.

### Installing updates safely

For normal user updates, install `maskan-release-signed.apk` from GitHub
Actions. Future signed release APKs built with the same keystore will install
over it and preserve app data.

If a device already has an APK signed with a different certificate, Android will
reject the update. Uninstall the old app once, then install the new signed
release APK. After that, keep using APKs signed with the permanent keystore.

## Build iOS

iOS builds require macOS with Xcode and CocoaPods installed.

```bash
flutter clean
flutter pub get
dart run flutter_launcher_icons
flutter build ios --release --no-codesign
```

Cloud mode uses the same Dart defines on iOS as Android:

```bash
flutter build ios --release --no-codesign \
  --dart-define=DATA_MODE=supabase \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

For TestFlight or App Store builds, open `ios/Runner.xcworkspace` in Xcode and
set the Apple development team/signing profile for bundle id
`com.expensenetwork.app`.

Manual CI validation is available from the GitHub Actions workflow
`Validate iOS`, which runs a macOS no-codesign build.

## Structure

- `lib/models/` - network, member, expense, and settlement models
- `lib/services/` - storage repository and settlement calculation
- `lib/screens/` - app screens and navigation flow
- `lib/widgets/` - reusable UI components
- `lib/utils/` - centralized strings and money parsing/formatting
