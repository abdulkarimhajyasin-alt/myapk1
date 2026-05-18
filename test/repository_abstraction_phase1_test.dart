import 'package:expense_network/models/expense.dart';
import 'package:expense_network/models/member.dart';
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
    expect(
      SharedPreferencesStorageKeys.offlineSyncQueue,
      'offline_sync_queue_v1',
    );
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

  test('leave network is blocked while total expenses are not zero', () async {
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
    await repository.saveNetwork(
      network.copyWith(
        members: [
          network.members.first.copyWith(
            expenses: [
              Expense(amountCents: 1000, createdAt: DateTime(2026)),
            ],
          ),
        ],
      ),
    );

    expect(
      () => repository.leaveNetwork(
        networkId: network.id,
        memberId: network.members.first.id,
      ),
      throwsA(
        isA<RepositoryException>()
            .having((error) => error.code, 'code', 'leave_unsettled_expenses'),
      ),
    );
  });

  test('leave network removes only the leaving member when total is zero',
      () async {
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
    final mona = Member(name: 'Mona');
    await repository.saveNetwork(network.addMember(mona));

    await repository.leaveNetwork(
      networkId: network.id,
      memberId: network.members.first.id,
    );

    final updated = await repository.findNetwork('Trip');
    expect(updated, isNotNull);
    expect(updated!.members, hasLength(1));
    expect(updated.members.single.name, 'Mona');
  });

  test('leave network removes empty single-member local network', () async {
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

    await repository.leaveNetwork(
      networkId: network.id,
      memberId: network.members.first.id,
    );

    expect(await repository.findNetwork('Trip'), isNull);
  });
}
