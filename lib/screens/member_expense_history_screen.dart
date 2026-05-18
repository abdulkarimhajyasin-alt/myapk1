import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../models/member.dart';
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/member_avatar.dart';

class MemberExpenseHistoryScreen extends StatelessWidget {
  const MemberExpenseHistoryScreen({
    required this.network,
    required this.member,
    super.key,
  });

  final ExpenseNetwork network;
  final Member member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AppScaffold(
      title: l10n.expenseHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MemberAvatar(member: member, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${l10n.totalPaid}: '
            '${MoneyUtils.formatCents(
              member.totalPaidCents,
              currencySymbol: network.currencySymbol,
            )}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 18),
          if (member.expenses.isEmpty)
            _EmptyHistory(
              title: l10n.noExpensesYet,
              subtitle: l10n.noExpensesSubtitle,
            )
          else
            ...member.expenses.reversed.map(
              (expense) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MoneyUtils.formatCents(
                          expense.amountCents,
                          currencySymbol: network.currencySymbol,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${MaterialLocalizations.of(context).formatFullDate(
                          expense.createdAt,
                        )} ${MaterialLocalizations.of(context).formatTimeOfDay(
                          TimeOfDay.fromDateTime(expense.createdAt),
                        )}',
                      ),
                      if (expense.addedByMemberName.isNotEmpty)
                        Text('${l10n.addedBy}: ${expense.addedByMemberName}'),
                      if (expense.note != null) ...[
                        const SizedBox(height: 8),
                        Text('${l10n.note}: ${expense.note}'),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
