# Expense Network

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

## Structure

- `lib/models/` - network, member, expense, and settlement models
- `lib/services/` - storage repository and settlement calculation
- `lib/screens/` - app screens and navigation flow
- `lib/widgets/` - reusable UI components
- `lib/utils/` - centralized strings and money parsing/formatting
