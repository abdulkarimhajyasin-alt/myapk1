import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/screens/create_network_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creating after stale session cleanup succeeds', (tester) async {
    final repository = _CreateRepositoryFake(
      savedNetwork: null,
      createdNetwork: _createdNetwork('Flat'),
    );
    final sessions = _CreateSessionFake(
      const AccountSession(networkName: 'Deleted Flat', memberId: 'old_member'),
    );

    await _pumpCreateScreen(tester, repository: repository, sessions: sessions);
    await _submitCreateForm(tester);

    expect(sessions.cleared, isTrue);
    expect(repository.createdNetworkName, 'Flat');
    expect(sessions.saved?.networkName, 'Flat');
    expect(sessions.saved?.memberId, 'member_1');
  });

  testWidgets('successful create saves session and opens dashboard',
      (tester) async {
    final repository = _CreateRepositoryFake(
      createdNetwork: _createdNetwork('Flat'),
    );
    final sessions = _CreateSessionFake(null);

    await _pumpCreateScreen(
      tester,
      repository: repository,
      sessions: sessions,
      dashboardBuilder: (network, currentMemberId) => Scaffold(
        body: Text('Dashboard ${network.name} $currentMemberId'),
      ),
    );
    await _submitCreateForm(tester);
    await tester.pumpAndSettle();

    expect(sessions.saved?.networkName, 'Flat');
    expect(sessions.saved?.memberId, 'member_1');
    expect(find.text('Dashboard Flat member_1'), findsOneWidget);
    expect(find.text('Create'), findsNothing);
  });

  testWidgets('successful create still opens dashboard if session write fails',
      (tester) async {
    final repository = _CreateRepositoryFake(
      createdNetwork: _createdNetwork('Flat'),
    );
    final sessions = _CreateSessionFake(
      null,
      saveError: const RepositoryException(
        'TEMP DEBUG: createNetwork failed.',
        code: 'supabase_create_network_failed',
      ),
    );

    await _pumpCreateScreen(
      tester,
      repository: repository,
      sessions: sessions,
      dashboardBuilder: (network, currentMemberId) => Scaffold(
        body: Text('Dashboard ${network.name} $currentMemberId'),
      ),
    );
    await _submitCreateForm(tester);
    await tester.pumpAndSettle();

    expect(repository.createdNetworkName, 'Flat');
    expect(find.text('Dashboard Flat member_1'), findsOneWidget);
    expect(find.textContaining('TEMP DEBUG'), findsNothing);
  });

  testWidgets('create flow does not show stale session unavailable message',
      (tester) async {
    final repository = _CreateRepositoryFake(
      findNetworkError: const RepositoryException(
        'Saved cloud record is no longer available.',
        code: 'supabase_not_found',
      ),
      createdNetwork: _createdNetwork('Flat'),
    );
    final sessions = _CreateSessionFake(
      const AccountSession(networkName: 'Deleted Flat', memberId: 'old_member'),
    );

    await _pumpCreateScreen(tester, repository: repository, sessions: sessions);
    await _submitCreateForm(tester);

    expect(
      find.text(
        'This saved network is no longer available. Please create or join a network again.',
      ),
      findsNothing,
    );
    expect(repository.createdNetworkName, 'Flat');
  });

  testWidgets('active network name conflict shows localized name conflict',
      (tester) async {
    final repository = _CreateRepositoryFake(
      createError: const RepositoryException(
        'This network name is already in use. Choose another name.',
        code: 'duplicate_network',
      ),
    );

    await _pumpCreateScreen(
      tester,
      locale: const Locale('ar'),
      repository: repository,
      sessions: _CreateSessionFake(null),
    );
    await _submitCreateForm(tester);
    await tester.pump();

    expect(
        find.text('اسم الشبكة مستخدم بالفعل. اختر اسمًا آخر.'), findsOneWidget);
    expect(
      find.text(
        'هذه الشبكة المحفوظة لم تعد متاحة. أنشئ شبكة أو انضم إلى شبكة مرة أخرى.',
      ),
      findsNothing,
    );
  });

  testWidgets('temporary backend debug text is not user-facing',
      (tester) async {
    final repository = _CreateRepositoryFake(
      createError: const RepositoryException(
        'TEMP DEBUG: createNetwork failed.\nbackend_code: 42501',
      ),
    );

    await _pumpCreateScreen(
      tester,
      repository: repository,
      sessions: _CreateSessionFake(null),
    );
    await _submitCreateForm(tester);
    await tester.pump();

    expect(find.textContaining('TEMP DEBUG'), findsNothing);
    expect(find.textContaining('backend_code'), findsNothing);
    expect(
      find.text('Could not create the network. Please try again.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpCreateScreen(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  required _CreateRepositoryFake repository,
  required _CreateSessionFake sessions,
  CreateNetworkDashboardBuilder? dashboardBuilder,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CreateNetworkScreen(
        repository: repository,
        sessionRepository: sessions,
        dashboardBuilder: dashboardBuilder,
      ),
    ),
  );
}

Future<void> _submitCreateForm(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Ali');
  await tester.enterText(find.byType(TextFormField).at(1), 'Flat');
  await tester.enterText(find.byType(TextFormField).at(2), 'network');
  await tester.enterText(find.byType(TextFormField).at(3), 'member');
  await tester.tap(find.byType(FilledButton));
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

ExpenseNetwork _createdNetwork(String name) {
  return ExpenseNetwork(
    id: 'network_1',
    name: name,
    password: 'network',
    members: [Member(id: 'member_1', name: 'Ali')],
    createdAt: DateTime(2026),
  );
}

class _CreateSessionFake implements SessionRepository {
  _CreateSessionFake(this.session, {this.saveError});

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
  Future<AccountSessionAuthState> restoreAuthenticatedSession() async {
    return AccountSessionAuthState(
      accountSession: session,
      accountSessionExists: session != null,
      supabaseSessionExists: session != null,
      currentUserExists: session != null,
      authRestored: session != null,
      memberId: session?.memberId,
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
    session = saved;
  }
}

class _CreateRepositoryFake implements ExpenseNetworkRepository {
  _CreateRepositoryFake({
    this.savedNetwork,
    this.findNetworkError,
    this.createdNetwork,
    this.createError,
  });

  final ExpenseNetwork? savedNetwork;
  final RepositoryException? findNetworkError;
  final ExpenseNetwork? createdNetwork;
  final RepositoryException? createError;

  String? createdNetworkName;

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async {
    final error = findNetworkError;
    if (error != null) throw error;
    return savedNetwork;
  }

  @override
  Future<ExpenseNetwork> createNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
    required String currencyCode,
  }) async {
    createdNetworkName = networkName.trim();
    final error = createError;
    if (error != null) throw error;
    return createdNetwork ?? _createdNetwork(networkName.trim());
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
      savedNetwork?.findMemberById(memberId);

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
      savedNetwork?.findMemberById(memberId);

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async =>
      const [];

  @override
  Future<List<ExpenseNetwork>> getNetworks() async =>
      savedNetwork == null ? const [] : [savedNetwork!];

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
