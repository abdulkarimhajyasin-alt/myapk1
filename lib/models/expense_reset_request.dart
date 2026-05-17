import '../utils/id_utils.dart';

class ExpenseResetApproval {
  const ExpenseResetApproval({
    required this.memberId,
    required this.memberName,
    required this.approvedAt,
  });

  final String memberId;
  final String memberName;
  final DateTime approvedAt;

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'approvedAt': approvedAt.toIso8601String(),
    };
  }

  factory ExpenseResetApproval.fromJson(Map<String, dynamic> json) {
    return ExpenseResetApproval(
      memberId: json['memberId'] as String,
      memberName: json['memberName'] as String,
      approvedAt: DateTime.parse(json['approvedAt'] as String),
    );
  }
}

class ExpenseResetRequest {
  ExpenseResetRequest({
    String? id,
    required this.networkId,
    required this.cycleId,
    required this.requestedByMemberId,
    required this.requestedByMemberName,
    required this.createdAt,
    required this.requiredMemberIds,
    required this.requiredMemberNames,
    this.status = ExpenseResetStatus.pending,
    this.completedAt,
    this.approvals = const [],
  }) : id = id ?? IdUtils.createId('reset');

  final String id;
  final String networkId;
  final String cycleId;
  final String requestedByMemberId;
  final String requestedByMemberName;
  final DateTime createdAt;
  final List<String> requiredMemberIds;
  final List<String> requiredMemberNames;
  final ExpenseResetStatus status;
  final DateTime? completedAt;
  final List<ExpenseResetApproval> approvals;

  bool get isPending => status == ExpenseResetStatus.pending;
  bool get isCompleted => status == ExpenseResetStatus.completed;

  bool isApprovedBy(String memberId) {
    return approvals.any((approval) => approval.memberId == memberId);
  }

  List<String> get pendingMemberNames {
    final approvedIds = approvals.map((approval) => approval.memberId).toSet();
    final names = <String>[];
    for (var i = 0; i < requiredMemberIds.length; i++) {
      if (!approvedIds.contains(requiredMemberIds[i])) {
        names.add(
          i < requiredMemberNames.length
              ? requiredMemberNames[i]
              : requiredMemberIds[i],
        );
      }
    }
    return names;
  }

  bool get hasUnanimousApproval {
    final approvedIds = approvals.map((approval) => approval.memberId).toSet();
    return requiredMemberIds.every(approvedIds.contains);
  }

  ExpenseResetRequest approve({
    required String memberId,
    required String memberName,
    DateTime? approvedAt,
  }) {
    if (isApprovedBy(memberId)) return this;
    return copyWith(
      approvals: [
        ...approvals,
        ExpenseResetApproval(
          memberId: memberId,
          memberName: memberName,
          approvedAt: approvedAt ?? DateTime.now(),
        ),
      ],
    );
  }

  ExpenseResetRequest copyWith({
    ExpenseResetStatus? status,
    DateTime? completedAt,
    List<ExpenseResetApproval>? approvals,
  }) {
    return ExpenseResetRequest(
      id: id,
      networkId: networkId,
      cycleId: cycleId,
      requestedByMemberId: requestedByMemberId,
      requestedByMemberName: requestedByMemberName,
      createdAt: createdAt,
      requiredMemberIds: requiredMemberIds,
      requiredMemberNames: requiredMemberNames,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      approvals: approvals ?? this.approvals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'networkId': networkId,
      'cycleId': cycleId,
      'requestedByMemberId': requestedByMemberId,
      'requestedByMemberName': requestedByMemberName,
      'createdAt': createdAt.toIso8601String(),
      'requiredMemberIds': requiredMemberIds,
      'requiredMemberNames': requiredMemberNames,
      'status': status.name,
      'completedAt': completedAt?.toIso8601String(),
      'approvals': approvals.map((approval) => approval.toJson()).toList(),
    };
  }

  factory ExpenseResetRequest.fromJson(Map<String, dynamic> json) {
    return ExpenseResetRequest(
      id: json['id'] as String?,
      networkId: json['networkId'] as String,
      cycleId: json['cycleId'] as String,
      requestedByMemberId: json['requestedByMemberId'] as String,
      requestedByMemberName: json['requestedByMemberName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      requiredMemberIds: (json['requiredMemberIds'] as List<dynamic>? ?? [])
          .map((value) => value as String)
          .toList(),
      requiredMemberNames: (json['requiredMemberNames'] as List<dynamic>? ?? [])
          .map((value) => value as String)
          .toList(),
      status: ExpenseResetStatus.fromName(json['status'] as String?),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      approvals: (json['approvals'] as List<dynamic>? ?? [])
          .map(
            (approval) => ExpenseResetApproval.fromJson(
              approval as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

enum ExpenseResetStatus {
  pending,
  completed,
  cancelled;

  static ExpenseResetStatus fromName(String? value) {
    return ExpenseResetStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ExpenseResetStatus.pending,
    );
  }
}
