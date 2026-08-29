import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.code);

  final String code;

  @override
  String toString() => code;
}

abstract class AccountDeletionService {
  Future<void> deleteAccount({
    required String memberPassword,
    required bool confirmNetworkDeletion,
  });
}

class SupabaseAccountDeletionService implements AccountDeletionService {
  SupabaseAccountDeletionService({
    required SupabaseClient client,
  }) : _client = client;

  SupabaseAccountDeletionService.active() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> deleteAccount({
    required String memberPassword,
    required bool confirmNetworkDeletion,
  }) async {
    if (memberPassword.trim().isEmpty) {
      throw const AccountDeletionException('invalid_credentials');
    }

    final FunctionResponse result;
    try {
      result = await _client.functions.invoke(
        'maskan-delete-account',
        body: {
          'memberPassword': memberPassword,
          'confirmNetworkDeletion': confirmNetworkDeletion,
        },
      );
    } on FunctionException catch (error) {
      final details = error.details is Map
          ? Map<String, dynamic>.from(error.details as Map)
          : const <String, dynamic>{};
      throw AccountDeletionException(
        details['code'] as String? ?? 'operation_failed',
      );
    }
    final data = result.data is Map
        ? Map<String, dynamic>.from(result.data as Map)
        : const <String, dynamic>{};
    if (result.status < 200 || result.status >= 300 || data['ok'] != true) {
      throw AccountDeletionException(
        data['code'] as String? ?? 'operation_failed',
      );
    }

    // The server has removed the Auth user. Clear its cached refresh/access
    // tokens locally without making another network request.
    await _client.auth.signOut(scope: SignOutScope.local);
  }
}
