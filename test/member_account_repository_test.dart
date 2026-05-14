import 'package:expense_network/services/shared_preferences_expense_network_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('create network saves creator member password data', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();

    final network = await repository.createNetwork(
      displayName: 'Ali',
      networkName: 'Trip',
      password: 'network',
      memberPassword: '1234',
      currencyCode: 'USD',
    );

    final member = network.members.single;
    expect(member.passwordHash, isNotNull);
    expect(member.passwordSalt, isNotNull);
    expect(member.passwordHash, isNot('1234'));
  });

  test('join network saves member password data and login succeeds or fails',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();

    await repository.createNetwork(
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

    final member = joined.findMemberByName('Mona')!;
    expect(member.passwordHash, isNotNull);
    expect(member.passwordHash, isNot('5678'));

    final loggedIn = await repository.authenticateMember(
      networkName: 'Trip',
      memberName: 'Mona',
      memberPassword: '5678',
    );
    expect(loggedIn.name, 'Trip');

    expect(
      () => repository.authenticateMember(
        networkName: 'Trip',
        memberName: 'Mona',
        memberPassword: 'wrong',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
