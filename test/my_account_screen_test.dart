import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/screens/my_account_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('valid saved account opens dashboard and saves session',
      (tester) async {
    final repository = _AccountRepository();
    final sessions = _AccountSessionRepository();

    await _pumpAccount(
      tester,
      repository: repository,
      sessions: sessions,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account password'),
      'member-pass',
    );
    await tester.tap(find.text('Continue to account'));
    await tester.pumpAndSettle();

    expect(repository.authenticatedMemberName, 'Ali');
    expect(sessions.saved?.networkName, 'Flat');
    expect(sessions.saved?.memberId, 'member_1');
    expect(find.text('Dashboard Flat member_1'), findsOneWidget);
    expect(find.text('Continue to account'), findsNothing);
  });

  testWidgets('valid account still opens dashboard if session save fails',
      (tester) async {
    final repository = _AccountRepository();
    final sessions = _AccountSessionRepository(
      saveError: Exception('metadata write failed'),
    );

    await _pumpAccount(
      tester,
      repository: repository,
      sessions: sessions,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account password'),
      'member-pass',
    );
    await tester.tap(find.text('Continue to account'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Flat member_1'), findsOneWidget);
    expect(find.textContaining('metadata'), findsNothing);
  });

  testWidgets('wrong personal password stays on account screen', (tester) async {
    final repository = _AccountRepository(
      authenticateError: const RepositoryException(
        'Member password is incorrect.',
        code: 'member_invalid_password',
      ),
    );

    await _pumpAccount(
      tester,
      repository: repository,
      sessions: _AccountSessionRepository(),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account password'),
      'wrong-pass',
    );
    await tester.tap(find.text('Continue to account'));
    await tester.pump();

    expect(find.text('Personal password is incorrect.'), findsOneWidget);
    expect(find.text('Continue to account'), findsOneWidget);
    expect(find.textContaining('backend_'), findsNothing);
  });

  testWidgets('deleted saved member clears invalid session safely',
      (tester) async {
    final sessions = _AccountSessionRepository(
      session: const AccountSession(
        networkName: 'Flat',
        memberId: 'deleted_member',
      ),
    );

    await _pumpAccount(
      tester,
      repository: _AccountRepository(),
      sessions: sessions,
    );
    await tester.pumpAndSettle();

    expect(sessions.cleared, isTrue);
    expect(
      find.text(
        'This saved network is no longer available. Please create or join a network again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('deleted account during resume clears session safely',
      (tester) async {
    final sessions = _AccountSessionRepository();
    final repository = _AccountRepository(
      authenticateError: const RepositoryException(
        'Member not found.',
        code: 'member_not_found',
      ),
    );

    await _pumpAccount(
      tester,
      repository: repository,
      sessions: sessions,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account password'),
      'member-pass',
    );
    await tester.tap(find.text('Continue to account'));
    await tester.pump();

    expect(sessions.cleared, isTrue);
    expect(
      find.text(
        'This saved network is no longer available. Please create or join a network again.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpAccount(
  WidgetTester tester, {
  required _AccountRepository repository,
  required _AccountSessionRepository sessions,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyAccountScreen(
        repository: repository,
        sessionRepository: sessions,
        dashboardBuilder: (network, currentMemberId) => Scaffold(
          body: Text('Dashboard ${network.name} $currentMemberId'),
        ),
      ),
    ),
  );
}

ExpenseNetwork _network() {
  return ExpenseNetwork(
    id: 'network_1',
    name: 'Flat',
    password: 'network-hash',
    createdAt: DateTime(2026),
    members: [
      Member(
        id: 'member_1',
        name: 'Ali',
        passwordHash: 'member-hash',
        passwordSalt: 'member-salt',
      ),
    ],
  );
}

class _AccountSessionRepository implements SessionRepository {
  _AccountSessionRepository({this.session, this.saveError});

  AccountSession? session;
  final Object? saveError;
  AccountSession? saved;
  bool cleared = false;

  @override
  Future<void> clearActiveSession() async {
    cleared = true;
    session = null;
  }

  @override
  Future<AccountSession?> getActiveSession() async => session;

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
  }) async {
    final error = saveError;
    if (error != null) throw error;
    saved = AccountSession(networkName: networkName, memberId: memberId);
    session = saved;
  }
}

class _AccountRepository implements ExpenseNetworkRepository {
  _AccountRepository({this.authenticateError});

  final RepositoryException? authenticateError;
  String? authenticatedMemberName;

  @override
  Future<List<ExpenseNetwork>> getNetworks() async => [_network()];

  @override
  Future<ExpenseNetwork> authenticateMember({
    required String networkName,
    required String memberName,
    required String memberPassword,
  }) async {
    authenticatedMemberName = memberName;
    final error = authenticateError;
    if (error != null) throw error;
    return _network();
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
  Future<ExpenseNetwork> approveResetRequest({
    required String networkName,
    required String resetRequestId,
    required String memberId,
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
      _network().findMemberById(memberId);

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async => _network();

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
      _network().findMemberById(memberId);

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async =>
      const [];

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
      _network().findMemberById(memberId)!;
}
