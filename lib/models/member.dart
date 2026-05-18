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
    String? avatarColor,
    String? avatarInitials,
    this.avatarImagePath,
    this.avatarImageUrl,
  })  : id = id ?? IdUtils.legacyId('member', name),
        createdAt = createdAt ?? DateTime.now(),
        avatarColor = avatarColor ?? _generatedAvatarColor(name),
        avatarInitials = avatarInitials ?? _generatedInitials(name);

  final String id;
  final String name;
  final String? passwordHash;
  final String? passwordSalt;
  final DateTime createdAt;
  final List<Expense> expenses;
  final String avatarColor;
  final String avatarInitials;
  final String? avatarImagePath;
  final String? avatarImageUrl;

  bool get hasPassword {
    return passwordHash != null &&
        passwordHash!.isNotEmpty &&
        passwordSalt != null &&
        passwordSalt!.isNotEmpty;
  }

  int get totalPaidCents {
    return expenses
        .where((expense) => !expense.isArchived)
        .fold<int>(0, (total, expense) => total + expense.amountCents);
  }

  Member copyWith({
    String? id,
    String? name,
    String? passwordHash,
    String? passwordSalt,
    DateTime? createdAt,
    List<Expense>? expenses,
    String? avatarColor,
    String? avatarInitials,
    String? avatarImagePath,
    String? avatarImageUrl,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      createdAt: createdAt ?? this.createdAt,
      expenses: expenses ?? this.expenses,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      avatarImagePath: avatarImagePath ?? this.avatarImagePath,
      avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
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
      'avatarColor': avatarColor,
      'avatarInitials': avatarInitials,
      'avatarImagePath': avatarImagePath,
      'avatarImageUrl': avatarImageUrl,
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
      avatarColor: json['avatarColor'] as String?,
      avatarInitials: json['avatarInitials'] as String?,
      avatarImagePath: json['avatarImagePath'] as String?,
      avatarImageUrl: json['avatarImageUrl'] as String?,
    );
  }

  static String _generatedInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final initials = parts
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first))
        .join();
    return initials.toUpperCase();
  }

  static String _generatedAvatarColor(String name) {
    const colors = [
      '#2563EB',
      '#059669',
      '#DC2626',
      '#7C3AED',
      '#EA580C',
      '#0891B2',
      '#4F46E5',
      '#BE123C',
    ];
    final hash = name.codeUnits.fold<int>(0, (total, unit) => total + unit);
    return colors[hash.abs() % colors.length];
  }
}
