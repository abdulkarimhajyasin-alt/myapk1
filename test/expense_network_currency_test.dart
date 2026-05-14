import 'package:expense_network/models/expense_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and deserializes selected network currency', () {
    final network = ExpenseNetwork(
      name: 'Trip',
      password: 'secret',
      members: const [],
      createdAt: DateTime(2026),
      currencyCode: 'EUR',
      currencySymbol: '€',
    );

    final decoded = ExpenseNetwork.fromJson(network.toJson());

    expect(decoded.currencyCode, 'EUR');
    expect(decoded.currencySymbol, '€');
  });

  test('old network data without currency falls back to USD', () {
    final network = ExpenseNetwork.fromJson({
      'name': 'Old Trip',
      'password': 'secret',
      'members': [],
      'createdAt': DateTime(2026).toIso8601String(),
    });

    expect(network.currencyCode, 'USD');
    expect(network.currencySymbol, r'$');
  });
}
