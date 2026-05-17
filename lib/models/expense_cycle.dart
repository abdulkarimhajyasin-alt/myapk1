import '../utils/id_utils.dart';

class ExpenseCycle {
  ExpenseCycle({
    String? id,
    required this.networkId,
    required this.cycleNumber,
    required this.startedAt,
    this.closedAt,
    this.status = ExpenseCycleStatus.active,
    this.requestedByMemberId,
    this.requestedByMemberName,
  }) : id = id ?? IdUtils.createId('cycle');

  final String id;
  final String networkId;
  final int cycleNumber;
  final DateTime startedAt;
  final DateTime? closedAt;
  final ExpenseCycleStatus status;
  final String? requestedByMemberId;
  final String? requestedByMemberName;

  ExpenseCycle copyWith({
    DateTime? closedAt,
    ExpenseCycleStatus? status,
    String? requestedByMemberId,
    String? requestedByMemberName,
  }) {
    return ExpenseCycle(
      id: id,
      networkId: networkId,
      cycleNumber: cycleNumber,
      startedAt: startedAt,
      closedAt: closedAt ?? this.closedAt,
      status: status ?? this.status,
      requestedByMemberId: requestedByMemberId ?? this.requestedByMemberId,
      requestedByMemberName: requestedByMemberName ?? this.requestedByMemberName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'networkId': networkId,
      'cycleNumber': cycleNumber,
      'startedAt': startedAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'status': status.name,
      'requestedByMemberId': requestedByMemberId,
      'requestedByMemberName': requestedByMemberName,
    };
  }

  factory ExpenseCycle.fromJson(Map<String, dynamic> json) {
    return ExpenseCycle(
      id: json['id'] as String?,
      networkId: json['networkId'] as String,
      cycleNumber: json['cycleNumber'] as int? ?? 1,
      startedAt: DateTime.parse(json['startedAt'] as String),
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
      status: ExpenseCycleStatus.fromName(json['status'] as String?),
      requestedByMemberId: json['requestedByMemberId'] as String?,
      requestedByMemberName: json['requestedByMemberName'] as String?,
    );
  }
}

enum ExpenseCycleStatus {
  active,
  pendingReset,
  closed;

  static ExpenseCycleStatus fromName(String? value) {
    return ExpenseCycleStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ExpenseCycleStatus.active,
    );
  }
}
