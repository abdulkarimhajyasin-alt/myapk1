import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/app_localizations.dart';
import '../models/network_notification.dart';

class PushNotificationCopy {
  const PushNotificationCopy({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class PushNotificationService {
  PushNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> showNetworkNotification({
    required NetworkNotification notification,
    required AppLocalizations l10n,
    required String currentMemberId,
    required String? actorMemberId,
  }) async {
    if (!shouldShowFor(
      currentMemberId: currentMemberId,
      actorMemberId: actorMemberId,
    )) {
      return;
    }
    await initialize();
    final copy = copyFor(notification: notification, l10n: l10n);
    await _plugin.show(
      notification.id.hashCode,
      copy.title,
      copy.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'maskan_events',
          'Maskan events',
          channelDescription: 'Shared housing activity updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: notification.id,
    );
  }

  PushNotificationCopy copyFor({
    required NetworkNotification notification,
    required AppLocalizations l10n,
  }) {
    final title = switch (notification.kind) {
      NetworkNotificationKind.expense => l10n.pushExpenseAddedTitle,
      NetworkNotificationKind.expenseUpdated => l10n.pushExpenseUpdatedTitle,
      NetworkNotificationKind.resetRequest => l10n.pushResetRequestedTitle,
      NetworkNotificationKind.cycleStarted => l10n.pushCycleStartedTitle,
    };
    return PushNotificationCopy(
      title: title,
      body: notification.actorMemberName,
    );
  }

  bool shouldShowFor({
    required String currentMemberId,
    required String? actorMemberId,
  }) {
    return actorMemberId == null || actorMemberId != currentMemberId;
  }
}
