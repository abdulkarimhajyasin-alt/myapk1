import 'package:supabase_flutter/supabase_flutter.dart';

/// Retries only a transaction that the server explicitly rolled back.
Future<T> retryExpenseWrite<T>(Future<T> Function() write) async {
  for (var attempt = 0;; attempt++) {
    try {
      return await write();
    } on PostgrestException catch (error) {
      if (attempt >= 2 ||
          error.code != '40001' ||
          error.message != 'network_busy_retry') {
        rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
    }
  }
}

bool matchesExpenseOperation(
    Map<String, dynamic> existing, Map<String, dynamic> attempted) {
  const fields = [
    'network_id',
    'cycle_id',
    'client_generated_id',
    'added_by_member_id',
    'paid_by_member_id',
    'amount_cents',
    'note'
  ];
  return attempted['client_generated_id'] != null &&
      fields.every((field) => existing[field] == attempted[field]);
}
