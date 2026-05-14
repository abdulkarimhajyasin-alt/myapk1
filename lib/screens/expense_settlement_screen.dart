import 'package:flutter/material.dart';

import '../models/expense_network.dart';
import '../services/settlement_service.dart';
import '../utils/app_strings.dart';
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';

class ExpenseSettlementScreen extends StatelessWidget {
  const ExpenseSettlementScreen({required this.network, super.key});

  final ExpenseNetwork network;

  @override
  Widget build(BuildContext context) {
    final settlement = const SettlementService().calculate(network);
    final theme = Theme.of(context);

    return AppScaffold(
      title: AppStrings.expenseSettlement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryTile(
            label: AppStrings.totalExpenses,
            value: MoneyUtils.formatCents(settlement.totalCents),
          ),
          _SummaryTile(
            label: AppStrings.sharePerMember,
            value: MoneyUtils.formatCents(settlement.sharePerMemberCents),
          ),
          const SizedBox(height: 18),
          Text(
            AppStrings.memberStatus,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...settlement.members.map(
            (member) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.memberName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Paid: ${MoneyUtils.formatCents(member.paidCents)}'),
                    Text(
                      'Should pay: '
                      '${MoneyUtils.formatCents(member.shouldPayCents)}',
                    ),
                    Text(
                      'Balance: ${MoneyUtils.formatCents(member.balanceCents)}',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppStrings.finalSettlement,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (settlement.payments.isEmpty)
            Text(AppStrings.noSettlementNeeded)
          else
            ...settlement.payments.map(
              (payment) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text(
                    '${payment.fromMember} pays '
                    '${MoneyUtils.formatCents(payment.amountCents)} '
                    'to ${payment.toMember}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
