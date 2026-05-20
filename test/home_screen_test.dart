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
}

class _HomeSessionFake implements SessionRepository {
  @override
  Future<void> clearActiveSession() async {}

  @override
  Future<AccountSession?> getActiveSession() async => null;

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
  }) async {}
}

class _HomeRepositoryFake implements ExpenseNetworkRepository {
  const _HomeRepositoryFake();

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async => null;

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
  Future<List<ExpenseNetwork>> getNetworks() async => const [];

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
