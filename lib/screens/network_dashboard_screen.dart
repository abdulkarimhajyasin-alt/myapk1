import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../services/expense_network_repository.dart';
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';
import 'add_expense_screen.dart';
import 'expense_settlement_screen.dart';

class NetworkDashboardScreen extends StatefulWidget {
  const NetworkDashboardScreen({
    required this.repository,
    required this.network,
    required this.currentMemberName,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final ExpenseNetwork network;
  final String currentMemberName;

  @override
  State<NetworkDashboardScreen> createState() => _NetworkDashboardScreenState();
}

class _NetworkDashboardScreenState extends State<NetworkDashboardScreen> {
  late ExpenseNetwork _network = widget.network;

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
          currentMemberName: widget.currentMemberName,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AppScaffold(
      title: _network.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
