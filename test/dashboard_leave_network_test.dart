import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/screens/network_dashboard_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/session_repository.dart';
import 'package:expense_network/services/supabase_expense_network_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'leave flow blocks when current active total is greater than zero',
      (tester) async {
    final network = ExpenseNetwork(
      id: 'network_1',
      name: 'Flat',
      password: 'network',
      createdAt: DateTime(2026),
      members: [
        Member(
          id: 'member_1',
          name: 'Ali',
          expenses: [
            Expense(amountCents: 1000, createdAt: DateTime(2026)),
          ],
        ),
        Member(id: 'member_2', name: 'Mona'),
      ],
    );
    final repository = _LeaveRepository(network);
    final sessionRepository = _LeaveSessionRepository();

    await _pumpDashboard(
      tester,
      network: network,
      repository: repository,
      sessionRepository: sessionRepository,
    );

    await tester.tap(find.byTooltip('Leave Network'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(repository.leftNetworkId, isNull);
    expect(sessionRepository.cleared, isFalse);
    expect(
      find.text(
        'You must settle accounts with your friends first. '
        'You can leave after the total expenses becomes 0.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('leave flow clears active session after confirmed leave',
      (tester) async {
    final network = ExpenseNetwork(
      id: 'network_1',
      name: 'Flat',
      password: 'network',
      createdAt: DateTime(2026),
      members: [
        Member(id: 'member_1', name: 'Ali'),
        Member(id: 'member_2', name: 'Mona'),
      ],
    );
    final repository = _LeaveRepository(network);
    final sessionRepository = _LeaveSessionRepository();

    await _pumpDashboard(
      tester,
      network: network,
      repository: repository,
      sessionRepository: sessionRepository,
    );

    await tester.tap(find.byTooltip('Leave Network'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(repository.leftNetworkId, 'network_1');
    expect(repository.leftMemberId, 'member_1');
    expect(repository.deletedNetwork, isFalse);
    expect(repository.remainingMembers.map((member) => member.id), [
      'member_2',
    ]);
    expect(sessionRepository.cleared, isTrue);
  });

  testWidgets('leave flow allows an active total of exactly zero',
      (tester) async {
    final network = ExpenseNetwork(
      id: 'network_1',
      name: 'Flat',
      password: 'network',
      createdAt: DateTime(2026),
      members: [
        Member(
          id: 'member_1',
          name: 'Ali',
          expenses: [
            Expense(amountCents: 0, createdAt: DateTime(2026)),
          ],
        ),
        Member(id: 'member_2', name: 'Mona'),
      ],
    );
    final repository = _LeaveRepository(network);
    final sessionRepository = _LeaveSessionRepository();

    await _pumpDashboard(
      tester,
      network: network,
      repository: repository,
      sessionRepository: sessionRepository,
    );

    await tester.tap(find.byTooltip('Leave Network'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(repository.leftNetworkId, 'network_1');
    expect(repository.leftMemberId, 'member_1');
    expect(sessionRepository.cleared, isTrue);
  });

  testWidgets('leave flow allows archived history when active total is zero',
      (tester) async {
    final network = ExpenseNetwork(
      id: 'network_1',
      name: 'Flat',
      password: 'network',
      createdAt: DateTime(2026),
      members: [
        Member(
          id: 'member_1',
          name: 'Ali',
          expenses: [
            Expense(
              amountCents: 1000,
              createdAt: DateTime(2026),
              archivedAt: DateTime(2026, 2),
            ),
          ],
        ),
        Member(id: 'member_2', name: 'Mona'),
      ],
    );
    final repository = _LeaveRepository(network);
    final sessionRepository = _LeaveSessionRepository();

    await _pumpDashboard(
      tester,
      network: network,
      repository: repository,
      sessionRepository: sessionRepository,
    );

    await tester.tap(find.byTooltip('Leave Network'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(repository.leftNetworkId, 'network_1');
    expect(repository.leftMemberId, 'member_1');
    expect(repository.deletedNetwork, isFalse);
    expect(repository.remainingMembers.map((member) => member.id), [
      'member_2',
    ]);
    expect(sessionRepository.cleared, isTrue);
  });

  testWidgets('last member leave deletes the network in the repository',
      (tester) async {
    final network = ExpenseNetwork(
      id: 'network_1',
      name: 'Flat',
      password: 'network',
      createdAt: DateTime(2026),
      members: [
        Member(id: 'member_1', name: 'Ali'),
      ],
    );
    final repository = _LeaveRepository(network);
    final sessionRepository = _LeaveSessionRepository();

    await _pumpDashboard(
      tester,
      network: network,
      repository: repository,
      sessionRepository: sessionRepository,
    );

    await tester.tap(find.byTooltip('Leave Network'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(repository.deletedNetwork, isTrue);
    expect(repository.remainingMembers, isEmpty);
    expect(await repository.findNetwork('Flat'), isNull);
    final recreated = await repository.createNetwork(
      displayName: 'Mona',
      networkName: 'Flat',
      password: 'network',
      memberPassword: 'member',
      currencyCode: 'USD',
    );
    expect(recreated.name, 'Flat');
    expect(recreated.members.single.name, 'Mona');
    expect(sessionRepository.cleared, isTrue);
  });

  testWidgets('last member leave dialog warns that network will be deleted',
      (tester) async {
    final network = ExpenseNetwork(
      id: 'network_1',
      name: 'Flat',
      password: 'network',
      createdAt: DateTime(2026),
      members: [
        Member(id: 'member_1', name: 'Ali'),
      ],
    );

    await _pumpDashboard(
      tester,
      network: network,
      repository: _LeaveRepository(network),
      sessionRepository: _LeaveSessionRepository(),
    );

    await tester.tap(find.byTooltip('Leave Network'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'You are the last member. Leaving will permanently delete this network.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required ExpenseNetwork network,
  required _LeaveRepository repository,
  required _LeaveSessionRepository sessionRepository,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NetworkDashboardScreen(
        repository: repository,
        sessionRepository: sessionRepository,
        network: network,
        currentMemberId: 'member_1',
      ),
    ),
  );
}

class _LeaveSessionRepository implements SessionRepository {
  bool cleared = false;

  @override
  Future<void> clearActiveSession() async {
    cleared = true;
  }

  @override
  Future<AccountSession?> getActiveSession() async => null;

  @override
  Future<AccountSessionAuthState> restoreAuthenticatedSession() async {
    return const AccountSessionAuthState(
      accountSession: null,
      accountSessionExists: false,
      supabaseSessionExists: false,
      currentUserExists: false,
      authRestored: false,
    );
  }

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
    String? memberPassword,
    String? networkId,
  }) async {}
}

class _LeaveRepository implements ExpenseNetworkRepository {
  _LeaveRepository(this.network);

  final ExpenseNetwork network;
  String? leftNetworkId;
  String? leftMemberId;
  bool deletedNetwork = false;
  late List<Member> remainingMembers = List.of(network.members);

  @override
  Future<void> leaveNetwork({
    required String networkId,
    required String memberId,
  }) async {
    leftNetworkId = networkId;
    leftMemberId = memberId;
    if (remainingMembers.length == 1 &&
        remainingMembers.single.id == memberId) {
      remainingMembers = [];
      deletedNetwork = true;
      return;
    }
    remainingMembers =
        remainingMembers.where((member) => member.id != memberId).toList();
  }

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async =>
      const [];

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async {
    if (deletedNetwork) return null;
    return network.copyWith(members: remainingMembers);
  }

  @override
  Future<Member?> getMemberHistory({
    required String networkName,
    required String memberId,
  }) async =>
      network.findMemberById(memberId);

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
  }) async {
    if (!deletedNetwork &&
        SupabaseExpenseNetworkRepository.normalizeName(networkName) ==
            SupabaseExpenseNetworkRepository.normalizeName(network.name)) {
      throw const RepositoryException(
        'This network name is already in use. Choose another name.',
        code: 'duplicate_network',
      );
    }
    deletedNetwork = false;
    remainingMembers = [Member(id: 'new_member', name: displayName)];
    return ExpenseNetwork(
      id: 'new_network',
      name: networkName,
      password: password,
      members: remainingMembers,
      createdAt: DateTime(2026),
      currencyCode: currencyCode,
    );
  }

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
      network.findMemberById(memberId);

  @override
  Future<ExpenseResetRequest?> getActiveResetRequest({
    required String networkId,
  }) async =>
      null;

  @override
  Future<List<ExpenseNetwork>> getNetworks() async => [network];

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
      network.findMemberById(memberId)!;

  @override
  Future<Member> resetMemberPassword({
    required String networkId,
    required String adminMemberId,
    required String targetMemberId,
    required String newPassword,
  }) async =>
      throw UnimplementedError();
}
