import 'expense.dart';
import 'member.dart';

class ExpenseNetwork {
  const ExpenseNetwork({
    required this.name,
    required this.password,
    required this.members,
    required this.createdAt,
  });

  final String name;
  final String password;
  final List<Member> members;
  final DateTime createdAt;

  int get totalExpensesCents {
    return members.fold<int>(0, (total, member) => total + member.totalPaidCents);
  }

  ExpenseNetwork copyWith({
    String? name,
    String? password,
    List<Member>? members,
    DateTime? createdAt,
  }) {
    return ExpenseNetwork(
      name: name ?? this.name,
      password: password ?? this.password,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  ExpenseNetwork addMember(String memberName) {
    return copyWith(members: [...members, Member(name: memberName)]);
  }

  ExpenseNetwork addExpense({
    required String memberName,
    required int amountCents,
    String? note,
  }) {
    final updatedMembers = members.map((member) {
      if (member.name.toLowerCase() != memberName.toLowerCase()) {
        return member;
      }
      return member.copyWith(
        expenses: [
          ...member.expenses,
          Expense(
            amountCents: amountCents,
            note: note,
            createdAt: DateTime.now(),
          ),
        ],
      );
    }).toList();

    return copyWith(members: updatedMembers);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'password': password,
      'members': members.map((member) => member.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ExpenseNetwork.fromJson(Map<String, dynamic> json) {
    return ExpenseNetwork(
      name: json['name'] as String,
      password: json['password'] as String,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((member) => Member.fromJson(member as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
