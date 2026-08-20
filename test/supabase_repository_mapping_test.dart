import 'package:expense_network/models/expense.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/models/network_notification.dart';
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
        'created_by_member_id': 'member-id',
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
          'avatar_color': '#059669',
          'avatar_initials': 'AL',
          'avatar_image_path': 'network/member.jpg',
          'avatar_image_url': 'https://example.com/member.jpg',
          'created_at': '2026-05-14T10:31:00.000Z',
        },
      ],
    );

    expect(network.id, 'network-id');
    expect(network.name, 'Flat 12');
    expect(network.password, isEmpty);
    expect(network.createdByMemberId, 'member-id');
    expect(network.currencyCode, 'EUR');
    expect(network.currencySymbol, '€');
    expect(network.members.single.id, 'member-id');
    expect(network.members.single.passwordHash, isNull);
    expect(network.members.single.passwordSalt, isNull);
    expect(network.members.single.avatarColor, '#059669');
    expect(network.members.single.avatarInitials, 'AL');
    expect(network.members.single.avatarImagePath, 'network/member.jpg');
    expect(
      network.members.single.avatarImageUrl,
      'https://example.com/member.jpg',
    );
  });

  test('normalizes names for cloud uniqueness', () {
    expect(
      SupabaseExpenseNetworkRepository.normalizeName('  My   Home  '),
      'my home',
    );
  });

  test('generates Postgres-compatible UUIDs for create inserts', () {
    final id = SupabaseExpenseNetworkRepository.createUuid();

    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
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
      'client_generated_id': 'client_1',
      'created_at': '2026-05-14T11:30:00.000Z',
    });

    expect(expense.id, 'expense-id');
    expect(expense.amountCents, 2500);
    expect(expense.note, 'Groceries');
    expect(expense.addedByMemberId, 'actor-id');
    expect(expense.addedByMemberName, 'Mona');
    expect(expense.createdAt.toUtc().year, 2026);
    expect(expense.clientGeneratedId, 'client_1');
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
          'cycle_id': 'cycle-id',
          'paid_by_member_id': 'ali-id',
          'added_by_member_id': 'mona-id',
          'added_by_member_name': 'Mona',
          'amount_cents': 1800,
          'created_at': '2026-05-14T10:40:00.000Z',
        },
      ],
      cycleRows: [
        {
          'id': 'cycle-id',
          'network_id': 'network-id',
          'cycle_number': 1,
          'status': 'active',
          'started_at': '2026-05-14T10:30:00.000Z',
        },
      ],
    );

    expect(network.totalExpensesCents, 1800);
    expect(network.activeCycle.id, 'cycle-id');
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
      clientGeneratedId: 'client_1',
    );

    expect(payload['network_id'], 'network-id');
    expect(payload['paid_by_member_id'], 'payer-id');
    expect(payload['paid_by_member_name'], 'Ali');
    expect(payload['added_by_member_id'], 'actor-id');
    expect(payload['added_by_member_name'], 'Mona');
    expect(payload['amount_cents'], 1234);
    expect(payload['cycle_id'], isNull);
    expect(payload['client_generated_id'], 'client_1');
    expect((payload['note'] as String).length, 200);
    expect(payload['created_at'], isA<String>());
  });

  test('update expense payload includes editable fields only', () {
    final payload = SupabaseExpenseNetworkRepository.buildExpenseUpdatePayload(
      amountCents: 1550,
      note: '  Updated  ',
      createdAt: DateTime.utc(2026, 5, 22, 10, 30),
    );

    expect(payload['amount_cents'], 1550);
    expect(payload['note'], 'Updated');
    expect(payload['created_at'], '2026-05-22T10:30:00.000Z');
    expect(payload, isNot(contains('added_by_member_id')));
  });

  test('maps archived Supabase expenses without counting active totals', () {
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
      ],
      expenseRows: [
        {
          'id': 'expense-id',
          'paid_by_member_id': 'ali-id',
          'amount_cents': 1800,
          'created_at': '2026-05-14T10:40:00.000Z',
          'archived_at': '2026-05-15T10:40:00.000Z',
        },
      ],
    );

    expect(network.totalExpensesCents, 0);
    expect(network.members.single.expenses.single.isArchived, isTrue);
  });

  test('leave is blocked only by current active totals', () {
    final activeNetwork = ExpenseNetwork(
      id: 'network-id',
      name: 'Flat 12',
      password: 'network-hash',
      createdAt: DateTime(2026),
      members: [
        Member(
          id: 'ali-id',
          name: 'Ali',
          expenses: [
            Expense(amountCents: 1800, createdAt: DateTime(2026)),
          ],
        ),
      ],
    );
    final archivedNetwork = activeNetwork.copyWith(
      members: [
        Member(
          id: 'ali-id',
          name: 'Ali',
          expenses: [
            Expense(
              amountCents: 1800,
              createdAt: DateTime(2026),
              archivedAt: DateTime(2026, 2),
            ),
          ],
        ),
      ],
    );

    expect(
      SupabaseExpenseNetworkRepository.canMemberLeaveNetwork(activeNetwork),
      isFalse,
    );
    expect(
      SupabaseExpenseNetworkRepository.canMemberLeaveNetwork(
        activeNetwork.copyWith(
          members: [
            Member(
              id: 'ali-id',
              name: 'Ali',
              expenses: [
                Expense(amountCents: 0, createdAt: DateTime(2026)),
              ],
            ),
          ],
        ),
      ),
      isTrue,
    );
    expect(
      SupabaseExpenseNetworkRepository.canMemberLeaveNetwork(archivedNetwork),
      isTrue,
    );
  });

  test('last member leave deletes the whole settled network', () {
    final network = ExpenseNetwork(
      id: 'network-id',
      name: 'Flat 12',
      password: 'network-hash',
      createdAt: DateTime(2026),
      members: [
        Member(id: 'ali-id', name: 'Ali'),
      ],
    );

    expect(
      SupabaseExpenseNetworkRepository.shouldDeleteNetworkAfterLeave(
        network,
        'ali-id',
      ),
      isTrue,
    );
    expect(
      SupabaseExpenseNetworkRepository.shouldDeleteNetworkAfterLeave(
        network.copyWith(
          members: [
            Member(id: 'ali-id', name: 'Ali'),
            Member(id: 'mona-id', name: 'Mona'),
          ],
        ),
        'ali-id',
      ),
      isFalse,
    );
  });

  test('maps Supabase reset requests and approvals', () {
    final request = SupabaseExpenseNetworkRepository.resetRequestFromRows(
      {
        'id': 'reset-id',
        'network_id': 'network-id',
        'cycle_id': 'cycle-id',
        'requested_by_member_id': 'ali-id',
        'requested_by_member_name': 'Ali',
        'status': 'pending',
        'required_member_ids': ['ali-id', 'mona-id'],
        'required_member_names': ['Ali', 'Mona'],
        'created_at': '2026-05-14T10:40:00.000Z',
      },
      [
        {
          'member_id': 'ali-id',
          'member_name': 'Ali',
          'approved_at': '2026-05-14T10:41:00.000Z',
        },
      ],
    );

    expect(request.isPending, isTrue);
    expect(request.approvals.single.memberId, 'ali-id');
    expect(request.pendingMemberNames, ['Mona']);
  });

  test('maps reset requests after requester member deletion', () {
    final request = SupabaseExpenseNetworkRepository.resetRequestFromRows(
      {
        'id': 'reset-id',
        'network_id': 'network-id',
        'cycle_id': 'cycle-id',
        'requested_by_member_id': null,
        'requested_by_member_name': 'Former member',
        'status': 'completed',
        'required_member_ids': ['old-member-id'],
        'required_member_names': ['Former member'],
        'created_at': '2026-05-14T10:40:00.000Z',
      },
      const [],
    );

    expect(request.requestedByMemberId, isEmpty);
    expect(request.requestedByMemberName, 'Former member');
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

  test('expense update notification payload excludes editor member', () {
    final payloads =
        SupabaseExpenseNetworkRepository.buildNotificationInsertPayloads(
      networkId: 'network-id',
      members: [
        Member(id: 'editor-id', name: 'Ali'),
        Member(id: 'mona-id', name: 'Mona'),
        Member(id: 'sara-id', name: 'Sara'),
      ],
      actor: Member(id: 'editor-id', name: 'Ali'),
      expenseId: 'expense-id',
      amountCents: 1450,
      currencySymbol: r'$',
      note: 'Updated coffee',
      kind: NetworkNotificationKind.expenseUpdated,
    );

    expect(payloads, hasLength(2));
    expect(
      payloads.map((payload) => payload['recipient_member_id']),
      unorderedEquals(['mona-id', 'sara-id']),
    );
    expect(
      payloads.map((payload) => payload['actor_member_id']).toSet(),
      {'editor-id'},
    );
    expect(
      payloads.map((payload) => payload['kind']).toSet(),
      {NetworkNotificationKind.expenseUpdated.name},
    );
    expect(
      payloads.map((payload) => payload['is_read']).toSet(),
      {false},
    );
  });

  test('maps expense updated notification rows', () {
    final notification = SupabaseExpenseNetworkRepository.notificationFromRow({
      'id': 'notification-id',
      'network_id': 'network-id',
      'recipient_member_id': 'mona-id',
      'actor_member_name': 'Ali',
      'amount_cents': 1450,
      'currency_symbol': r'$',
      'note_snippet': 'Updated coffee',
      'kind': 'expenseUpdated',
      'reset_request_id': null,
      'created_at': '2026-05-14T10:40:00.000Z',
      'is_read': false,
    });

    expect(notification.kind, NetworkNotificationKind.expenseUpdated);
    expect(notification.recipientMemberId, 'mona-id');
    expect(notification.expenseAmountCents, 1450);
    expect(notification.isRead, isFalse);
  });

  test('maps duplicate network errors to RepositoryException', () {
    final error = SupabaseExpenseNetworkRepository.mapSupabaseError(
      Exception('duplicate key value violates unique constraint 23505'),
      duplicateCode: 'duplicate_network',
      duplicateMessage:
          'This network name is already in use. Choose another name.',
      fallbackCode: 'fallback',
      fallbackMessage: 'Fallback',
    );

    expect(error, isA<RepositoryException>());
    expect(error.code, 'duplicate_network');
    expect(
      error.message,
      'This network name is already in use. Choose another name.',
    );
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

  test('maps missing cloud rows without raw backend copy', () {
    final error = SupabaseExpenseNetworkRepository.mapSupabaseError(
      Exception(
          'PGRST116: JSON object requested, multiple or no rows returned'),
      fallbackCode: 'fallback',
      fallbackMessage: 'Fallback message.',
    );

    expect(error.code, 'supabase_not_found');
    expect(error.message, 'Saved cloud record is no longer available.');
  });

  test('create network maps missing internal rows as create failure', () {
    final error = SupabaseExpenseNetworkRepository.mapSupabaseError(
      Exception(
          'PGRST116: JSON object requested, multiple or no rows returned'),
      notFoundCode: 'supabase_create_network_failed',
      notFoundMessage: 'Cloud network could not be created.',
      fallbackCode: 'fallback',
      fallbackMessage: 'Fallback message.',
    );

    expect(error.code, 'supabase_create_network_failed');
    expect(error.message, 'Cloud network could not be created.');
  });

  test('create failures map to safe user-facing RepositoryException', () {
    final error = SupabaseExpenseNetworkRepository.mapSupabaseError(
      Exception('new row violates row-level security policy 42501'),
      duplicateCode: 'duplicate_network',
      duplicateMessage:
          'This network name is already in use. Choose another name.',
      notFoundCode: 'supabase_create_network_failed',
      notFoundMessage: 'Cloud network could not be created.',
      fallbackCode: 'supabase_create_network_failed',
      fallbackMessage: 'Cloud network could not be created.',
    );

    expect(error.code, 'supabase_permission_denied');
    expect(error.message, 'Cloud permission denied.');
  });
}
