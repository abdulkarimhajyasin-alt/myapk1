import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/screens/notifications_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders expense edit notification text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NotificationsScreen(
          repository: _NotificationsRepository([
            NetworkNotification(
              id: 'notification-id',
              networkId: 'network-id',
              recipientMemberId: 'mona-id',
              actorMemberName: 'Ali',
              expenseAmountCents: 1450,
              currencySymbol: r'$',
              noteSnippet: 'Updated coffee',
              kind: NetworkNotificationKind.expenseUpdated,
            ),
          ]),
          networkId: 'network-id',
          memberId: 'mona-id',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ali edited an expense of \$ 14.50'), findsOneWidget);
    expect(find.text('Note: Updated coffee'), findsOneWidget);
  });
}

class _NotificationsRepository implements ExpenseNetworkRepository {
  const _NotificationsRepository(this.notifications);

  final List<NetworkNotification> notifications;

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async =>
      notifications
          .where(
            (notification) =>
                notification.networkId == networkId &&
                notification.recipientMemberId == memberId,
          )
          .toList();

  @override
  Future<void> clearNotificationsForMember({
    required String networkId,
    required String memberId,
  }) async {}

  @override
  Future<void> deleteNotification(String notificationId) async {}

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
  Future<ExpenseNetwork> deleteExpense({
    required String networkName,
    required String networkId,
    required String expenseId,
    required String deletedByMemberId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Member?> findMember({
    required String networkName,
    required String memberId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async =>
      throw UnimplementedError();

  @override
  Future<ExpenseResetRequest?> getActiveResetRequest({
    required String networkId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Member?> getMemberHistory({
    required String networkName,
    required String memberId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<ExpenseNetwork>> getNetworks() async =>
      throw UnimplementedError();

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
  }) async =>
      throw UnimplementedError();

  @override
  Future<Member> resetMemberPassword({
    required String networkId,
    required String adminMemberId,
    required String targetMemberId,
    required String newPassword,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> saveNetwork(ExpenseNetwork network) async =>
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
}
