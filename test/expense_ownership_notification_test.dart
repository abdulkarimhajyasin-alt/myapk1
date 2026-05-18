import 'package:expense_network/services/shared_preferences_expense_network_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('expense stores owner metadata, note, and creates notifications',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();

    final created = await repository.createNetwork(
      displayName: 'Ali',
      networkName: 'Trip',
      password: 'network',
      memberPassword: '1234',
      currencyCode: 'USD',
    );
    final joined = await repository.joinNetwork(
      displayName: 'Mona',
      networkName: 'Trip',
      password: 'network',
      memberPassword: '5678',
    );
    final ali = created.members.single;
    final mona = joined.findMemberByName('Mona')!;

    final updated = await repository.addExpense(
      networkName: 'Trip',
      memberName: 'Ali',
      addedByMemberId: ali.id,
      amountCents: 1200,
      note: 'Coffee',
    );

    final expense = updated.findMemberByName('Ali')!.expenses.single;
    expect(expense.addedByMemberId, ali.id);
    expect(expense.addedByMemberName, 'Ali');
    expect(expense.note, 'Coffee');
    expect(expense.createdAt, isNotNull);

    final aliNotifications = await repository.getNotifications(
      networkId: updated.id,
      memberId: ali.id,
    );
    final monaNotifications = await repository.getNotifications(
      networkId: updated.id,
      memberId: mona.id,
    );

    expect(aliNotifications, isEmpty);
    expect(monaNotifications, hasLength(1));
    expect(monaNotifications.single.actorMemberName, 'Ali');
    expect(monaNotifications.single.noteSnippet, 'Coffee');

    final history = await repository.getMemberHistory(
      networkName: 'Trip',
      memberId: ali.id,
    );
    expect(history?.expenses, hasLength(1));

    await repository.deleteNotification(monaNotifications.single.id);
    final readNotifications = await repository.getNotifications(
      networkId: updated.id,
      memberId: mona.id,
    );
    expect(readNotifications, isEmpty);
  });

  test('clear notifications removes current member notifications only',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();

    final created = await repository.createNetwork(
      displayName: 'Ali',
      networkName: 'Trip',
      password: 'network',
      memberPassword: '1234',
      currencyCode: 'USD',
    );
    final joinedMona = await repository.joinNetwork(
      displayName: 'Mona',
      networkName: 'Trip',
      password: 'network',
      memberPassword: '5678',
    );
    final joinedSara = await repository.joinNetwork(
      displayName: 'Sara',
      networkName: 'Trip',
      password: 'network',
      memberPassword: '9012',
    );
    final ali = created.members.single;
    final mona = joinedMona.findMemberByName('Mona')!;
    final sara = joinedSara.findMemberByName('Sara')!;

    final updated = await repository.addExpense(
      networkName: 'Trip',
      memberName: 'Ali',
      addedByMemberId: ali.id,
      amountCents: 1200,
      note: 'Coffee',
    );

    expect(
      await repository.getNotifications(
        networkId: updated.id,
        memberId: mona.id,
      ),
      hasLength(1),
    );
    expect(
      await repository.getNotifications(
        networkId: updated.id,
        memberId: sara.id,
      ),
      hasLength(1),
    );

    await repository.clearNotificationsForMember(
      networkId: updated.id,
      memberId: mona.id,
    );

    expect(
      await repository.getNotifications(
        networkId: updated.id,
        memberId: mona.id,
      ),
      isEmpty,
    );
    expect(
      await repository.getNotifications(
        networkId: updated.id,
        memberId: sara.id,
      ),
      hasLength(1),
    );
  });
}
