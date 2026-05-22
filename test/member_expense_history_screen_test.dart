import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/expense_reset_request.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/screens/member_expense_history_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows edit icon only for expenses created by current member',
      (tester) async {
    final ownExpense = Expense(
      id: 'expense_1',
      amountCents: 1200,
      createdAt: DateTime(2026),
      addedByMemberId: 'member_1',
      addedByMemberName: 'Ali',
    );
    final otherExpense = Expense(
      id: 'expense_2',
      amountCents: 900,
      createdAt: DateTime(2026),
      addedByMemberId: 'member_2',
      addedByMemberName: 'Mona',
    );
    final member = Member(
      id: 'member_1',
      name: 'Ali',
      expenses: [ownExpense, otherExpense],
    );
    final network = _network(member);

    await _pumpHistory(tester, network: network, member: member);

    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
  });

  testWidgets('editing own expense calls repository and refreshes history',
      (tester) async {
    final expense = Expense(
      id: 'expense_1',
      amountCents: 1200,
      createdAt: DateTime(2026),
      addedByMemberId: 'member_1',
      addedByMemberName: 'Ali',
    );
    final member = Member(id: 'member_1', name: 'Ali', expenses: [expense]);
    final network = _network(member);
    final repository = _HistoryRepository(network);

    await _pumpHistory(
      tester,
      network: network,
      member: member,
      repository: repository,
    );

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '15.50');
    await tester.enterText(
      find.widgetWithText(TextField, 'Note / description (optional)'),
      'Updated',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.editedExpenseId, 'expense_1');
    expect(repository.editedByMemberId, 'member_1');
    expect(repository.editedAmountCents, 1550);
    expect(repository.editedNote, 'Updated');
    expect(find.textContaining('15.50'), findsWidgets);
  });
}

Future<void> _pumpHistory(
  WidgetTester tester, {
  required ExpenseNetwork network,
  required Member member,
  _HistoryRepository? repository,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MemberExpenseHistoryScreen(
        repository: repository ?? _HistoryRepository(network),
        network: network,
        member: member,
        currentMemberId: 'member_1',
      ),
    ),
  );
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

class _HistoryRepository implements ExpenseNetworkRepository {
  _HistoryRepository(this.network);

  ExpenseNetwork network;
  String? editedExpenseId;
  String? editedByMemberId;
  int? editedAmountCents;
  String? editedNote;

  @override
  Future<ExpenseNetwork> updateExpense({
    required String networkName,
    required String expenseId,
    required String editedByMemberId,
    required int amountCents,
    String? note,
    DateTime? createdAt,
  }) async {
    editedExpenseId = expenseId;
    this.editedByMemberId = editedByMemberId;
    editedAmountCents = amountCents;
    editedNote = note;
    final updatedMembers = network.members.map((member) {
      return member.copyWith(
        expenses: member.expenses.map((expense) {
          if (expense.id != expenseId) return expense;
          return expense.copyWith(
            amountCents: amountCents,
            note: note,
            clearNote: note == null,
            createdAt: createdAt,
          );
        }).toList(),
      );
    }).toList();
    network = network.copyWith(members: updatedMembers);
    return network;
  }

  @override
  Future<Member?> getMemberHistory({
    required String networkName,
    required String memberId,
  }) async =>
      network.findMemberById(memberId);

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async => network;

  @override
  Future<Member?> findMember({
    required String networkName,
    required String memberId,
  }) async =>
      network.findMemberById(memberId);

  @override
  Future<List<ExpenseNetwork>> getNetworks() async => [network];

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
  Future<ExpenseResetRequest?> getActiveResetRequest({
    required String networkId,
  }) async =>
      null;

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
      throw UnimplementedError();
}
