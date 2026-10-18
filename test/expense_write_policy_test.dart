import 'package:expense_network/services/expense_write_policy.dart';
import 'package:expense_network/services/repository_error_messages.dart';
import 'package:expense_network/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final payload = <String, dynamic>{
    'network_id': 'n',
    'cycle_id': 'c',
    'client_generated_id': 'op',
    'added_by_member_id': 'a',
    'paid_by_member_id': 'p',
    'amount_cents': 100,
    'note': 'fixture'
  };
  test('identical operation matches independently of names and timestamps', () {
    expect(
        matchesExpenseOperation({...payload, 'created_at': 'later'}, payload),
        isTrue);
  });
  for (final field in payload.keys) {
    test('different $field cannot be treated as an identical expense', () {
      expect(matchesExpenseOperation({...payload, field: 'different'}, payload),
          isFalse);
    });
  }
  test('a missing operation key is never deduplicated by contents', () {
    expect(
        matchesExpenseOperation({...payload, 'client_generated_id': null},
            {...payload, 'client_generated_id': null}),
        isFalse);
  });
  test('network lock conflicts retry at most twice', () async {
    var calls = 0;
    final result = await retryExpenseWrite(() async {
      calls++;
      if (calls < 3) {
        throw const PostgrestException(
            message: 'network_busy_retry', code: '40001');
      }
      return 'saved';
    });
    expect(result, 'saved');
    expect(calls, 3);
  });
  test('stale cycles and unknown transport failures are not retried', () async {
    var calls = 0;
    await expectLater(retryExpenseWrite(() async {
      calls++;
      throw const PostgrestException(
          message: 'stale_expense_cycle', code: '40001');
    }), throwsA(isA<PostgrestException>()));
    expect(calls, 1);
    calls = 0;
    await expectLater(retryExpenseWrite(() async {
      calls++;
      throw StateError('transport failure');
    }), throwsStateError);
    expect(calls, 1);
  });
  test('real conflicts and retry guidance are localized in both languages', () {
    for (final language in ['en', 'ar']) {
      final l10n = AppLocalizations(Locale(language));
      for (final code in [
        'expense_operation_conflict',
        'expense_network_busy',
        'expense_cycle_changed'
      ]) {
        final message = RepositoryErrorMessages.fromCode(l10n, code);
        expect(message, isNotNull);
        expect(message, isNot(contains('????')));
        expect(message, isNot(contains('40001')));
      }
    }
  });
}
