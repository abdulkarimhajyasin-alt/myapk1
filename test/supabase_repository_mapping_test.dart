import 'package:expense_network/services/expense_network_repository.dart';
import 'package:expense_network/services/supabase_expense_network_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps Supabase network and member rows into domain models', () {
    final network = SupabaseExpenseNetworkRepository.networkFromRows(
      {
        'id': 'network-id',
        'name': 'Flat 12',
        'network_password_hash': 'network-hash',
        'currency_code': 'EUR',
        'currency_symbol': '€',
        'created_at': '2026-05-14T10:30:00.000Z',
      },
      [
        {
          'id': 'member-id',
          'name': 'Ali',
          'password_hash': 'member-hash',
          'password_salt': 'member-salt',
          'created_at': '2026-05-14T10:31:00.000Z',
        },
      ],
    );

    expect(network.id, 'network-id');
    expect(network.name, 'Flat 12');
    expect(network.password, 'network-hash');
    expect(network.currencyCode, 'EUR');
    expect(network.currencySymbol, '€');
    expect(network.members.single.id, 'member-id');
    expect(network.members.single.passwordHash, 'member-hash');
    expect(network.members.single.passwordSalt, 'member-salt');
  });

  test('normalizes names for cloud uniqueness', () {
    expect(
      SupabaseExpenseNetworkRepository.normalizeName('  My   Home  '),
      'my home',
    );
  });

  test('maps duplicate network errors to RepositoryException', () {
    final error = SupabaseExpenseNetworkRepository.mapSupabaseError(
      Exception('duplicate key value violates unique constraint 23505'),
      duplicateCode: 'duplicate_network',
      duplicateMessage: 'A network with this name already exists.',
      fallbackCode: 'fallback',
      fallbackMessage: 'Fallback',
    );

    expect(error, isA<RepositoryException>());
    expect(error.code, 'duplicate_network');
  });

  test('maps duplicate member errors to RepositoryException', () {
    final error = SupabaseExpenseNetworkRepository.mapSupabaseError(
      Exception('duplicate key value violates unique constraint 23505'),
      duplicateCode: 'duplicate_member',
      duplicateMessage: 'This member name is already used in the network.',
      fallbackCode: 'fallback',
      fallbackMessage: 'Fallback',
    );

    expect(error.code, 'duplicate_member');
  });
}
