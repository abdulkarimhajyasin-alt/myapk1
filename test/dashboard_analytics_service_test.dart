import 'package:expense_network/models/expense.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/services/dashboard_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates empty dashboard analytics safely', () {
    final network = ExpenseNetwork(
      name: 'Home',
      password: 'secret',
      members: const [],
      createdAt: DateTime(2026),
    );

    final analytics = const DashboardAnalyticsService().calculate(network);

    expect(analytics.totalCents, 0);
    expect(analytics.averageExpenseCents, 0);
    expect(analytics.expenseCount, 0);
    expect(analytics.topPayer, isNull);
    expect(analytics.recentActivity, isEmpty);
  });

  test('calculates top payer averages monthly spend and activity', () {
    final now = DateTime(2026, 5, 18);
    final network = ExpenseNetwork(
      name: 'Home',
      password: 'secret',
      createdAt: DateTime(2026),
      members: [
        Member(
          name: 'Ali',
          expenses: [
            Expense(amountCents: 5000, createdAt: now),
            Expense(amountCents: 1500, createdAt: DateTime(2026, 4, 1)),
          ],
        ),
        Member(
          name: 'Mona',
          expenses: [
            Expense(amountCents: 2500, createdAt: now),
          ],
        ),
      ],
    );

    final analytics = const DashboardAnalyticsService().calculate(
      network,
      now: now,
    );

    expect(analytics.totalCents, 9000);
    expect(analytics.averageExpenseCents, 3000);
    expect(analytics.expenseCount, 3);
    expect(analytics.monthlyTotalCents, 7500);
    expect(analytics.topPayer?.name, 'Ali');
    expect(analytics.recentActivity, hasLength(3));
  });
}
