import '../utils/id_utils.dart';

class Expense {
  Expense({
    String? id,
    required this.amountCents,
    required this.createdAt,
    this.note,
    String? addedByMemberId,
    String? addedByMemberName,
    this.cycleId,
    this.archivedAt,
    this.clientGeneratedId,
    this.isPendingSync = false,
  })  : id = id ?? IdUtils.createId('expense'),
        addedByMemberId = addedByMemberId ?? '',
        addedByMemberName = addedByMemberName ?? '';

  final String id;
  final int amountCents;
  final String? note;
  final DateTime createdAt;
  final String addedByMemberId;
  final String addedByMemberName;
  final String? cycleId;
  final DateTime? archivedAt;
  final String? clientGeneratedId;
  final bool isPendingSync;

  bool get isArchived => archivedAt != null;

  Expense copyWith({
    String? cycleId,
    DateTime? archivedAt,
    String? clientGeneratedId,
    bool? isPendingSync,
  }) {
    return Expense(
      id: id,
      amountCents: amountCents,
      note: note,
      createdAt: createdAt,
      addedByMemberId: addedByMemberId,
      addedByMemberName: addedByMemberName,
      cycleId: cycleId ?? this.cycleId,
      archivedAt: archivedAt ?? this.archivedAt,
      clientGeneratedId: clientGeneratedId ?? this.clientGeneratedId,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amountCents': amountCents,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'addedByMemberId': addedByMemberId,
      'addedByMemberName': addedByMemberName,
      'cycleId': cycleId,
      'archivedAt': archivedAt?.toIso8601String(),
      'clientGeneratedId': clientGeneratedId,
      'isPendingSync': isPendingSync,
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
      cycleId: json['cycleId'] as String?,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      clientGeneratedId: json['clientGeneratedId'] as String?,
      isPendingSync: json['isPendingSync'] as bool? ?? false,
    );
  }
}
