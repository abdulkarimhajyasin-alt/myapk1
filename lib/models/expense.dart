import '../utils/id_utils.dart';

class Expense {
  Expense({
    String? id,
    required this.amountCents,
    required this.createdAt,
    this.note,
    String? addedByMemberId,
    String? addedByMemberName,
  })  : id = id ?? IdUtils.createId('expense'),
        addedByMemberId = addedByMemberId ?? '',
        addedByMemberName = addedByMemberName ?? '';

  final String id;
  final int amountCents;
  final String? note;
  final DateTime createdAt;
  final String addedByMemberId;
  final String addedByMemberName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amountCents': amountCents,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'addedByMemberId': addedByMemberId,
      'addedByMemberName': addedByMemberName,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final amountCents = json['amountCents'] as int;
    return Expense(
      id: json['id'] as String? ??
          IdUtils.legacyId('expense', '$amountCents-${createdAt.toIso8601String()}'),
      amountCents: amountCents,
      note: json['note'] as String?,
      createdAt: createdAt,
      addedByMemberId: json['addedByMemberId'] as String? ?? '',
      addedByMemberName: json['addedByMemberName'] as String? ?? '',
    );
  }
}
