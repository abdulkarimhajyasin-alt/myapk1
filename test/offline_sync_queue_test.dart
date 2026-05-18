import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/offline_sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('operation is queued and survives SharedPreferences reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final queue = OfflineSyncQueue(preferences);

    await queue.enqueueAddExpense(
      networkName: 'Home',
      memberName: 'Ali',
      addedByMemberId: 'member_1',
      amountCents: 1200,
      clientGeneratedId: 'client_1',
      note: 'Tea',
    );

    final reloaded = OfflineSyncQueue(await SharedPreferences.getInstance());
    final operations = await reloaded.pendingOperations();

    expect(operations, hasLength(1));
    expect(operations.single.id, 'client_1');
    expect(operations.single.payload['amountCents'], 1200);
  });

  test('queued operation retries later and is removed', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final queue = OfflineSyncQueue(preferences);
    final repository = _QueueRepository();

    await queue.enqueueAddExpense(
      networkName: 'Home',
      memberName: 'Ali',
      addedByMemberId: 'member_1',
      amountCents: 1200,
      clientGeneratedId: 'client_1',
    );

    expect(await queue.retryPending(repository), 1);
    expect(await queue.pendingOperations(), isEmpty);
    expect(repository.clientGeneratedIds, ['client_1']);
  });
}

class _QueueRepository implements ExpenseNetworkRepository {
  final clientGeneratedIds = <String>[];

  @override
  Future<ExpenseNetwork> addExpense({
    required String networkName,
    required String memberName,
    required String addedByMemberId,
    required int amountCents,
    String? note,
    String? clientGeneratedId,
  }) async {
    clientGeneratedIds.add(clientGeneratedId ?? '');
    return ExpenseNetwork(
      name: networkName,
      password: 'secret',
      members: [Member(name: memberName, id: addedByMemberId)],
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<ExpenseNetwork> approveResetRequest({
    required String networkName,
    required String resetRequestId,
    required String memberId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ExpenseNetwork> authenticateMember({
    required String networkName,
    required String memberName,
    required String memberPassword,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> clearNotificationsForMember({
    required String networkId,
    required String memberId,
  }) async {}

  @override
  Future<ExpenseNetwork> createNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
    required String currencyCode,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ExpenseNetwork> createResetRequest({
    required String networkName,
    required String requestedByMemberId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteNotification(String notificationId) async {}

  @override
  Future<Member?> findMember({
    required String networkName,
    required String memberId,
  }) async =>
      null;

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async => null;

  @override
  Future<ExpenseResetRequest?> getActiveResetRequest({
    required String networkId,
  }) async =>
      null;

  @override
  Future<Member?> getMemberHistory({
    required String networkName,
    required String memberId,
  }) async =>
      null;

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async =>
      const [];

  @override
  Future<List<ExpenseNetwork>> getNetworks() async => const [];

  @override
  Future<ExpenseNetwork> joinNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
    String? networkId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> leaveNetwork({
    required String networkId,
    required String memberId,
  }) async {}

  @override
  Future<void> saveNetwork(ExpenseNetwork network) async {}

  @override
  Future<Member> updateMemberProfile({
    required String networkName,
    required String memberId,
    String? avatarColor,
    String? avatarInitials,
    String? avatarImagePath,
    String? avatarImageUrl,
  }) async =>
      Member(name: 'Ali', id: memberId);
}
