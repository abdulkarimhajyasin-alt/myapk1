import 'package:supabase_flutter/supabase_flutter.dart';

/// Stable bridge between a Maskan member and its Supabase Auth identity.
///
/// The database remains authoritative through `network_members.auth_user_id`;
/// these deterministic credentials only preserve the existing sign-in UX.
abstract final class SupabaseAuthIdentity {
  static String emailFor(String memberId) {
    final safeMemberId = memberId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'maskan-$safeMemberId@auth.maskan.app'.toLowerCase();
  }

  static String passwordFor(String memberId, String memberPassword) {
    return 'Maskan:$memberId:${memberPassword.trim()}:SupabaseAuth';
  }

  static Future<void> establish({
    required SupabaseClient client,
    required String memberId,
    required String memberPassword,
    required String networkName,
  }) async {
    final email = emailFor(memberId);
    final password = passwordFor(memberId, memberPassword);
    try {
      await client.auth.signInWithPassword(email: email, password: password);
    } on AuthException {
      await client.auth.signUp(email: email, password: password);
    }
    if (client.auth.currentSession == null || client.auth.currentUser == null) {
      throw const AuthException(
        'Supabase Auth did not issue a session. Disable email confirmation for the app-managed member flow.',
      );
    }
    await client.auth.updateUser(
      UserAttributes(
        data: {
          'maskan_network_name': networkName,
          'maskan_member_id': memberId,
        },
      ),
    );
    await client.auth.refreshSession();
  }
}
