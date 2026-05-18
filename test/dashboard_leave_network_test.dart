import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/screens/network_dashboard_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    await tester.pumpWidget(
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

    await tester.tap(find.byTooltip('Leave Network'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(repository.leftNetworkId, 'network_1');
    expect(repository.leftMemberId, 'member_1');
    expect(sessionRepository.cleared, isTrue);
  });
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
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
  }) async {}
}

class _LeaveRepository implements ExpenseNetworkRepository {
  _LeaveRepository(this.network);

  final ExpenseNetwork network;
  String? leftNetworkId;
  String? leftMemberId;

  @override
  Future<void> leaveNetwork({
    required String networkId,
    required String memberId,
  }) async {
    leftNetworkId = networkId;
    leftMemberId = memberId;
  }

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async =>
      const [];

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async => network;

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
}
