import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../services/settlement_service.dart';
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';

class ExpenseSettlementScreen extends StatelessWidget {
  const ExpenseSettlementScreen({required this.network, super.key});

  final ExpenseNetwork network;

  @override
  Widget build(BuildContext context) {
    final settlement = const SettlementService().calculate(network);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.expenseSettlement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryTile(
            label: l10n.totalExpenses,
            value: MoneyUtils.formatCents(
              settlement.totalCents,
              currencySymbol: network.currencySymbol,
            ),
          ),
          _SummaryTile(
            label: l10n.sharePerMember,
            value: MoneyUtils.formatCents(
              settlement.sharePerMemberCents,
              currencySymbol: network.currencySymbol,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.memberStatus,
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
                    Text(
                      '${l10n.paid}: '
                      '${MoneyUtils.formatCents(
                        member.paidCents,
                        currencySymbol: network.currencySymbol,
                      )}',
                    ),
                    Text(
                      '${l10n.shouldPay}: '
                      '${MoneyUtils.formatCents(
                        member.shouldPayCents,
                        currencySymbol: network.currencySymbol,
                      )}',
                    ),
                    Text(
                      '${l10n.balance}: '
                      '${MoneyUtils.formatCents(
                        member.balanceCents,
                        currencySymbol: network.currencySymbol,
                      )}',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.finalSettlement,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (settlement.payments.isEmpty)
            Text(l10n.noSettlementNeeded)
          else
            ...settlement.payments.map(
              (payment) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text(
                    l10n.settlementPayment(
                      fromMember: payment.fromMember,
                      amount: MoneyUtils.formatCents(
                        payment.amountCents,
                        currencySymbol: network.currencySymbol,
                      ),
                      toMember: payment.toMember,
                    ),
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
