import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_repository.dart';

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository({required dynamic auth}) : _auth = auth;

  SupabaseSessionRepository.active() : _auth = Supabase.instance.client.auth;

  static const _networkNameKey = 'maskan_network_name';
  static const _memberIdKey = 'maskan_member_id';

  final dynamic _auth;

  @override
  Future<AccountSession?> getActiveSession() async {
    final user = _auth.currentUser;
    final metadata = user?.userMetadata;
    final networkName = metadata?[_networkNameKey] as String?;
    final memberId = metadata?[_memberIdKey] as String?;
    if (networkName == null ||
        networkName.trim().isEmpty ||
        memberId == null ||
        memberId.trim().isEmpty) {
      return null;
    }
    return AccountSession(
      networkName: networkName.trim(),
      memberId: memberId.trim(),
    );
  }

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
  }) async {
    await _ensureAuthSession();
    await _auth.updateUser(
      UserAttributes(
        data: {
          _networkNameKey: networkName.trim(),
          _memberIdKey: memberId.trim(),
        },
      ),
    );
  }

  @override
  Future<void> clearActiveSession() async {
    if (_auth.currentSession == null) return;
    await _auth.updateUser(
      UserAttributes(
        data: {
          _networkNameKey: null,
          _memberIdKey: null,
        },
      ),
    );
  }

  Future<void> _ensureAuthSession() async {
    if (_auth.currentSession != null) return;
    await _auth.signInAnonymously();
  }
}
