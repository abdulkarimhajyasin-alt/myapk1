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
  });
}
