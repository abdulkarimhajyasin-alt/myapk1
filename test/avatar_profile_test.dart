import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/screens/network_dashboard_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/session_repository.dart';
import 'package:expense_network/widgets/member_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old member data loads with generated avatar fields', () {
    final member = Member.fromJson({
      'name': 'Ali Hassan',
      'createdAt': DateTime(2026).toIso8601String(),
      'expenses': [],
    });

    expect(member.avatarInitials, 'AH');
    expect(member.avatarColor, startsWith('#'));
  });

  test('explicit avatar fields are preserved', () {
    final member = Member(
      name: 'Mona',
      avatarColor: '#059669',
      avatarInitials: 'MO',
    );

    expect(member.avatarColor, '#059669');
    expect(member.avatarInitials, 'MO');
  });

  test('member image path and url are preserved', () {
    final member = Member.fromJson({
      'name': 'Mona',
      'createdAt': DateTime(2026).toIso8601String(),
      'avatarImagePath': 'network/member.jpg',
      'avatarImageUrl': 'https://example.com/member.jpg',
    });

    expect(member.avatarImagePath, 'network/member.jpg');
    expect(member.avatarImageUrl, 'https://example.com/member.jpg');
  });

  testWidgets('avatar fallback renders initials without image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberAvatar(
            member: Member(name: 'Ali Hassan'),
          ),
        ),
      ),
    );

    expect(find.text('AH'), findsOneWidget);
  });

  testWidgets('dashboard renders image avatar when available', (tester) async {
    final network = _network(
      Member(
        id: 'member_1',
        name: 'Ali',
        avatarImageUrl: 'https://example.com/avatar.jpg',
      ),
    );

    await _pumpDashboard(
      tester,
      network: network,
      repository: _AvatarRepository(network),
    );

    final avatar = tester.widget<MemberAvatar>(
      find.byType(MemberAvatar).first,
    );
    expect(avatar.member.avatarImageUrl, 'https://example.com/avatar.jpg');
    expect(find.text('A'), findsNothing);
  });

  testWidgets('dashboard does not expose avatar editing while disabled',
      (tester) async {
    final network = _network(Member(id: 'member_1', name: 'Ali'));

    await _pumpDashboard(
      tester,
      network: network,
      repository: _AvatarRepository(network),
    );

    expect(find.text('Edit avatar'), findsNothing);
    expect(find.byIcon(Icons.palette_rounded), findsNothing);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required ExpenseNetwork network,
  required _AvatarRepository repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NetworkDashboardScreen(
        repository: repository,
        sessionRepository: _AvatarSessionRepository(
          const AccountSession(networkName: 'Flat', memberId: 'member_1'),
        ),
        network: network,
        currentMemberId: 'member_1',
      ),
    ),
  );
  await tester.pump();
}

ExpenseNetwork _network(Member member) {
  return ExpenseNetwork(
    id: 'network_1',
    name: 'Flat',
    password: 'hash',
    createdAt: DateTime(2026),
    members: [member],
  );
}

class _AvatarSessionRepository implements SessionRepository {
  _AvatarSessionRepository([this.session]);

  AccountSession? session;

  @override
  Future<void> clearActiveSession() async {}

  @override
  Future<AccountSession?> getActiveSession() async {
    return session;
  }

  @override
  Future<AccountSessionAuthState> restoreAuthenticatedSession() async {
    final activeSession = await getActiveSession();
    return AccountSessionAuthState(
      accountSession: activeSession,
      accountSessionExists: activeSession != null,
      supabaseSessionExists: activeSession != null,
      currentUserExists: activeSession != null,
      authRestored: activeSession != null,
      memberId: activeSession?.memberId,
    );
  }

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
    String? memberPassword,
  }) async {}
}

class _AvatarRepository implements ExpenseNetworkRepository {
  _AvatarRepository(this.network);

  ExpenseNetwork network;
  String? savedAvatarImagePath;
  String? savedAvatarImageUrl;

  @override
  Future<Member> updateMemberProfile({
    required String networkName,
    required String memberId,
    String? avatarColor,
    String? avatarInitials,
    String? avatarImagePath,
    String? avatarImageUrl,
  }) async {
    savedAvatarImagePath = avatarImagePath;
    savedAvatarImageUrl = avatarImageUrl;
    final updated = network.findMemberById(memberId)!.copyWith(
          avatarImagePath: avatarImagePath,
          avatarImageUrl: avatarImageUrl,
        );
    network = network.copyWith(members: [updated]);
    return updated;
  }

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async => network;

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async =>
      const [];

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
  Future<void> leaveNetwork({
    required String networkId,
    required String memberId,
  }) async {}

  @override
  Future<void> saveNetwork(ExpenseNetwork network) async {}
}
