import '../utils/id_utils.dart';
import 'expense.dart';

class Member {
  Member({
    String? id,
    required this.name,
    this.passwordHash,
    this.passwordSalt,
    DateTime? createdAt,
    this.expenses = const [],
  })  : id = id ?? IdUtils.legacyId('member', name),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final String? passwordHash;
  final String? passwordSalt;
  final DateTime createdAt;
  final List<Expense> expenses;

  bool get hasPassword {
    return passwordHash != null &&
        passwordHash!.isNotEmpty &&
        passwordSalt != null &&
        passwordSalt!.isNotEmpty;
  }

  int get totalPaidCents {
    return expenses.fold<int>(0, (total, expense) => total + expense.amountCents);
  }

  Member copyWith({
    String? id,
    String? name,
    String? passwordHash,
    String? passwordSalt,
    DateTime? createdAt,
    List<Expense>? expenses,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      createdAt: createdAt ?? this.createdAt,
      expenses: expenses ?? this.expenses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'passwordHash': passwordHash,
      'passwordSalt': passwordSalt,
      'createdAt': createdAt.toIso8601String(),
      'expenses': expenses.map((expense) => expense.toJson()).toList(),
    };
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    return Member(
      id: json['id'] as String? ?? IdUtils.legacyId('member', name),
      name: name,
      passwordHash: json['passwordHash'] as String?,
      passwordSalt: json['passwordSalt'] as String?,
      createdAt: json['createdAt'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(json['createdAt'] as String),
      expenses: (json['expenses'] as List<dynamic>? ?? [])
          .map((expense) => Expense.fromJson(expense as Map<String, dynamic>))
          .toList(),
    );
  }
}
