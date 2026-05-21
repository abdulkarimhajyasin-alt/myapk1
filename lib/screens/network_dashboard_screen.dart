import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../models/member.dart';
import '../models/network_notification.dart';
import '../services/dashboard_analytics_service.dart';
import '../services/expense_network_repository.dart';
import '../services/member_avatar_photo_service.dart';
import '../services/push_notification_service.dart';
import '../services/repository_error_messages.dart';
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
    this.avatarPhotoService,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;
  final ExpenseNetwork network;
  final String currentMemberId;
  final MemberAvatarPhotoService? avatarPhotoService;

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
        (_network.members.isEmpty
            ? Member(name: '')
            : _network.members.first);
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberExpenseHistoryScreen(
          network: _network,
          member: historyMember,
        ),
      ),
    );
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

  Future<void> _editAvatar() async {
    final member = _currentMember;
    try {
      final photoService =
          widget.avatarPhotoService ?? SupabaseMemberAvatarPhotoService.active();
      final photo = await photoService.pickAndUpload(
        networkId: _network.id,
        memberId: member.id,
      );
      if (photo == null) return;
      final updatedMember = await widget.repository.updateMemberProfile(
        networkName: _network.name,
        memberId: member.id,
        avatarImagePath: photo.storagePath,
        avatarImageUrl: photo.publicUrl,
      );
      if (!mounted) return;
      setState(() => _replaceMember(updatedMember));
    } on MemberAvatarPhotoException catch (error) {
      if (!mounted) return;
      _showSnack(
        RepositoryErrorMessages.fromCode(context.l10n, error.code) ??
            context.l10n.avatarPhotoUploadFailed,
      );
    } on RepositoryException catch (error) {
      if (!mounted) return;
      _showSnack(RepositoryErrorMessages.fromException(context, error));
    } catch (_) {
      if (!mounted) return;
      _showSnack(context.l10n.avatarPhotoUploadFailed);
    }
  }

  void _replaceMember(Member updatedMember) {
    _network = _network.copyWith(
      members: _network.members
          .map((candidate) =>
              candidate.id == updatedMember.id ? updatedMember : candidate)
          .toList(),
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
                child: OutlinedButton.icon(
                  onPressed: _editAvatar,
                  icon: const Icon(Icons.palette_rounded),
                  label: Text(l10n.editAvatar),
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
            currencySymbol: _network.currencySymbol,
          ),
          const SizedBox(height: 18),
          _ActivityTimeline(
            analytics: analytics,
            currencySymbol: _network.currencySymbol,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.members,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ..._network.members.map(
            (member) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _openHistory(member),
                leading: MemberAvatar(member: member),
                title: Text(member.name),
                subtitle: Text(l10n.totalPaid),
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
            ),
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
    required this.currencySymbol,
  });

  final DashboardAnalytics analytics;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topPayer = analytics.topPayer;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _AnalyticsCard(
          label: l10n.currentCycleTotal,
          value: MoneyUtils.formatCents(
            analytics.currentCycleTotalCents,
            currencySymbol: currencySymbol,
          ),
        ),
        _AnalyticsCard(
          label: l10n.averageExpense,
          value: MoneyUtils.formatCents(
            analytics.averageExpenseCents,
            currencySymbol: currencySymbol,
          ),
        ),
        _AnalyticsCard(
          label: l10n.expenseCount,
          value: analytics.expenseCount.toString(),
        ),
        _AnalyticsCard(
          label: l10n.monthlySpend,
          value: MoneyUtils.formatCents(
            analytics.monthlyTotalCents,
            currencySymbol: currencySymbol,
          ),
        ),
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

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({
    required this.analytics,
    required this.currencySymbol,
  });

  final DashboardAnalytics analytics;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.activityTimeline,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        if (analytics.recentActivity.isEmpty)
          Text(l10n.noActivityYet)
        else
          ...analytics.recentActivity.map(
            (entry) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: MemberAvatar(member: entry.member),
                title: Text(
                  '${entry.member.name} ${MoneyUtils.formatCents(
                    entry.expense.amountCents,
                    currencySymbol: currencySymbol,
                  )}',
                ),
                subtitle: Text(
                  [
                    material.formatShortDate(entry.expense.createdAt),
                    material.formatTimeOfDay(
                      TimeOfDay.fromDateTime(entry.expense.createdAt),
                    ),
                    if (entry.expense.note?.trim().isNotEmpty == true)
                      entry.expense.note!.trim(),
                  ].join(' - '),
                ),
                trailing: entry.expense.isPendingSync
                    ? const Icon(Icons.sync_rounded)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
