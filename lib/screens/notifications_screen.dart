import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/member.dart';
import '../models/network_notification.dart';
import '../services/expense_network_repository.dart';
import '../services/supabase_realtime_service.dart';
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/member_avatar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.repository,
    required this.networkId,
    required this.memberId,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final String networkId;
  final String memberId;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NetworkNotification>> _notificationsFuture =
      _loadNotifications();
  SupabaseRealtimeService? _realtimeService;

  @override
  void initState() {
    super.initState();
    _startRealtime();
  }

  @override
  void dispose() {
    _realtimeService?.dispose();
    super.dispose();
  }

  Future<void> _startRealtime() async {
    final service = SupabaseRealtimeService();
    _realtimeService = service;
    await service.subscribe(
      networkId: widget.networkId,
      memberId: widget.memberId,
      onRefresh: () {
        if (!mounted) return;
        setState(() => _notificationsFuture = _loadNotifications());
      },
      onNotification: (_, __) {},
    );
  }

  Future<List<NetworkNotification>> _loadNotifications() {
    return widget.repository.getNotifications(
      networkId: widget.networkId,
      memberId: widget.memberId,
    );
  }

  Future<void> _clearAll() async {
    final l10n = context.l10n;
    await widget.repository.clearNotificationsForMember(
      networkId: widget.networkId,
      memberId: widget.memberId,
    );
    if (!mounted) return;
    setState(() => _notificationsFuture = _loadNotifications());
    _showMessage(l10n.notificationRemoved);
  }

  Future<void> _removeNotification(NetworkNotification notification) async {
    final l10n = context.l10n;
    await widget.repository.deleteNotification(notification.id);
    if (!mounted) return;
    setState(() => _notificationsFuture = _loadNotifications());
    _showMessage(l10n.notificationRemoved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.notifications,
      actions: [
        TextButton(
          onPressed: _clearAll,
          child: Text(l10n.clearAll),
        ),
      ],
      child: FutureBuilder<List<NetworkNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Text(l10n.noNotifications);
          }

          return Column(
            children: notifications.map((notification) {
              final amount = MoneyUtils.formatCents(
                notification.expenseAmountCents,
                currencySymbol: notification.currencySymbol,
              );
              final title = switch (notification.kind) {
                NetworkNotificationKind.resetRequest =>
                  l10n.resetRequestNotification(
                    actor: notification.actorMemberName,
                  ),
                NetworkNotificationKind.cycleStarted =>
                  l10n.cycleStartedNotification,
                NetworkNotificationKind.expense => l10n.newExpenseNotification(
                    actor: notification.actorMemberName,
                    amount: amount,
                  ),
                NetworkNotificationKind.expenseUpdated =>
                  l10n.expenseUpdatedNotification(
                    actor: notification.actorMemberName,
                    amount: amount,
                  ),
              };
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: MemberAvatar(
                    member: Member(name: notification.actorMemberName),
                  ),
                  title: Text(title),
                  subtitle: notification.noteSnippet == null
                      ? null
                      : Text('${l10n.note}: ${notification.noteSnippet}'),
                  trailing: IconButton(
                    tooltip: l10n.clear,
                    onPressed: () => _removeNotification(notification),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  onTap: () => _removeNotification(notification),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
