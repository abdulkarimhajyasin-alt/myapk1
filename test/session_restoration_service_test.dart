import 'package:expense_network/services/session_restoration_service.dart';
import 'package:expense_network/services/shared_preferences_expense_network_repository.dart';
import 'package:expense_network/services/shared_preferences_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('restores dashboard session when saved network and member are valid',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();
    final sessionRepository = SharedPreferencesSessionRepository(preferences);

    final network = await repository.createNetwork(
      displayName: 'Ali',
      networkName: 'Trip',
      password: 'network',
      memberPassword: '1234',
      currencyCode: 'USD',
    );
    final member = network.members.single;
    await sessionRepository.saveActiveSession(
      networkName: network.name,
      memberId: member.id,
      dataMode: 'local',
    );

    final restored = await SessionRestorationService(
      repository: repository,
      sessionRepository: sessionRepository,
      currentDataMode: 'local',
    ).restore();

    expect(restored?.network.name, 'Trip');
    expect(restored?.memberId, member.id);
  });

  test('invalid saved session falls back and clears stale session', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();
    final sessionRepository = SharedPreferencesSessionRepository(preferences);

    await sessionRepository.saveActiveSession(
      networkName: 'Missing',
      memberId: 'member_missing',
      dataMode: 'local',
    );

    final restored = await SessionRestorationService(
      repository: repository,
      sessionRepository: sessionRepository,
      currentDataMode: 'local',
    ).restore();

    expect(restored, isNull);
    expect(await sessionRepository.getActiveSession(), isNull);
  });

  test('different saved data mode does not restore into current mode', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();
    final sessionRepository = SharedPreferencesSessionRepository(preferences);

    final network = await repository.createNetwork(
      displayName: 'Ali',
      networkName: 'Trip',
      password: 'network',
      memberPassword: '1234',
      currencyCode: 'USD',
    );
    await sessionRepository.saveActiveSession(
      networkName: network.name,
      memberId: network.members.single.id,
      dataMode: 'supabase',
    );

    final restored = await SessionRestorationService(
      repository: repository,
      sessionRepository: sessionRepository,
      currentDataMode: 'local',
    ).restore();

    expect(restored, isNull);
    expect((await sessionRepository.getActiveSession())?.dataMode, 'supabase');
  });

  test('legacy saved session without data mode can still restore', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();
    final sessionRepository = SharedPreferencesSessionRepository(preferences);

    final network = await repository.createNetwork(
      displayName: 'Ali',
      networkName: 'Trip',
      password: 'network',
      memberPassword: '1234',
      currencyCode: 'USD',
    );
    await preferences.setString('active_network_name', network.name);
    await preferences.setString('active_member_id', network.members.single.id);

    final restored = await SessionRestorationService(
      repository: repository,
      sessionRepository: sessionRepository,
      currentDataMode: 'local',
    ).restore();

    expect(restored?.network.name, 'Trip');
    expect(restored?.memberId, network.members.single.id);
  });
}
