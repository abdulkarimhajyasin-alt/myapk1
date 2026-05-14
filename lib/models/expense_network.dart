import '../utils/currency_utils.dart';
import '../utils/id_utils.dart';
import 'expense.dart';
import 'member.dart';

class ExpenseNetwork {
  ExpenseNetwork({
    String? id,
    required this.name,
    required this.password,
    required this.members,
    required this.createdAt,
    this.currencyCode = 'USD',
    this.currencySymbol = r'$',
  }) : id = id ?? IdUtils.legacyId('network', name);

  final String id;
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
    String? id,
    String? name,
    String? password,
    List<Member>? members,
    DateTime? createdAt,
    String? currencyCode,
    String? currencySymbol,
  }) {
    return ExpenseNetwork(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
    );
  }

  ExpenseNetwork addMember(Member member) {
    return copyWith(members: [...members, member]);
  }

  ExpenseNetwork addExpense({
    required String memberName,
    required int amountCents,
    required String addedByMemberId,
    required String addedByMemberName,
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
            addedByMemberId: addedByMemberId,
            addedByMemberName: addedByMemberName,
          ),
        ],
      );
    }).toList();

    return copyWith(members: updatedMembers);
  }

  Member? findMemberByName(String memberName) {
    final normalizedName = memberName.trim().toLowerCase();
    for (final member in members) {
      if (member.name.trim().toLowerCase() == normalizedName) return member;
    }
    return null;
  }

  Member? findMemberById(String memberId) {
    for (final member in members) {
      if (member.id == memberId) return member;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'password': password,
      'members': members.map((member) => member.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
    };
  }

  factory ExpenseNetwork.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final rawCurrencyCode = json['currencyCode'] as String?;
    final currency = CurrencyCatalog.findByCode(rawCurrencyCode);
    final currencySymbol = json['currencySymbol'] as String?;
    final hasSupportedCurrencyCode =
        CurrencyCatalog.isSupportedCode(rawCurrencyCode);

    return ExpenseNetwork(
      id: json['id'] as String? ?? IdUtils.legacyId('network', name),
      name: name,
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
