import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/screens/expense_settlement_screen.dart';
import 'package:expense_network/screens/network_dashboard_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/session_repository.dart';
import 'package:expense_network/services/supabase_expense_network_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin badge appears for owner member', (tester) async {
    final network = _network(createdByMemberId: 'owner-id');

    await _pumpDashboard(tester, network);

    expect(find.text('مشرف'), findsOneWidget);
  });

  testWidgets('admin badge does not appear for normal member', (tester) async {
    final network = _network(createdByMemberId: 'other-owner-id');

    await _pumpDashboard(
      tester,
      network,
      currentMemberId: 'member-id',
    );

    expect(find.widgetWithText(ListTile, 'Mona'), findsOneWidget);
    expect(find.text('مشرف'), findsNothing);
  });

  testWidgets('non-owner member row does not show admin badge', (tester) async {
    final network = _network(createdByMemberId: 'owner-id');

    await _pumpDashboard(tester, network);

    final normalMemberTile = find.ancestor(
      of: find.text('Mona'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: normalMemberTile, matching: find.text('مشرف')),
      findsNothing,
    );
  });

  testWidgets('owner starts new cycle directly without approval request',
      (tester) async {
    final network = _network(createdByMemberId: 'owner-id');
    final repository = _AdminRepository(network);

    await _pumpSettlement(
      tester,
      network: network,
      repository: repository,
      currentMemberId: 'owner-id',
    );

    await tester.tap(find.text('Start New Cycle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(repository.directStarts, 1);
    expect(repository.approvalRequests, 0);
    expect(find.text('New cycle started.'), findsOneWidget);
    expect(find.text('Reset request pending'), findsNothing);
  });

  testWidgets('normal member still uses approval request flow', (tester) async {
    final network = _network(createdByMemberId: 'owner-id');
    final repository = _AdminRepository(network);

    await _pumpSettlement(
      tester,
      network: network,
      repository: repository,
      currentMemberId: 'member-id',
    );

    await tester.tap(find.text('Start New Cycle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(repository.directStarts, 0);
    expect(repository.approvalRequests, 1);
    expect(find.text('Reset request pending'), findsOneWidget);
  });

  test('repository guard rejects direct start for non-owner', () {
    expect(
      () => SupabaseExpenseNetworkRepository.verifyDirectCycleStartAllowed(
        {'created_by_member_id': 'owner-id'},
        'member-id',
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          'direct_cycle_start_not_owner',
        ),
      ),
    );
  });

  testWidgets('admin sees reset password action for other members',
      (tester) async {
    final network = _network(createdByMemberId: 'owner-id');

    await _pumpDashboard(tester, network);

    expect(find.text('إعادة تعيين كلمة المرور'), findsOneWidget);
  });

  testWidgets('normal member does not see reset password action',
      (tester) async {
    final network = _network(createdByMemberId: 'owner-id');

    await _pumpDashboard(
      tester,
      network,
      currentMemberId: 'member-id',
    );

    expect(find.text('إعادة تعيين كلمة المرور'), findsNothing);
  });

  testWidgets('admin cannot reset own password through member list',
      (tester) async {
    final network = _network(createdByMemberId: 'owner-id');

    await _pumpDashboard(tester, network);

    final ownerTile = find.ancestor(
      of: find.text('Ali'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: ownerTile,
        matching: find.text('إعادة تعيين كلمة المرور'),
      ),
      findsNothing,
    );
  });

  testWidgets('reset password validates required minimum and confirmation',
      (tester) async {
    final network = _network(createdByMemberId: 'owner-id');

    await _pumpDashboard(tester, network);
    await tester.ensureVisible(find.text('إعادة تعيين كلمة المرور'));
    await tester.tap(find.text('إعادة تعيين كلمة المرور'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حفظ'));
    await tester.pump();
    expect(find.text('This field is required.'), findsNWidgets(2));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'كلمة المرور الجديدة'),
      '123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'تأكيد كلمة المرور الجديدة'),
      '4567',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pump();

    expect(
        find.text('Password must be at least 4 characters.'), findsOneWidget);
    expect(find.text('كلمتا المرور غير متطابقتين.'), findsOneWidget);
  });

  testWidgets('reset calls repository with admin and target member ids',
      (tester) async {
    final network = _network(createdByMemberId: 'owner-id');
    final repository = _AdminRepository(network);

    await _pumpDashboard(
      tester,
      network,
      repository: repository,
    );
    await tester.ensureVisible(find.text('إعادة تعيين كلمة المرور'));
    await tester.tap(find.text('إعادة تعيين كلمة المرور'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'كلمة المرور الجديدة'),
      'new-pass',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'تأكيد كلمة المرور الجديدة'),
      'new-pass',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(repository.resetNetworkId, 'network-id');
    expect(repository.resetAdminMemberId, 'owner-id');
    expect(repository.resetTargetMemberId, 'member-id');
    expect(repository.resetNewPassword, 'new-pass');
    expect(find.text('تم تحديث كلمة مرور العضو بنجاح.'), findsOneWidget);
  });

  testWidgets('successful reset allows fake login with new password',
      (tester) async {
    final network = _network(createdByMemberId: 'owner-id');
    final repository = _AdminRepository(network);

    await _pumpDashboard(
      tester,
      network,
      repository: repository,
    );
    await tester.ensureVisible(find.text('إعادة تعيين كلمة المرور'));
    await tester.tap(find.text('إعادة تعيين كلمة المرور'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'كلمة المرور الجديدة'),
      'new-pass',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'تأكيد كلمة المرور الجديدة'),
      'new-pass',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final authenticated = await repository.authenticateMember(
      networkName: 'Flat',
      memberName: 'Mona',
      memberPassword: 'new-pass',
    );
    expect(authenticated.findMemberById('member-id')?.name, 'Mona');
  });

  test('repository guard rejects member password reset by non-owner', () {
    expect(
      () => SupabaseExpenseNetworkRepository.verifyMemberPasswordResetAllowed(
        {'created_by_member_id': 'owner-id'},
        adminMemberId: 'member-id',
        targetMemberId: 'other-id',
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          'member_password_reset_not_owner',
        ),
      ),
    );
  });

  test('repository guard rejects owner self password reset', () {
    expect(
      () => SupabaseExpenseNetworkRepository.verifyMemberPasswordResetAllowed(
        {'created_by_member_id': 'owner-id'},
        adminMemberId: 'owner-id',
        targetMemberId: 'owner-id',
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          'member_password_reset_self_forbidden',
        ),
      ),
    );
  });
}

ExpenseNetwork _network({required String createdByMemberId}) {
  return ExpenseNetwork(
    id: 'network-id',
    name: 'Flat',
    password: 'hash',
    createdAt: DateTime(2026),
    createdByMemberId: createdByMemberId,
    members: [
      Member(id: 'owner-id', name: 'Ali'),
      Member(id: 'member-id', name: 'Mona'),
    ],
  );
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  ExpenseNetwork network, {
  String currentMemberId = 'owner-id',
  _AdminRepository? repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NetworkDashboardScreen(
        repository: repository ?? _AdminRepository(network),
        sessionRepository: _AdminSessionRepository(),
        network: network,
        currentMemberId: currentMemberId,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpSettlement(
  WidgetTester tester, {
  required ExpenseNetwork network,
  required _AdminRepository repository,
  required String currentMemberId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ExpenseSettlementScreen(
        repository: repository,
        network: network,
        currentMemberId: currentMemberId,
      ),
    ),
  );
}

class _AdminSessionRepository implements SessionRepository {
  @override
  Future<void> clearActiveSession() async {}

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

class _AdminRepository implements ExpenseNetworkRepository {
  _AdminRepository(this.network);

  ExpenseNetwork network;
  int directStarts = 0;
  int approvalRequests = 0;
  String? resetNetworkId;
  String? resetAdminMemberId;
  String? resetTargetMemberId;
  String? resetNewPassword;
  final Map<String, String> memberPasswords = {};

  @override
  Future<ExpenseNetwork> createResetRequest({
    required String networkName,
    required String requestedByMemberId,
  }) async {
    if (network.isOwnerMember(requestedByMemberId)) {
      directStarts += 1;
      return network;
    }

    approvalRequests += 1;
    final request = ExpenseResetRequest(
      id: 'reset-id',
      networkId: network.id,
      cycleId: network.activeCycle.id,
      requestedByMemberId: requestedByMemberId,
      requestedByMemberName:
          network.findMemberById(requestedByMemberId)?.name ?? '',
      createdAt: DateTime(2026),
      requiredMemberIds: network.members.map((member) => member.id).toList(),
      requiredMemberNames:
          network.members.map((member) => member.name).toList(),
      approvals: [
        ExpenseResetApproval(
          memberId: requestedByMemberId,
          memberName: network.findMemberById(requestedByMemberId)?.name ?? '',
          approvedAt: DateTime(2026),
        ),
      ],
    );
    network = network.copyWith(resetRequests: [request]);
    return network;
  }

  @override
  Future<Member> resetMemberPassword({
    required String networkId,
    required String adminMemberId,
    required String targetMemberId,
    required String newPassword,
  }) async {
    resetNetworkId = networkId;
    resetAdminMemberId = adminMemberId;
    resetTargetMemberId = targetMemberId;
    resetNewPassword = newPassword;
    memberPasswords[targetMemberId] = newPassword;
    return network.findMemberById(targetMemberId)!;
  }

  @override
  Future<ExpenseNetwork> approveResetRequest({
    required String networkName,
    required String resetRequestId,
    required String memberId,
  }) async =>
      throw UnimplementedError();

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
  Future<ExpenseNetwork> authenticateMember({
    required String networkName,
    required String memberName,
    required String memberPassword,
  }) async {
    final member = network.findMemberByName(memberName);
    if (member == null ||
        memberPasswords[member.id] != null &&
            memberPasswords[member.id] != memberPassword) {
      throw const RepositoryException(
        'Member password is incorrect.',
        code: 'member_invalid_password',
      );
    }
    return network;
  }

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
  Future<ExpenseNetwork> deleteExpense({
    required String networkName,
    required String networkId,
    required String expenseId,
    required String deletedByMemberId,
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
  Future<ExpenseNetwork?> findNetwork(String networkName) async => network;

  @override
  Future<ExpenseResetRequest?> getActiveResetRequest({
    required String networkId,
  }) async =>
      network.activeResetRequest;

  @override
  Future<Member?> getMemberHistory({
    required String networkName,
    required String memberId,
  }) async =>
      network.findMemberById(memberId);

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async =>
      const [];

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
  Future<void> leaveNetwork({
    required String networkId,
    required String memberId,
  }) async {}

  @override
  Future<void> saveNetwork(ExpenseNetwork network) async {}

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
  Future<Member> updateMemberProfile({
    required String networkName,
    required String memberId,
    String? avatarColor,
    String? avatarInitials,
    String? avatarImagePath,
    String? avatarImageUrl,
  }) async =>
      throw UnimplementedError();
}
