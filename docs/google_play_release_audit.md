# Maskan Google Play Release Audit

Checked: 2026-08-26

| Item | Repository value | Status |
|---|---|---|
| applicationId | com.expensenetwork.app | Preserved |
| Namespace | com.expensenetwork.app | Preserved |
| Version name | 1.0.0 | No change |
| Version code | 1 | Play Console comparison required; last uploaded code is unknown |
| Compile SDK | 36 | Configured |
| Target SDK | 36 | Configured |
| Minimum SDK | Flutter-managed existing value | Unchanged |
| AGP | 8.11.1 | Preserved |
| Gradle wrapper | 8.14 | Preserved |
| Kotlin | 2.2.20 | Preserved |
| Java | 17 | Preserved |
| Signing identity | Existing environment/key-properties flow | No key change |

## Android 16 focused checks

- Flutter uses Material navigation APIs; no direct onBackPressed or
  KEYCODE_BACK interception was found.
- No edge-to-edge opt-out is declared.
- No fixed orientation/resizability restriction is declared.
- Responsive behavior still requires manual checks on Android 16 phone,
  tablet/large screen, gesture back, and three-button back.
- Arabic Amiri font layouts require visual verification because Android 16
  ignores the legacy elegant-font behavior.

## Manual release gates

- Confirm the last Play Console version code before changing the package
  version.
- Verify the release AAB is signed by the existing upload key.
- Inspect the merged release manifest for permissions.
- Do not upload from this task.
