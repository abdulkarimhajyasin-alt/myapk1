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

  test('old member and expense JSON loads safely', () {
    final network = ExpenseNetwork.fromJson({
      'name': 'Old Trip',
      'password': 'secret',
      'members': [
        {
          'name': 'Ali',
          'expenses': [
            {
              'amountCents': 1000,
              'note': 'Tea',
              'createdAt': DateTime(2026).toIso8601String(),
            }
          ],
        }
      ],
      'createdAt': DateTime(2026).toIso8601String(),
    });

    final member = network.members.single;
    final expense = member.expenses.single;
    expect(member.id, isNotEmpty);
    expect(member.hasPassword, isFalse);
    expect(expense.id, isNotEmpty);
    expect(expense.addedByMemberId, '');
    expect(expense.addedByMemberName, '');
  });

  test('member history can filter expenses by member', () {
    final network = ExpenseNetwork.fromJson({
      'name': 'Trip',
      'password': 'secret',
      'members': [
        {
          'name': 'Ali',
          'expenses': [
            {
              'amountCents': 1000,
              'createdAt': DateTime(2026).toIso8601String(),
            }
          ],
        },
        {
          'name': 'Mona',
          'expenses': [],
        }
      ],
      'createdAt': DateTime(2026).toIso8601String(),
    });

    expect(network.findMemberByName('Ali')?.expenses, hasLength(1));
    expect(network.findMemberByName('Mona')?.expenses, isEmpty);
  });
}
