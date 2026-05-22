import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/screens/join_network_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('invite join passes network id to cloud repository',
      (tester) async {
    final repository = _InviteJoinRepository();
    final sessions = _SessionRepository();

    await tester.pumpWidget(
      _TestApp(
        child: JoinNetworkScreen(
          repository: repository,
          sessionRepository: sessions,
          inviteNetworkId: 'network_1',
          dashboardBuilder: (network, currentMemberId) => Scaffold(
            body: Text('Dashboard ${network.name} $currentMemberId'),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'User display name'),
      'Mona',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Network password'),
      'network-pass',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Personal account password'),
      'member-pass',
    );
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(repository.joinedNetworkId, 'network_1');
    expect(sessions.saved?.networkName, 'Flat');
    expect(sessions.saved?.memberId, 'mona-id');
    expect(find.text('Dashboard Flat mona-id'), findsOneWidget);
    expect(find.text('Join'), findsNothing);
  });

  testWidgets('successful join still opens dashboard if session write fails',
      (tester) async {
    final repository = _InviteJoinRepository();
    final sessions = _SessionRepository(
      saveError: Exception('metadata write failed'),
    );

    await tester.pumpWidget(
      _TestApp(
        child: JoinNetworkScreen(
          repository: repository,
          sessionRepository: sessions,
          dashboardBuilder: (network, currentMemberId) => Scaffold(
            body: Text('Dashboard ${network.name} $currentMemberId'),
          ),
        ),
      ),
    );

    await _submitJoinForm(tester);
    await tester.pumpAndSettle();

    expect(repository.joinCalls, 1);
    expect(find.text('Dashboard Flat mona-id'), findsOneWidget);
    expect(find.textContaining('failed'), findsNothing);
  });

  testWidgets('invalid join credentials show localized friendly error',
      (tester) async {
    final repository = _InviteJoinRepository(
      joinError: const RepositoryException(
        'Network name or password is incorrect.',
        code: 'network_invalid_credentials',
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        child: JoinNetworkScreen(
          repository: repository,
          sessionRepository: _SessionRepository(),
        ),
      ),
    );

    await _submitJoinForm(tester);
    await tester.pump();

    expect(find.text('Network name or password is incorrect.'), findsOneWidget);
    expect(find.textContaining('backend_'), findsNothing);
  });

  testWidgets('duplicate member shows localized friendly error',
      (tester) async {
    final repository = _InviteJoinRepository(
      joinError: const RepositoryException(
        'This member name is already used in the network.',
        code: 'duplicate_member',
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        child: JoinNetworkScreen(
          repository: repository,
          sessionRepository: _SessionRepository(),
        ),
      ),
    );

    await _submitJoinForm(tester);
    await tester.pump();

    expect(
      find.text('This member name is already used in the network.'),
      findsOneWidget,
    );
    expect(find.textContaining('backend_'), findsNothing);
  });
}

Future<void> _submitJoinForm(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'User display name'),
    'Mona',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Network name'),
    'Flat',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Network password'),
    'network-pass',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Personal account password'),
    'member-pass',
  );
  await tester.tap(find.text('Join'));
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }
}

class _SessionRepository implements SessionRepository {
  _SessionRepository({this.saveError});

  final Object? saveError;
  AccountSession? saved;

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
  }) async {
    final error = saveError;
    if (error != null) throw error;
    saved = AccountSession(networkName: networkName, memberId: memberId);
  }
}

class _InviteJoinRepository implements ExpenseNetworkRepository {
  _InviteJoinRepository({this.joinError});

  final RepositoryException? joinError;
  String? joinedNetworkId;
  int joinCalls = 0;

  @override
  Future<ExpenseNetwork> joinNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
    String? networkId,
  }) async {
    joinCalls += 1;
    joinedNetworkId = networkId;
    final error = joinError;
    if (error != null) throw error;
    return ExpenseNetwork(
      id: networkId ?? 'network_1',
      name: 'Flat',
      password: 'hash',
      createdAt: DateTime(2026),
      members: [
        Member(id: 'owner-id', name: 'Ali'),
        Member(id: 'mona-id', name: displayName),
      ],
    );
  }

  @override
  Future<void> leaveNetwork({
    required String networkId,
    required String memberId,
  }) async {}

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
    required String expenseId,
    required String editedByMemberId,
    required int amountCents,
    String? note,
    DateTime? createdAt,
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
  Future<List<ExpenseNetwork>> getNetworks() async => const [];

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async =>
      const [];

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
      Member(name: 'Mona', id: memberId);
}
