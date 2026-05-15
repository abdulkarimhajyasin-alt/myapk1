# Shared Housing Expenses

A Flutter mobile app for private expense-sharing networks. The first version is Android APK-first and uses local persistent storage through `shared_preferences`, with repository interfaces that can later be backed by Firebase or Supabase.

## Run

```bash
flutter pub get
flutter run
```

## Build APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

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
