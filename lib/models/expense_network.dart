import '../utils/currency_utils.dart';
import '../utils/id_utils.dart';
import 'expense.dart';
import 'expense_cycle.dart';
import 'expense_reset_request.dart';
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
    List<ExpenseCycle>? cycles,
    this.resetRequests = const [],
  }) : id = id ?? IdUtils.legacyId('network', name);

  final String id;
  final String name;
  final String password;
  final List<Member> members;
  final DateTime createdAt;
  final String currencyCode;
  final String currencySymbol;
  final List<ExpenseCycle>? cycles;
  final List<ExpenseResetRequest> resetRequests;

  ExpenseCycle get activeCycle {
    final existing = cycles?.where(
      (cycle) =>
          cycle.status == ExpenseCycleStatus.active ||
          cycle.status == ExpenseCycleStatus.pendingReset,
    );
    if (existing != null && existing.isNotEmpty) return existing.last;
    return ExpenseCycle(
      id: IdUtils.legacyId('cycle', id),
      networkId: id,
      cycleNumber: 1,
      startedAt: createdAt,
    );
  }

  ExpenseResetRequest? get activeResetRequest {
    final pending = resetRequests.where((request) => request.isPending);
    return pending.isEmpty ? null : pending.last;
  }

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
    List<ExpenseCycle>? cycles,
    List<ExpenseResetRequest>? resetRequests,
  }) {
    return ExpenseNetwork(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      cycles: cycles ?? this.cycles,
      resetRequests: resetRequests ?? this.resetRequests,
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
            cycleId: activeCycle.id,
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
      'cycles': (cycles ?? [activeCycle]).map((cycle) => cycle.toJson()).toList(),
      'resetRequests':
          resetRequests.map((request) => request.toJson()).toList(),
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
      cycles: (json['cycles'] as List<dynamic>?)
          ?.map((cycle) => ExpenseCycle.fromJson(cycle as Map<String, dynamic>))
          .toList(),
      resetRequests: (json['resetRequests'] as List<dynamic>? ?? [])
          .map(
            (request) => ExpenseResetRequest.fromJson(
              request as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}
