import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../models/member.dart';
import '../models/network_notification.dart';
import '../services/dashboard_analytics_service.dart';
import '../services/expense_network_repository.dart';
import '../services/push_notification_service.dart';
import '../services/session_repository.dart';
import '../services/supabase_realtime_service.dart';
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/member_avatar.dart';
import 'add_expense_screen.dart';
import 'expense_settlement_screen.dart';
import 'invite_members_screen.dart';
import 'member_expense_history_screen.dart';
import 'notifications_screen.dart';

class NetworkDashboardScreen extends StatefulWidget {
  const NetworkDashboardScreen({
    required this.repository,
    required this.sessionRepository,
    required this.network,
    required this.currentMemberId,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;
  final ExpenseNetwork network;
  final String currentMemberId;

  @override
  State<NetworkDashboardScreen> createState() => _NetworkDashboardScreenState();
}

class _NetworkDashboardScreenState extends State<NetworkDashboardScreen> {
  late ExpenseNetwork _network = widget.network;
  final _pushNotifications = PushNotificationService();
  SupabaseRealtimeService? _realtimeService;
  RealtimeConnectionState _realtimeState = RealtimeConnectionState.connecting;
  Timer? _reconnectTimer;

  Member get _currentMember {
    return _network.findMemberById(widget.currentMemberId) ??
        (_network.members.isEmpty ? Member(name: '') : _network.members.first);
  }

  Future<void> _refreshNetwork() async {
    try {
      final latest = await widget.repository.findNetwork(_network.name);
      if (latest != null && mounted) {
        setState(() {
          _network = latest;
          _realtimeState = RealtimeConnectionState.connected;
        });
      }
    } on RepositoryException catch (error) {
      if (error.code == 'supabase_network_unavailable') {
        _markOfflineAndRetry();
        return;
      }
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _startRealtime();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _realtimeService?.dispose();
    super.dispose();
  }

  Future<void> _startRealtime() async {
    _reconnectTimer?.cancel();
    await _realtimeService?.dispose();
    final service = SupabaseRealtimeService();
    _realtimeService = service;
    setState(() => _realtimeState = RealtimeConnectionState.connecting);
    final state = await service.subscribe(
      networkId: _network.id,
      memberId: widget.currentMemberId,
      onRefresh: () {
        if (mounted) _refreshNetwork();
      },
      onNotification: _showRealtimeNotification,
    );
    if (!mounted) return;
    setState(() => _realtimeState = state);
    if (state == RealtimeConnectionState.offline) {
      _scheduleRealtimeReconnect();
    }
  }

  void _markOfflineAndRetry() {
    if (!mounted) return;
    setState(() => _realtimeState = RealtimeConnectionState.offline);
    _scheduleRealtimeReconnect();
  }

  void _scheduleRealtimeReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _startRealtime();
    });
  }

  Future<void> _showRealtimeNotification(
    NetworkNotification notification,
    String? actorMemberId,
  ) {
    return _pushNotifications.showNetworkNotification(
      notification: notification,
      l10n: context.l10n,
      currentMemberId: widget.currentMemberId,
      actorMemberId: actorMemberId,
    );
  }

  Future<void> _openAddExpense() async {
    final updatedNetwork = await Navigator.of(context).push<ExpenseNetwork>(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          repository: widget.repository,
          network: _network,
          currentMemberId: widget.currentMemberId,
        ),
      ),
    );
    if (!mounted) return;
    if (updatedNetwork != null) {
      setState(() => _network = updatedNetwork);
    } else {
      await _refreshNetwork();
    }
  }

  Future<void> _openSettlement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseSettlementScreen(
          repository: widget.repository,
          network: _network,
          currentMemberId: widget.currentMemberId,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshNetwork();
  }

  Future<void> _openHistory(Member member) async {
    final historyMember = await widget.repository.getMemberHistory(
          networkName: _network.name,
          memberId: member.id,
        ) ??
        member;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberExpenseHistoryScreen(
          repository: widget.repository,
          network: _network,
          member: historyMember,
          currentMemberId: widget.currentMemberId,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshNetwork();
  }

  Future<void> _openResetPassword(Member targetMember) async {
    final l10n = context.l10n;
    final didReset = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetPasswordDialog(
        targetMemberName: targetMember.name,
        onSubmit: (newPassword) {
          return widget.repository.resetMemberPassword(
            networkId: _network.id,
            adminMemberId: widget.currentMemberId,
            targetMemberId: targetMember.id,
            newPassword: newPassword,
          );
        },
      ),
    );
    if (!mounted || didReset != true) return;
    _showSnack(l10n.memberPasswordResetSuccess);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          repository: widget.repository,
          networkId: _network.id,
          memberId: widget.currentMemberId,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openInvite() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InviteMembersScreen(
          networkName: _network.name,
          networkId: _network.id,
        ),
      ),
    );
  }

  Future<int> _unreadCount() async {
    final notifications = await widget.repository.getNotifications(
      networkId: _network.id,
      memberId: widget.currentMemberId,
    );
    return notifications.where((notification) => !notification.isRead).length;
  }

  Future<void> _leaveNetwork() async {
    final l10n = context.l10n;
    final isLastMember = _network.members.length == 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveNetwork),
        content: Text(
          isLastMember
              ? '${l10n.confirmLeaveNetwork}\n\n${l10n.lastMemberLeaveWarning}'
              : l10n.confirmLeaveNetwork,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_network.totalExpensesCents != 0) {
      _showSnack(l10n.cannotLeaveBeforeSettlement);
      return;
    }

    try {
      await widget.repository.leaveNetwork(
        networkId: _network.id,
        memberId: widget.currentMemberId,
      );
      await widget.sessionRepository.clearActiveSession();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.leaveNetworkSuccess)),
      );
    } on RepositoryException catch (error) {
      if (!mounted) return;
      _showSnack(_leaveErrorMessage(error));
    }
  }

  String _leaveErrorMessage(RepositoryException error) {
    final l10n = context.l10n;
    return switch (error.code) {
      'leave_unsettled_expenses' => l10n.cannotLeaveBeforeSettlement,
      'leave_pending_reset' => l10n.cannotLeavePendingReset,
      'leave_member_has_history' => l10n.cannotLeaveWithHistory,
      _ => l10n.leaveNetworkFailed,
    };
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final analytics = const DashboardAnalyticsService().calculate(_network);

    return AppScaffold(
      title: _network.name,
      actions: [
        IconButton(
          tooltip: l10n.inviteMembers,
          onPressed: _openInvite,
          icon: const Icon(Icons.qr_code_rounded),
        ),
        FutureBuilder<int>(
          future: _unreadCount(),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: l10n.notifications,
                  onPressed: _openNotifications,
                  icon: const Icon(Icons.notifications_rounded),
                ),
                if (count > 0)
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: CircleAvatar(
                      radius: 8,
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          tooltip: l10n.leaveNetwork,
          onPressed: _leaveNetwork,
          icon: const Icon(Icons.exit_to_app_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _currentMember.name,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _SyncStatusChip(state: _realtimeState),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              MemberAvatar(member: _currentMember, radius: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _currentMember.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.totalExpenses,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  MoneyUtils.formatCents(
                    _network.totalExpensesCents,
                    currencySymbol: _network.currencySymbol,
                  ),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AnalyticsGrid(
            analytics: analytics,
          ),
          const SizedBox(height: 18),
          Text(
            l10n.members,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ..._network.members.map(
            (member) {
              final isOwner = _network.isOwnerMember(member.id);
              final canResetPassword =
                  _network.isOwnerMember(widget.currentMemberId) &&
                      !isOwner &&
                      member.id != widget.currentMemberId;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _openHistory(member),
                  leading: MemberAvatar(member: member),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(member.name)),
                      if (isOwner) ...[
                        const SizedBox(width: 8),
                        _AdminBadge(label: l10n.adminBadge),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.totalPaid),
                      if (canResetPassword)
                        TextButton(
                          onPressed: () => _openResetPassword(member),
                          child: Text(l10n.resetMemberPassword),
                        ),
                    ],
                  ),
                  trailing: Text(
                    MoneyUtils.formatCents(
                      member.totalPaidCents,
                      currencySymbol: _network.currencySymbol,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _openAddExpense,
            icon: const Icon(Icons.add_card_rounded),
            label: Text(l10n.addExpense),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openSettlement,
            icon: const Icon(Icons.receipt_long_rounded),
            label: Text(l10n.expenseSettlement),
          ),
        ],
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFDDF6E6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF166534),
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({
    required this.targetMemberName,
    required this.onSubmit,
  });

  final String targetMemberName;
  final Future<Member> Function(String newPassword) onSubmit;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.memberPasswordResetFailed)),
      );
    }
  }

  String? _passwordValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return context.l10n.fieldRequired;
    if (trimmed.length < 4) return context.l10n.passwordTooShort;
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return context.l10n.fieldRequired;
    if (trimmed != _passwordController.text.trim()) {
      return context.l10n.passwordsDoNotMatch;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.resetMemberPassword),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.targetMemberName),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: l10n.newPassword),
              obscureText: true,
              validator: _passwordValidator,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _confirmController,
              decoration: InputDecoration(labelText: l10n.confirmNewPassword),
              obscureText: true,
              validator: _confirmPasswordValidator,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(l10n.savePasswordReset),
        ),
      ],
    );
  }
}

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({
    required this.state,
  });

  final RealtimeConnectionState state;

  @override
  Widget build(BuildContext context) {
    if (state == RealtimeConnectionState.connected) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final label = switch (state) {
      RealtimeConnectionState.connected => l10n.connected,
      RealtimeConnectionState.connecting => l10n.syncing,
      RealtimeConnectionState.offline => l10n.reconnecting,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      avatar: Icon(
        state == RealtimeConnectionState.connecting
            ? Icons.sync_rounded
            : state == RealtimeConnectionState.connected
                ? Icons.cloud_done_rounded
                : Icons.cloud_off_rounded,
        size: 18,
      ),
    );
  }
}

class _AnalyticsGrid extends StatelessWidget {
  const _AnalyticsGrid({
    required this.analytics,
  });

  final DashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topPayer = analytics.topPayer;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _AnalyticsCard(
          label: l10n.topPayer,
          value: topPayer == null ? '-' : topPayer.name,
        ),
      ],
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 165,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
