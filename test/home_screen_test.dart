import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/screens/home_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home onboarding does not show cloud connected badge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          repository: const _HomeRepositoryFake(),
          sessionRepository: _HomeSessionFake(),
          onChangeLanguage: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cloud connected'), findsNothing);
    expect(find.text('Create Network'), findsOneWidget);
    expect(find.text('Join Network'), findsOneWidget);
  });

  testWidgets('startup shows restoration screen before onboarding',
      (tester) async {
    final session = _HomeSessionFake(null, const Duration(seconds: 1));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          repository: const _HomeRepositoryFake(),
          sessionRepository: session,
          onChangeLanguage: (_) {},
        ),
      ),
    );

    expect(find.text('Restoring your session'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Create Network'), findsNothing);
    expect(find.text('Join Network'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Restoring your session'), findsNothing);
    expect(find.text('Create Network'), findsOneWidget);
    expect(find.text('Join Network'), findsOneWidget);
  });

  testWidgets('valid saved session restores dashboard automatically',
      (tester) async {
    final network = ExpenseNetwork(
      id: 'network_1',
      name: 'Flat',
      password: 'hash',
      createdAt: DateTime(2026),
      members: [Member(id: 'member_1', name: 'Ali')],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          repository: _HomeRepositoryFake(network: network),
          sessionRepository: _HomeSessionFake(
            const AccountSession(networkName: 'Flat', memberId: 'member_1'),
          ),
          onChangeLanguage: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Flat'), findsOneWidget);
    expect(find.text('Ali'), findsWidgets);
    expect(find.text('Create Network'), findsNothing);
  });

  testWidgets('saved session without Supabase auth asks user to re-enter',
      (tester) async {
    final network = ExpenseNetwork(
      id: 'network_1',
      name: 'Flat',
      password: 'hash',
      createdAt: DateTime(2026),
      members: [Member(id: 'member_1', name: 'Ali')],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          repository: _HomeRepositoryFake(network: network),
          sessionRepository: _HomeSessionFake(
            const AccountSession(networkName: 'Flat', memberId: 'member_1'),
            Duration.zero,
            false,
          ),
          onChangeLanguage: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Flat'), findsNothing);
    expect(find.text('Create Network'), findsOneWidget);
    expect(
      find.text(
        'Your secure session needs to be restored. Please open My Account and re-enter your personal password, or join the network again once.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('deleted saved session shows localized recovery message',
      (tester) async {
    final sessions = _HomeSessionFake(
      const AccountSession(networkName: 'Deleted Flat', memberId: 'member_1'),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          repository: const _HomeRepositoryFake(),
          sessionRepository: sessions,
          onChangeLanguage: (_) {},
        ),
      ),
    );
    await tester.pump();
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

class _HomeSessionFake implements SessionRepository {
  _HomeSessionFake([
    this.session,
    Duration delay = Duration.zero,
    this.authRestored = true,
  ]) : _delay = delay;

  AccountSession? session;
  final Duration _delay;
  final bool authRestored;
  bool cleared = false;

  @override
  Future<void> clearActiveSession() async {
    cleared = true;
    session = null;
  }

  @override
  Future<AccountSession?> getActiveSession() async {
    if (_delay > Duration.zero) {
      await Future<void>.delayed(_delay);
    }
    return session;
  }

  @override
  Future<AccountSessionAuthState> restoreAuthenticatedSession() async {
    final activeSession = await getActiveSession();
    return AccountSessionAuthState(
      accountSession: activeSession,
      accountSessionExists: activeSession != null,
      supabaseSessionExists: activeSession != null && authRestored,
      currentUserExists: activeSession != null && authRestored,
      authRestored: activeSession != null && authRestored,
      memberId: activeSession?.memberId,
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

class _HomeRepositoryFake implements ExpenseNetworkRepository {
  const _HomeRepositoryFake({this.network});

  final ExpenseNetwork? network;

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async => network;

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
      null;

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
      throw UnimplementedError();
}
