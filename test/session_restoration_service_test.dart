import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/session_repository.dart';
import 'package:expense_network/services/session_restoration_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stale session with missing member clears session safely', () async {
    final repository = _SessionRepositoryFake(
      network: ExpenseNetwork(
        id: 'network_1',
        name: 'Flat',
        password: 'network',
        members: [Member(id: 'member_2', name: 'Mona')],
        createdAt: DateTime(2026),
      ),
    );
    final sessions = _SessionStoreFake(
      const AccountSession(networkName: 'Flat', memberId: 'member_1'),
    );

    final restored = await SessionRestorationService(
      repository: repository,
      sessionRepository: sessions,
    ).restore();

    expect(restored, isNull);
    expect(sessions.cleared, isTrue);
  });

  test('stale session with missing network clears session safely', () async {
    final repository = _SessionRepositoryFake();
    final sessions = _SessionStoreFake(
      const AccountSession(networkName: 'Flat', memberId: 'member_1'),
    );

    final restored = await SessionRestorationService(
      repository: repository,
      sessionRepository: sessions,
    ).restore();

    expect(restored, isNull);
    expect(sessions.cleared, isTrue);
  });

  test('stale session with deleted cloud record clears session safely',
      () async {
    final repository = _SessionRepositoryFake(
      findNetworkError: const RepositoryException(
        'Saved cloud record is no longer available.',
        code: 'supabase_not_found',
      ),
    );
    final sessions = _SessionStoreFake(
      const AccountSession(networkName: 'Flat', memberId: 'member_1'),
    );

    final restored = await SessionRestorationService(
      repository: repository,
      sessionRepository: sessions,
    ).restore();

    expect(restored, isNull);
    expect(sessions.cleared, isTrue);
  });

  test('temporary cloud outage does not clear saved session', () async {
    final repository = _SessionRepositoryFake(
      findNetworkError: const RepositoryException(
        'Maskan needs an internet connection.',
        code: 'supabase_network_unavailable',
      ),
    );
    final sessions = _SessionStoreFake(
      const AccountSession(networkName: 'Flat', memberId: 'member_1'),
    );

    final restored = await SessionRestorationService(
      repository: repository,
      sessionRepository: sessions,
    ).restore();

    expect(restored, isNull);
    expect(sessions.cleared, isFalse);
  });

  test('valid local session without Supabase auth asks for reauth', () async {
    final repository = _SessionRepositoryFake(
      network: ExpenseNetwork(
        id: 'network_1',
        name: 'Flat',
        password: 'network',
        members: [Member(id: 'member_1', name: 'Ali')],
        createdAt: DateTime(2026),
      ),
    );
    final sessions = _SessionStoreFake(
      const AccountSession(networkName: 'Flat', memberId: 'member_1'),
      authRestored: false,
    );

    final result = await SessionRestorationService(
      repository: repository,
      sessionRepository: sessions,
    ).restoreWithStatus();

    expect(result.status, SessionRestorationStatus.unavailable);
    expect(result.restoredSession, isNull);
    expect(sessions.authRestoreCalls, 1);
    expect(sessions.cleared, isFalse);
  });

  test('valid saved session restores dashboard target without clearing',
      () async {
    final repository = _SessionRepositoryFake(
      network: ExpenseNetwork(
        id: 'network_1',
        name: 'Flat',
        password: 'network',
        members: [Member(id: 'member_1', name: 'Ali')],
        createdAt: DateTime(2026),
      ),
    );
    final sessions = _SessionStoreFake(
      const AccountSession(networkName: 'Flat', memberId: 'member_1'),
    );

    final result = await SessionRestorationService(
      repository: repository,
      sessionRepository: sessions,
    ).restoreWithStatus();

    expect(result.status, SessionRestorationStatus.restored);
    expect(result.restoredSession?.network.name, 'Flat');
    expect(result.restoredSession?.memberId, 'member_1');
    expect(sessions.authRestoreCalls, 1);
    expect(sessions.cleared, isFalse);
  });
}

class _SessionStoreFake implements SessionRepository {
  _SessionStoreFake(this.session, {this.authRestored = true});

  AccountSession? session;
  final bool authRestored;
  bool cleared = false;
  int authRestoreCalls = 0;

  @override
  Future<void> clearActiveSession() async {
    cleared = true;
    session = null;
  }

  @override
  Future<AccountSession?> getActiveSession() async => session;

  @override
  Future<AccountSessionAuthState> restoreAuthenticatedSession() async {
    authRestoreCalls += 1;
    return AccountSessionAuthState(
      accountSession: session,
      accountSessionExists: session != null,
      supabaseSessionExists: session != null && authRestored,
      currentUserExists: session != null && authRestored,
      authRestored: session != null && authRestored,
      memberId: session?.memberId,
    );
  }

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
    String? memberPassword,
    String? networkId,
  }) async {
    session = AccountSession(networkName: networkName, memberId: memberId);
  }
}

class _SessionRepositoryFake implements ExpenseNetworkRepository {
  const _SessionRepositoryFake({
    this.network,
    this.findNetworkError,
  });

  final ExpenseNetwork? network;
  final RepositoryException? findNetworkError;

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async {
    final error = findNetworkError;
    if (error != null) throw error;
    return network;
  }

  @override
  Future<ExpenseNetwork> addExpense({
    required String networkName,
    required String memberName,
    required String addedByMemberId,
    required int amountCents,
    String? note,
    String? clientGeneratedId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ExpenseNetwork> updateExpense({
    required String networkName,
    required String networkId,
    required String expenseId,
    required String editedByMemberId,
    required int amountCents,
    String? note,
    DateTime? createdAt,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ExpenseNetwork> deleteExpense({
    required String networkName,
    required String networkId,
    required String expenseId,
    required String deletedByMemberId,
  }) async =>
      throw UnimplementedError();

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
      network?.findMemberById(memberId);

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
      network?.findMemberById(memberId);

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async =>
      const [];

  @override
  Future<List<ExpenseNetwork>> getNetworks() async =>
      network == null ? const [] : [network!];

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
      network!.findMemberById(memberId)!;
}
