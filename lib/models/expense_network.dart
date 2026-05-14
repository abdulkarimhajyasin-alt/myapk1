import 'expense.dart';
import 'member.dart';
import '../utils/currency_utils.dart';

class ExpenseNetwork {
  const ExpenseNetwork({
    required this.name,
    required this.password,
    required this.members,
    required this.createdAt,
    this.currencyCode = 'USD',
    this.currencySymbol = r'$',
  });

  final String name;
  final String password;
  final List<Member> members;
  final DateTime createdAt;
  final String currencyCode;
  final String currencySymbol;

  int get totalExpensesCents {
    return members.fold<int>(0, (total, member) => total + member.totalPaidCents);
  }

  ExpenseNetwork copyWith({
    String? name,
    String? password,
    List<Member>? members,
    DateTime? createdAt,
    String? currencyCode,
    String? currencySymbol,
  }) {
    return ExpenseNetwork(
      name: name ?? this.name,
      password: password ?? this.password,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
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
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
    };
  }

  factory ExpenseNetwork.fromJson(Map<String, dynamic> json) {
    final rawCurrencyCode = json['currencyCode'] as String?;
    final currency = CurrencyCatalog.findByCode(rawCurrencyCode);
    final currencySymbol = json['currencySymbol'] as String?;
    final hasSupportedCurrencyCode =
        CurrencyCatalog.isSupportedCode(rawCurrencyCode);

    return ExpenseNetwork(
      name: json['name'] as String,
      password: json['password'] as String,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((member) => Member.fromJson(member as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      currencyCode: currency.code,
      currencySymbol: hasSupportedCurrencyCode &&
              currencySymbol?.trim().isNotEmpty == true
          ? currencySymbol!.trim()
          : currency.symbol,
    );
  }
}
