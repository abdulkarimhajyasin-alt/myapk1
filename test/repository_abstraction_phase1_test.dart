import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/shared_preferences_expense_network_repository.dart';
import 'package:expense_network/services/shared_preferences_session_repository.dart';
import 'package:expense_network/services/shared_preferences_storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('shared preferences storage keys remain stable', () {
    expect(SharedPreferencesStorageKeys.networks, 'expense_networks_v1');
    expect(
      SharedPreferencesStorageKeys.notifications,
      'expense_network_notifications_v1',
    );
    expect(
      SharedPreferencesStorageKeys.activeNetworkName,
      'active_network_name',
    );
    expect(SharedPreferencesStorageKeys.activeMemberId, 'active_member_id');
    expect(SharedPreferencesStorageKeys.activeDataMode, 'active_data_mode');
  });

  test('session repository stores and clears active session separately', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final sessionRepository = SharedPreferencesSessionRepository(preferences);

    await sessionRepository.saveActiveSession(
      networkName: 'Trip',
      memberId: 'member_1',
    );

    final session = await sessionRepository.getActiveSession();
    expect(session?.networkName, 'Trip');
    expect(session?.memberId, 'member_1');
    expect(session?.dataMode, 'local');

    await sessionRepository.clearActiveSession();
    expect(await sessionRepository.getActiveSession(), isNull);
  });

  test('failed network load does not rewrite stored data', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesStorageKeys.networks: '{bad json',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();

    expect(
      repository.getNetworks,
      throwsA(isA<RepositoryException>()),
    );
    expect(
      preferences.getString(SharedPreferencesStorageKeys.networks),
      '{bad json',
    );
  });

  test('repository can save an updated network through abstract contract',
      () async {
    SharedPreferences.setMockInitialValues({});
    final ExpenseNetworkRepository repository =
        SharedPreferencesExpenseNetworkRepository();
    await (repository as SharedPreferencesExpenseNetworkRepository).init();

    final network = await repository.createNetwork(
      displayName: 'Ali',
      networkName: 'Trip',
      password: 'network',
      memberPassword: '1234',
      currencyCode: 'USD',
    );

    await repository.saveNetwork(network.copyWith(name: 'Trip Updated'));
    final updated = await repository.findNetwork('Trip Updated');

    expect(updated?.name, 'Trip Updated');
  });
}
