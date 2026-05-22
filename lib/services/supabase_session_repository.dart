import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_repository.dart';

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository({
    required dynamic auth,
    SharedPreferences? preferences,
  })  : _auth = auth,
        _preferences = preferences;

  SupabaseSessionRepository.active({SharedPreferences? preferences})
      : _auth = Supabase.instance.client.auth,
        _preferences = preferences;

  static const _networkNameKey = 'maskan_network_name';
  static const _memberIdKey = 'maskan_member_id';

  final dynamic _auth;
  final SharedPreferences? _preferences;

  @override
  Future<AccountSession?> getActiveSession() async {
    final localSession = await _localSession();
    if (localSession != null) return localSession;

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
    final session = AccountSession(
      networkName: networkName.trim(),
      memberId: memberId.trim(),
    );
    await _saveLocalSession(session);
    return session;
  }

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
  }) async {
    final session = AccountSession(
      networkName: networkName.trim(),
      memberId: memberId.trim(),
    );
    if (session.networkName.isEmpty || session.memberId.isEmpty) {
      await clearActiveSession();
      return;
    }
    await _saveLocalSession(session);
    await _trySaveAuthMetadata(session);
  }

  @override
  Future<void> clearActiveSession() async {
    await _preferences?.remove(_networkNameKey);
    await _preferences?.remove(_memberIdKey);
    if (_auth.currentSession == null) return;
    try {
      await _auth.updateUser(
        UserAttributes(
          data: {
            _networkNameKey: null,
            _memberIdKey: null,
          },
        ),
      );
    } catch (error) {
      developer.log(
        'active session auth metadata clear failed: $error',
        name: 'maskan.session',
      );
    }
  }

  Future<void> _ensureAuthSession() async {
    if (_auth.currentSession != null) return;
    await _auth.signInAnonymously();
  }

  Future<AccountSession?> _localSession() async {
    final preferences = _preferences;
    if (preferences == null) return null;
    final networkName = preferences.getString(_networkNameKey)?.trim();
    final memberId = preferences.getString(_memberIdKey)?.trim();
    if (networkName == null ||
        networkName.isEmpty ||
        memberId == null ||
        memberId.isEmpty) {
      if (preferences.containsKey(_networkNameKey) ||
          preferences.containsKey(_memberIdKey)) {
        await preferences.remove(_networkNameKey);
        await preferences.remove(_memberIdKey);
      }
      return null;
    }
    return AccountSession(networkName: networkName, memberId: memberId);
  }

  Future<void> _saveLocalSession(AccountSession session) async {
    final preferences = _preferences;
    if (preferences == null) return;
    await preferences.setString(_networkNameKey, session.networkName);
    await preferences.setString(_memberIdKey, session.memberId);
  }

  Future<void> _trySaveAuthMetadata(AccountSession session) async {
    try {
      await _ensureAuthSession();
      await _auth.updateUser(
        UserAttributes(
          data: {
            _networkNameKey: session.networkName,
            _memberIdKey: session.memberId,
          },
        ),
      );
    } catch (error) {
      developer.log(
        'active session auth metadata save failed: $error',
        name: 'maskan.session',
      );
    }
  }
}
