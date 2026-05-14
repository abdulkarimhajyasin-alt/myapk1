import 'package:flutter/material.dart';

<<<<<<< HEAD
import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../services/expense_network_repository.dart';
=======
import '../models/expense_network.dart';
import '../services/expense_network_repository.dart';
import '../utils/app_strings.dart';
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
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
<<<<<<< HEAD
    if (!mounted) return;
=======
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
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
<<<<<<< HEAD
    final l10n = context.l10n;
=======
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb

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
<<<<<<< HEAD
                  l10n.totalExpenses,
=======
                  AppStrings.totalExpenses,
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  MoneyUtils.formatCents(_network.totalExpensesCents),
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
<<<<<<< HEAD
            l10n.members,
=======
            AppStrings.members,
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
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
<<<<<<< HEAD
                subtitle: Text(l10n.totalPaid),
=======
                subtitle: Text('Total paid'),
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
                trailing: Text(
                  MoneyUtils.formatCents(member.totalPaidCents),
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
<<<<<<< HEAD
            label: Text(l10n.addExpense),
=======
            label: const Text(AppStrings.addExpense),
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openSettlement,
            icon: const Icon(Icons.receipt_long_rounded),
<<<<<<< HEAD
            label: Text(l10n.expenseSettlement),
=======
            label: const Text(AppStrings.expenseSettlement),
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
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
