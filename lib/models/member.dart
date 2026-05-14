import 'expense.dart';

class Member {
  const Member({
    required this.name,
    this.expenses = const [],
  });

  final String name;
  final List<Expense> expenses;

  int get totalPaidCents {
    return expenses.fold<int>(0, (total, expense) => total + expense.amountCents);
  }

  Member copyWith({
    String? name,
    List<Expense>? expenses,
  }) {
    return Member(
      name: name ?? this.name,
      expenses: expenses ?? this.expenses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'expenses': expenses.map((expense) => expense.toJson()).toList(),
    };
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      name: json['name'] as String,
      expenses: (json['expenses'] as List<dynamic>? ?? [])
          .map((expense) => Expense.fromJson(expense as Map<String, dynamic>))
          .toList(),
    );
  }
}
