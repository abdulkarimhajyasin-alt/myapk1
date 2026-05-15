import 'package:expense_network/models/member.dart';
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

  test('maps Supabase expense rows into domain expenses', () {
    final expense = SupabaseExpenseNetworkRepository.expenseFromRow({
      'id': 'expense-id',
      'paid_by_member_id': 'payer-id',
      'added_by_member_id': 'actor-id',
      'added_by_member_name': 'Mona',
      'amount_cents': 2500,
      'note': 'Groceries',
      'created_at': '2026-05-14T11:30:00.000Z',
    });

    expect(expense.id, 'expense-id');
    expect(expense.amountCents, 2500);
    expect(expense.note, 'Groceries');
    expect(expense.addedByMemberId, 'actor-id');
    expect(expense.addedByMemberName, 'Mona');
    expect(expense.createdAt.toUtc().year, 2026);
  });

  test('hydrates network totals by assigning expenses to paid member', () {
    final network = SupabaseExpenseNetworkRepository.networkFromRows(
      {
        'id': 'network-id',
        'name': 'Flat 12',
        'network_password_hash': 'network-hash',
        'currency_code': 'USD',
        'currency_symbol': r'$',
        'created_at': '2026-05-14T10:30:00.000Z',
      },
      [
        {
          'id': 'ali-id',
          'name': 'Ali',
          'created_at': '2026-05-14T10:31:00.000Z',
        },
        {
          'id': 'mona-id',
          'name': 'Mona',
          'created_at': '2026-05-14T10:32:00.000Z',
        },
      ],
      expenseRows: [
        {
          'id': 'expense-id',
          'paid_by_member_id': 'ali-id',
          'added_by_member_id': 'mona-id',
          'added_by_member_name': 'Mona',
          'amount_cents': 1800,
          'created_at': '2026-05-14T10:40:00.000Z',
        },
      ],
    );

    expect(network.totalExpensesCents, 1800);
    expect(network.findMemberById('ali-id')?.expenses, hasLength(1));
    expect(network.findMemberById('mona-id')?.expenses, isEmpty);
  });

  test('add expense payload includes owner, cents, and safe note data', () {
    final payload = SupabaseExpenseNetworkRepository.buildExpenseInsertPayload(
      networkId: 'network-id',
      paidByMemberId: 'payer-id',
      paidByMemberName: 'Ali',
      addedByMemberId: 'actor-id',
      addedByMemberName: 'Mona',
      amountCents: 1234,
      note: '  ${List.filled(210, 'x').join()}  ',
    );

    expect(payload['network_id'], 'network-id');
    expect(payload['paid_by_member_id'], 'payer-id');
    expect(payload['paid_by_member_name'], 'Ali');
    expect(payload['added_by_member_id'], 'actor-id');
    expect(payload['added_by_member_name'], 'Mona');
    expect(payload['amount_cents'], 1234);
    expect((payload['note'] as String).length, 200);
    expect(payload['created_at'], isA<String>());
  });

  test('notification payload excludes actor member', () {
    final payloads =
        SupabaseExpenseNetworkRepository.buildNotificationInsertPayloads(
      networkId: 'network-id',
      members: [
        Member(id: 'actor-id', name: 'Ali'),
        Member(id: 'mona-id', name: 'Mona'),
      ],
      actor: Member(id: 'actor-id', name: 'Ali'),
      expenseId: 'expense-id',
      amountCents: 1200,
      currencySymbol: r'$',
      note: 'Coffee',
    );

    expect(payloads, hasLength(1));
    expect(payloads.single['recipient_member_id'], 'mona-id');
    expect(payloads.single['actor_member_id'], 'actor-id');
    expect(payloads.single['expense_id'], 'expense-id');
    expect(payloads.single['amount_cents'], 1200);
    expect(payloads.single['currency_symbol'], r'$');
    expect(payloads.single['note_snippet'], 'Coffee');
    expect(payloads.single['is_read'], isFalse);
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

  test('maps permission denied errors to RepositoryException', () {
    final error = SupabaseExpenseNetworkRepository.mapSupabaseError(
      Exception('new row violates row-level security policy 42501'),
      fallbackCode: 'fallback',
      fallbackMessage: 'Fallback',
    );

    expect(error, isA<RepositoryException>());
    expect(error.code, 'supabase_permission_denied');
    expect(error.message, 'Cloud permission denied.');
  });

  test('maps network failures to RepositoryException', () {
    final error = SupabaseExpenseNetworkRepository.mapSupabaseError(
      Exception('SocketException: Failed host lookup'),
      duplicateCode: null,
      duplicateMessage: null,
      fallbackCode: 'fallback',
      fallbackMessage: 'Fallback message.',
    );

    expect(error.code, 'supabase_network_unavailable');
  });
}
