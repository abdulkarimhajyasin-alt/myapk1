# Maskan Android Permissions Audit

Last verified: 2026-08-26

| Permission | Status | Runtime use | Reason / evidence |
|---|---|---|---|
| INTERNET | Kept | Normal permission; no runtime prompt | Required for Supabase Auth, database, Realtime, Storage, and Edge Functions |
| POST_NOTIFICATIONS | Kept | Requested by PushNotificationService on Android 13+ | Displays local notifications for realtime network activity |
| CAMERA | Kept | Requested by the scanner when the user opens Scan Invite | mobile_scanner reads invite QR codes; Maskan does not retain camera frames |
| READ_MEDIA_IMAGES | Removed | None | Avatar selection uses image_picker/Android Photo Picker and needs no broad media permission |
| READ_MEDIA_VIDEO | Not declared | None | The app does not select videos |
| READ_EXTERNAL_STORAGE | Removed | None | Broad legacy storage access is unnecessary for the Photo Picker |
| MANAGE_EXTERNAL_STORAGE | Not declared | None | No all-files access use case exists |

## Runtime-path findings

- Avatar: ImageSource.gallery, one image, immediate byte read/upload, no
  background media scan.
- Camera: only ScanInviteScreen/mobile_scanner.
- Notifications: local notification plugin; no FCM token or background push
  transport.
- Final merged-manifest verification is part of the release build checklist.
