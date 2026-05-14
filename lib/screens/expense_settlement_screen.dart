import 'package:flutter/material.dart';

<<<<<<< HEAD
import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../services/settlement_service.dart';
=======
import '../models/expense_network.dart';
import '../services/settlement_service.dart';
import '../utils/app_strings.dart';
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';

class ExpenseSettlementScreen extends StatelessWidget {
  const ExpenseSettlementScreen({required this.network, super.key});

  final ExpenseNetwork network;

  @override
  Widget build(BuildContext context) {
    final settlement = const SettlementService().calculate(network);
    final theme = Theme.of(context);
<<<<<<< HEAD
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.expenseSettlement,
=======

    return AppScaffold(
      title: AppStrings.expenseSettlement,
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryTile(
<<<<<<< HEAD
            label: l10n.totalExpenses,
            value: MoneyUtils.formatCents(settlement.totalCents),
          ),
          _SummaryTile(
            label: l10n.sharePerMember,
=======
            label: AppStrings.totalExpenses,
            value: MoneyUtils.formatCents(settlement.totalCents),
          ),
          _SummaryTile(
            label: AppStrings.sharePerMember,
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
            value: MoneyUtils.formatCents(settlement.sharePerMemberCents),
          ),
          const SizedBox(height: 18),
          Text(
<<<<<<< HEAD
            l10n.memberStatus,
=======
            AppStrings.memberStatus,
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
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
<<<<<<< HEAD
                    Text('${l10n.paid}: '
                        '${MoneyUtils.formatCents(member.paidCents)}'),
                    Text(
                      '${l10n.shouldPay}: '
                      '${MoneyUtils.formatCents(member.shouldPayCents)}',
                    ),
                    Text(
                      '${l10n.balance}: '
                      '${MoneyUtils.formatCents(member.balanceCents)}',
=======
                    Text('Paid: ${MoneyUtils.formatCents(member.paidCents)}'),
                    Text(
                      'Should pay: '
                      '${MoneyUtils.formatCents(member.shouldPayCents)}',
                    ),
                    Text(
                      'Balance: ${MoneyUtils.formatCents(member.balanceCents)}',
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
<<<<<<< HEAD
            l10n.finalSettlement,
=======
            AppStrings.finalSettlement,
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (settlement.payments.isEmpty)
<<<<<<< HEAD
            Text(l10n.noSettlementNeeded)
=======
            Text(AppStrings.noSettlementNeeded)
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
          else
            ...settlement.payments.map(
              (payment) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text(
<<<<<<< HEAD
                    l10n.settlementPayment(
                      fromMember: payment.fromMember,
                      amount: MoneyUtils.formatCents(payment.amountCents),
                      toMember: payment.toMember,
                    ),
=======
                    '${payment.fromMember} pays '
                    '${MoneyUtils.formatCents(payment.amountCents)} '
                    'to ${payment.toMember}',
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
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
