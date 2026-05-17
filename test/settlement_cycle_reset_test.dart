import 'package:expense_network/models/expense.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/services/shared_preferences_expense_network_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reset request auto-approves requester and waits for all members',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();

    final created = await repository.createNetwork(
      displayName: 'Ali',
      networkName: 'Flat',
      password: 'network',
      memberPassword: '1234',
      currencyCode: 'USD',
    );
    final joined = await repository.joinNetwork(
      displayName: 'Mona',
      networkName: 'Flat',
      password: 'network',
      memberPassword: '5678',
    );
    final ali = created.members.single;
    final mona = joined.findMemberByName('Mona')!;
    await repository.addExpense(
      networkName: 'Flat',
      memberName: 'Ali',
      addedByMemberId: ali.id,
      amountCents: 2000,
    );

    final requested = await repository.createResetRequest(
      networkName: 'Flat',
      requestedByMemberId: ali.id,
    );
    final request = requested.activeResetRequest!;

    expect(request.approvals.single.memberId, ali.id);
    expect(request.pendingMemberNames, ['Mona']);
    expect(requested.totalExpensesCents, 2000);

    final monaNotifications = await repository.getNotifications(
      networkId: requested.id,
      memberId: mona.id,
    );
    expect(
      monaNotifications.any(
        (notification) =>
            notification.kind == NetworkNotificationKind.resetRequest,
      ),
      isTrue,
    );
  });

  test('expenses are archived only after unanimous reset approval', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();

    final created = await repository.createNetwork(
      displayName: 'Ali',
      networkName: 'Flat',
      password: 'network',
      memberPassword: '1234',
      currencyCode: 'USD',
    );
    final joined = await repository.joinNetwork(
      displayName: 'Mona',
      networkName: 'Flat',
      password: 'network',
      memberPassword: '5678',
    );
    final ali = created.members.single;
    final mona = joined.findMemberByName('Mona')!;
    await repository.addExpense(
      networkName: 'Flat',
      memberName: 'Ali',
      addedByMemberId: ali.id,
      amountCents: 2000,
    );
    final requested = await repository.createResetRequest(
      networkName: 'Flat',
      requestedByMemberId: ali.id,
    );

    final completed = await repository.approveResetRequest(
      networkName: 'Flat',
      resetRequestId: requested.activeResetRequest!.id,
      memberId: mona.id,
    );

    expect(completed.activeResetRequest, isNull);
    expect(completed.totalExpensesCents, 0);
    expect(completed.activeCycle.cycleNumber, 2);
    final history = await repository.getMemberHistory(
      networkName: 'Flat',
      memberId: ali.id,
    );
    expect(history?.expenses.single.isArchived, isTrue);

    final aliNotifications = await repository.getNotifications(
      networkId: completed.id,
      memberId: ali.id,
    );
    expect(
      aliNotifications.any(
        (notification) =>
            notification.kind == NetworkNotificationKind.cycleStarted,
      ),
      isTrue,
    );
  });

  test('old local expenses without cycle metadata still count as active', () {
    final network = ExpenseNetwork(
      name: 'Legacy',
      password: 'network',
      createdAt: DateTime(2026),
      members: [
        Member(
          name: 'Ali',
          expenses: [
            Expense(amountCents: 1500, createdAt: DateTime(2026)),
          ],
        ),
      ],
    );

    final legacyJson = network.toJson()..remove('cycles');
    final decoded = ExpenseNetwork.fromJson(legacyJson);

    expect(decoded.activeCycle.cycleNumber, 1);
    expect(decoded.totalExpensesCents, 1500);
    expect(decoded.members.single.expenses.single.cycleId, isNull);
  });
}
