# Push Notifications Phase 2

The current implementation is Push-1: Supabase Realtime events received by the app can show Android local notifications. This is useful while the app process is active and connected.

Production background push requires a server-side path:

- Firebase Cloud Messaging project configuration
- Device token registration per member/device
- Supabase Edge Function or backend worker that listens for important rows
- Server sends FCM messages to recipient devices, excluding the actor
- Notification tap routing into Maskan screens
- Token refresh and logout cleanup

Do not put Firebase server keys or Supabase service-role keys in the Flutter app.
