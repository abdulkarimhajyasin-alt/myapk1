import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../models/member.dart';
import '../services/expense_network_repository.dart';
import '../services/session_repository.dart';
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/mode_indicator.dart';
import 'add_expense_screen.dart';
import 'expense_settlement_screen.dart';
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

  Member get _currentMember {
    return _network.findMemberById(widget.currentMemberId) ??
        (_network.members.isEmpty
            ? Member(name: '')
            : _network.members.first);
  }

  Future<void> _refreshNetwork() async {
    final latest = await widget.repository.findNetwork(_network.name);
    if (latest != null && mounted) {
      setState(() => _network = latest);
    }
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

  void _openSettlement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseSettlementScreen(network: _network),
      ),
    );
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

  Future<int> _unreadCount() async {
    final notifications = await widget.repository.getNotifications(
      networkId: _network.id,
      memberId: widget.currentMemberId,
    );
    return notifications.where((notification) => !notification.isRead).length;
  }

  Future<void> _logout() async {
    await widget.sessionRepository.clearActiveSession();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AppScaffold(
      title: _network.name,
      actions: [
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
          tooltip: l10n.logout,
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
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
          const ModeIndicator(),
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
                leading: CircleAvatar(
                  child: Text(_avatarText(member.name)),
                ),
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

  String _avatarText(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }
}
