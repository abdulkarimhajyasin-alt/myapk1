import '../models/expense.dart';
import '../models/expense_network.dart';
import '../models/member.dart';

class DashboardAnalytics {
  const DashboardAnalytics({
    required this.totalCents,
    required this.currentCycleTotalCents,
    required this.averageExpenseCents,
    required this.expenseCount,
    required this.monthlyTotalCents,
    required this.topPayer,
    required this.recentActivity,
  });

  final int totalCents;
  final int currentCycleTotalCents;
  final double averageExpenseCents;
  final int expenseCount;
  final int monthlyTotalCents;
  final Member? topPayer;
  final List<ActivityEntry> recentActivity;
}

class ActivityEntry {
  const ActivityEntry({
    required this.member,
    required this.expense,
  });

  final Member member;
  final Expense expense;
}

class DashboardAnalyticsService {
  const DashboardAnalyticsService();

  DashboardAnalytics calculate(ExpenseNetwork network, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final activeCycleId = network.activeCycle.id;
    final activeExpenses = <ActivityEntry>[];
    final currentCycleExpenses = <ActivityEntry>[];
    for (final member in network.members) {
      for (final expense in member.expenses.where((item) => !item.isArchived)) {
        final entry = ActivityEntry(member: member, expense: expense);
        activeExpenses.add(entry);
        if (expense.cycleId == null || expense.cycleId == activeCycleId) {
          currentCycleExpenses.add(entry);
        }
      }
    }

    final monthlyExpenses = activeExpenses.where((entry) {
      return entry.expense.createdAt.year == today.year &&
          entry.expense.createdAt.month == today.month;
    });
    final topPayers = [...network.members]
      ..sort((a, b) => b.totalPaidCents.compareTo(a.totalPaidCents));
    activeExpenses.sort(
      (a, b) => b.expense.createdAt.compareTo(a.expense.createdAt),
    );

    return DashboardAnalytics(
      totalCents: network.totalExpensesCents,
      currentCycleTotalCents: currentCycleExpenses.fold<int>(
        0,
        (total, entry) => total + entry.expense.amountCents,
      ),
      averageExpenseCents: activeExpenses.isEmpty
          ? 0
          : network.totalExpensesCents / activeExpenses.length,
      expenseCount: activeExpenses.length,
      monthlyTotalCents: monthlyExpenses.fold<int>(
        0,
        (total, entry) => total + entry.expense.amountCents,
      ),
      topPayer: topPayers.isEmpty || topPayers.first.totalPaidCents == 0
          ? null
          : topPayers.first,
      recentActivity: activeExpenses.take(6).toList(),
    );
  }
}
