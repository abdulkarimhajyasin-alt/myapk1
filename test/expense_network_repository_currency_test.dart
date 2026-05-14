import 'package:expense_network/services/shared_preferences_expense_network_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists selected currency inside created network', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesExpenseNetworkRepository();
    await repository.init();

    final network = await repository.createNetwork(
      displayName: 'Ali',
      networkName: 'Trip',
      password: 'secret',
      currencyCode: 'SAR',
    );
    final storedNetwork = await repository.findNetwork('Trip');

    expect(network.currencyCode, 'SAR');
    expect(network.currencySymbol, 'ر.س');
    expect(storedNetwork?.currencyCode, 'SAR');
    expect(storedNetwork?.currencySymbol, 'ر.س');
  });
}
