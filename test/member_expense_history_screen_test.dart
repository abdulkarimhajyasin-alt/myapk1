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

  testWidgets('edit sheet opens with selected expense data', (tester) async {
    final keepExpense = Expense(
      id: 'expense_keep',
      amountCents: 5000,
      note: 'Keep this one',
      createdAt: DateTime(2026),
      addedByMemberId: 'member_1',
      addedByMemberName: 'Ali',
    );
    final expense = Expense(
      id: 'expense_1',
      amountCents: 450,
      note: 'Selected note',
      createdAt: DateTime(2026, 1, 2),
      addedByMemberId: 'member_1',
      addedByMemberName: 'Ali',
    );
    final member = Member(
      id: 'member_1',
      name: 'Ali',
      expenses: [keepExpense, expense],
    );
    final network = _network(member);

    await _pumpHistory(tester, network: network, member: member);

    final targetCard = find.ancestor(
      of: find.text('Note: Selected note'),
      matching: find.byType(Card),
    );
    await tester.tap(find.descendant(
      of: targetCard,
      matching: find.byIcon(Icons.edit_rounded),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Edit expense'), findsOneWidget);
    expect(findEditableText('4.50'), findsOneWidget);
    expect(findEditableText('Selected note'), findsOneWidget);
    expect(find.text('Friday, January 2, 2026'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsNothing);
    expect(find.text('Delete expense'), findsNothing);
  });

  testWidgets('editing exact selected expense updates visible history',
      (tester) async {
    final keepExpense = Expense(
      id: 'expense_keep',
      amountCents: 5000,
      note: 'Keep this one',
      createdAt: DateTime(2026),
      addedByMemberId: 'member_1',
      addedByMemberName: 'Ali',
    );
    final selectedExpense = Expense(
      id: 'expense_selected',
      amountCents: 450,
      note: 'Edit this one',
      createdAt: DateTime(2026, 1, 2),
      addedByMemberId: 'member_1',
      addedByMemberName: 'Ali',
    );
    final member = Member(
      id: 'member_1',
      name: 'Ali',
      expenses: [keepExpense, selectedExpense],
    );
    final network = _network(member);
    final repository = _HistoryRepository(network);

    await _pumpHistory(
      tester,
      network: network,
      member: member,
      repository: repository,
    );

    final targetCard = find.ancestor(
      of: find.text('Note: Edit this one'),
      matching: find.byType(Card),
    );
    await tester.tap(find.descendant(
      of: targetCard,
      matching: find.byIcon(Icons.edit_rounded),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '6.75');
    await tester.enterText(
      find.widgetWithText(TextField, 'Note / description (optional)'),
      'Edited selected',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.editedNetworkId, 'network_1');
    expect(repository.editedExpenseId, 'expense_selected');
    expect(repository.editedByMemberId, 'member_1');
    expect(find.text('Note: Edited selected'), findsOneWidget);
    expect(find.text('Note: Keep this one'), findsOneWidget);
    expect(find.textContaining('50.00'), findsWidgets);
    expect(find.textContaining('6.75'), findsWidgets);
  });

  testWidgets('zero-row update shows failure without success', (tester) async {
    final expense = Expense(
      id: 'expense_1',
      amountCents: 1200,
      createdAt: DateTime(2026),
      addedByMemberId: 'member_1',
      addedByMemberName: 'Ali',
    );
    final member = Member(id: 'member_1', name: 'Ali', expenses: [expense]);
    final network = _network(member);
    final repository = _HistoryRepository(network, updateSucceeds: false);

    await _pumpHistory(
      tester,
      network: network,
      member: member,
      repository: repository,
    );

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '15.50');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.editedExpenseId, 'expense_1');
    expect(
      find.text('Could not update this expense. Please refresh and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('12.00'), findsWidgets);
    expect(find.textContaining('15.50'), findsNothing);
  });

  testWidgets('other members cannot edit another member expense',
      (tester) async {
    final expense = Expense(
      id: 'expense_2',
      amountCents: 900,
      createdAt: DateTime(2026),
      addedByMemberId: 'member_2',
      addedByMemberName: 'Mona',
    );
    final member = Member(id: 'member_1', name: 'Ali', expenses: [expense]);
    final network = _network(member);

    await _pumpHistory(tester, network: network, member: member);

    expect(find.byIcon(Icons.edit_rounded), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsNothing);
  });

  testWidgets('archived own expense does not expose edit or delete',
      (tester) async {
    final archivedExpense = Expense(
      id: 'expense_archived',
      amountCents: 5000,
      createdAt: DateTime(2026),
      addedByMemberId: 'member_1',
      addedByMemberName: 'Ali',
      archivedAt: DateTime(2026, 2),
    );
    final activeExpense = Expense(
      id: 'expense_active',
      amountCents: 450,
      createdAt: DateTime(2026, 1, 2),
      addedByMemberId: 'member_2',
      addedByMemberName: 'Mona',
    );
    final member = Member(
      id: 'member_1',
      name: 'Ali',
      expenses: [archivedExpense, activeExpense],
    );
    final network = _network(member);

    await _pumpHistory(tester, network: network, member: member);

    expect(find.textContaining('4.50'), findsWidgets);
    expect(find.textContaining('50.00'), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsNothing);
  });
}

Finder findEditableText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is EditableText && widget.controller.text == text,
  );
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
  _HistoryRepository(
    this.network, {
    this.updateSucceeds = true,
  });

  ExpenseNetwork network;
  final bool updateSucceeds;
  String? editedNetworkId;
  String? editedExpenseId;
  String? editedByMemberId;
  int? editedAmountCents;
  String? editedNote;
  String? deletedNetworkId;
  String? deletedExpenseId;
  String? deletedByMemberId;

  @override
  Future<ExpenseNetwork> updateExpense({
    required String networkName,
    required String networkId,
    required String expenseId,
    required String editedByMemberId,
    required int amountCents,
    String? note,
    DateTime? createdAt,
  }) async {
    editedNetworkId = networkId;
    editedExpenseId = expenseId;
    this.editedByMemberId = editedByMemberId;
    editedAmountCents = amountCents;
    editedNote = note;
    if (!updateSucceeds) {
      throw const RepositoryException(
        'Could not update this expense. Please refresh and try again.',
        code: 'expense_update_zero_rows',
      );
    }
    final updatedMembers = network.members.map((member) {
      return member.copyWith(
        expenses: member.expenses.map((expense) {
          if (expense.id != expenseId) return expense;
          if (expense.addedByMemberId != editedByMemberId) return expense;
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
  Future<ExpenseNetwork> deleteExpense({
    required String networkName,
    required String networkId,
    required String expenseId,
    required String deletedByMemberId,
  }) async {
    deletedNetworkId = networkId;
    deletedExpenseId = expenseId;
    this.deletedByMemberId = deletedByMemberId;
    final updatedMembers = network.members.map((member) {
      return member.copyWith(
        expenses: member.expenses
            .where((expense) =>
                expense.id != expenseId ||
                expense.addedByMemberId != deletedByMemberId)
            .toList(),
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
