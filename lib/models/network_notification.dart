import '../utils/id_utils.dart';

class NetworkNotification {
  NetworkNotification({
    String? id,
    required this.networkId,
    required this.recipientMemberId,
    required this.actorMemberName,
    required this.expenseAmountCents,
    required this.currencySymbol,
    this.noteSnippet,
    DateTime? createdAt,
    this.isRead = false,
  })  : id = id ?? IdUtils.createId('notification'),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String networkId;
  final String recipientMemberId;
  final String actorMemberName;
  final int expenseAmountCents;
  final String currencySymbol;
  final String? noteSnippet;
  final DateTime createdAt;
  final bool isRead;

  NetworkNotification copyWith({
    bool? isRead,
  }) {
    return NetworkNotification(
      id: id,
      networkId: networkId,
      recipientMemberId: recipientMemberId,
      actorMemberName: actorMemberName,
      expenseAmountCents: expenseAmountCents,
      currencySymbol: currencySymbol,
      noteSnippet: noteSnippet,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'networkId': networkId,
      'recipientMemberId': recipientMemberId,
      'actorMemberName': actorMemberName,
      'expenseAmountCents': expenseAmountCents,
      'currencySymbol': currencySymbol,
      'noteSnippet': noteSnippet,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory NetworkNotification.fromJson(Map<String, dynamic> json) {
    return NetworkNotification(
      id: json['id'] as String?,
      networkId: json['networkId'] as String,
      recipientMemberId: json['recipientMemberId'] as String,
      actorMemberName: json['actorMemberName'] as String,
      expenseAmountCents: json['expenseAmountCents'] as int,
      currencySymbol: json['currencySymbol'] as String,
      noteSnippet: json['noteSnippet'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
