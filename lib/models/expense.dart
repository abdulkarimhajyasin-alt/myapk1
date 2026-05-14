class Expense {
  const Expense({
    required this.amountCents,
    required this.createdAt,
    this.note,
  });

  final int amountCents;
  final String? note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'amountCents': amountCents,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      amountCents: json['amountCents'] as int,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
