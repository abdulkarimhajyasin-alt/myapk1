import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/id_utils.dart';
import 'expense_network_repository.dart';
import 'shared_preferences_storage_keys.dart';

enum OfflineOperationType {
  addExpense,
  approveReset,
}

class OfflineOperation {
  OfflineOperation({
    String? id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
    this.retryCount = 0,
    this.status = 'pending',
  })  : id = id ?? IdUtils.createId('offline_operation'),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final OfflineOperationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String status;

  OfflineOperation copyWith({
    int? retryCount,
    String? status,
  }) {
    return OfflineOperation(
      id: id,
      type: type,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'status': status,
    };
  }

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'] as String?,
      type: OfflineOperationType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => OfflineOperationType.addExpense,
      ),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

class OfflineSyncQueue {
  OfflineSyncQueue(this._preferences);

  final SharedPreferences _preferences;

  Future<List<OfflineOperation>> pendingOperations() async {
    final raw = _preferences.getString(
      SharedPreferencesStorageKeys.offlineSyncQueue,
    );
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => OfflineOperation.fromJson(item as Map<String, dynamic>))
        .where((operation) => operation.status == 'pending')
        .toList();
  }

  Future<void> enqueueAddExpense({
    required String networkName,
    required String memberName,
    required String addedByMemberId,
    required int amountCents,
    required String clientGeneratedId,
    String? note,
  }) async {
    final operations = await pendingOperations();
    if (operations.any((operation) => operation.id == clientGeneratedId)) {
      return;
    }
    await _save([
      ...operations,
      OfflineOperation(
        id: clientGeneratedId,
        type: OfflineOperationType.addExpense,
        payload: {
          'networkName': networkName,
          'memberName': memberName,
          'addedByMemberId': addedByMemberId,
          'amountCents': amountCents,
          'note': note,
        },
      ),
    ]);
  }

  Future<int> retryPending(ExpenseNetworkRepository repository) async {
    final operations = await pendingOperations();
    var synced = 0;
    final remaining = <OfflineOperation>[];
    for (final operation in operations) {
      try {
        if (operation.type == OfflineOperationType.addExpense) {
          await repository.addExpense(
            networkName: operation.payload['networkName'] as String,
            memberName: operation.payload['memberName'] as String,
            addedByMemberId: operation.payload['addedByMemberId'] as String,
            amountCents: operation.payload['amountCents'] as int,
            note: operation.payload['note'] as String?,
            clientGeneratedId: operation.id,
          );
        }
        synced++;
      } on RepositoryException catch (error) {
        if (error.code == 'duplicate_expense_operation') {
          synced++;
          continue;
        }
        if (error.code != 'supabase_network_unavailable') rethrow;
        remaining.add(operation.copyWith(retryCount: operation.retryCount + 1));
      }
    }
    await _save(remaining);
    return synced;
  }

  Future<void> _save(List<OfflineOperation> operations) async {
    await _preferences.setString(
      SharedPreferencesStorageKeys.offlineSyncQueue,
      jsonEncode(operations.map((operation) => operation.toJson()).toList()),
    );
  }
}
