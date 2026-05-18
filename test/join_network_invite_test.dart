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
  testWidgets('local invite join explains that QR requires cloud mode',
      (tester) async {
    final repository = _InviteJoinRepository();

    await tester.pumpWidget(
      _TestApp(
        child: JoinNetworkScreen(
          repository: repository,
          sessionRepository: _SessionRepository(),
          dataMode: 'local',
          inviteNetworkId: 'network_1',
        ),
      ),
    );

    expect(find.text('QR invite joining requires cloud mode. You can still join manually in local mode.'), findsWidgets);
  });

  testWidgets('cloud invite join passes network id to repository',
      (tester) async {
    final repository = _InviteJoinRepository();

    await tester.pumpWidget(
      _TestApp(
        child: JoinNetworkScreen(
          repository: repository,
          sessionRepository: _SessionRepository(),
          dataMode: 'supabase',
          inviteNetworkId: 'network_1',
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
  });
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
  @override
  Future<void> clearActiveSession() async {}

  @override
  Future<AccountSession?> getActiveSession() async => null;

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
    String? dataMode,
  }) async {}
}

class _InviteJoinRepository implements ExpenseNetworkRepository {
  String? joinedNetworkId;

  @override
  Future<ExpenseNetwork> joinNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
    String? networkId,
  }) async {
    joinedNetworkId = networkId;
    return ExpenseNetwork(
      id: networkId ?? 'network_1',
      name: 'Flat',
      password: 'hash',
      createdAt: DateTime(2026),
      members: [Member(name: displayName)],
    );
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
