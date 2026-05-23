import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_repository.dart';
import 'supabase_config.dart';

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
  Future<AccountSessionAuthState> restoreAuthenticatedSession() async {
    final accountSession = await getActiveSession();
    if (accountSession == null) {
      return _authState(null, authRestored: false);
    }

    var authRestored = false;
    if (_auth.currentSession != null && _auth.currentUser != null) {
      try {
        await _writeAuthMetadataAndRefresh(accountSession);
        final jwtMemberId = _jwtMetadataMemberId(_auth.currentSession);
        authRestored = _auth.currentSession != null &&
            _auth.currentUser != null &&
            jwtMemberId == accountSession.memberId;
      } catch (error) {
        developer.log(
          'active session auth restore failed: $error',
          name: 'maskan.session',
        );
      }
    }

    final state = _authState(accountSession, authRestored: authRestored);
    _logAuthState(state);
    return state;
  }

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
    String? memberPassword,
    String? networkId,
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
    if (memberPassword != null && memberPassword.trim().isNotEmpty) {
      await _ensureSupabaseAuthSession(
        session,
        memberPassword,
        networkId: networkId,
      );
    } else {
      await _trySaveAuthMetadata(session);
    }
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
    if (_auth.currentSession == null || _auth.currentUser == null) return;
    try {
      await _writeAuthMetadataAndRefresh(session);
    } catch (error) {
      developer.log(
        'active session auth metadata save failed: $error',
        name: 'maskan.session',
      );
    }
  }

  Future<void> _ensureSupabaseAuthSession(
    AccountSession session,
    String memberPassword, {
    String? networkId,
  }) async {
    final email = _authEmailFor(session.memberId);
    final password = _authPasswordFor(session.memberId, memberPassword);
    var authMethod = 'signInWithPassword';
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } catch (error, stackTrace) {
      _logAuthRestoreError(
        networkId: networkId,
        memberId: session.memberId,
        email: email,
        authMethod: authMethod,
        error: error,
        stackTrace: stackTrace,
      );
      authMethod = 'signUp';
      try {
        await _auth.signUp(email: email, password: password);
      } catch (signUpError, signUpStackTrace) {
        _logAuthRestoreError(
          networkId: networkId,
          memberId: session.memberId,
          email: email,
          authMethod: authMethod,
          error: signUpError,
          stackTrace: signUpStackTrace,
        );
        rethrow;
      }
    }
    await _writeAuthMetadataAndRefresh(session);
    final jwtMemberId = _jwtMetadataMemberId(_auth.currentSession);
    final success = _auth.currentSession != null &&
        _auth.currentUser != null &&
        jwtMemberId == session.memberId;
    debugPrint(
      'maskan.accountAuth.restore '
      'networkId=${networkId ?? '<unknown>'} '
      'memberId=${session.memberId} '
      'passwordProvided=true '
      'sessionExists=${_auth.currentSession != null} '
      'currentUserExists=${_auth.currentUser != null} '
      'jwtMemberId=${jwtMemberId ?? '<none>'} '
      'success=$success '
      'failureReason=${success ? '<none>' : 'jwt_or_session_missing'}',
    );
    if (!success) {
      throw StateError('Supabase Auth session was not restored.');
    }
  }

  void _logAuthRestoreError({
    required String? networkId,
    required String memberId,
    required String email,
    required String authMethod,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final authException = error is AuthException ? error : null;
    final endpoint = switch (authMethod) {
      'signInWithPassword' =>
        '${SupabaseConfig.defaultConfig.url}/auth/v1/token?grant_type=password',
      'signUp' => '${SupabaseConfig.defaultConfig.url}/auth/v1/signup',
      _ => '${SupabaseConfig.defaultConfig.url}/auth/v1',
    };
    debugPrint(
      'maskan.auth.restore.error '
      'networkId=${networkId ?? '<unknown>'} '
      'memberId=$memberId '
      'authEmail=$email '
      'signInMethod=$authMethod '
      'supabaseUrl=${SupabaseConfig.defaultConfig.url} '
      'endpoint=$endpoint '
      'exceptionType=${error.runtimeType} '
      'statusCode=${authException?.statusCode ?? '<none>'} '
      'errorCode=${authException?.code ?? '<none>'} '
      'message=${authException?.message ?? error.toString()} '
      'rawResponse=${error.toString()} '
      'stack=$stackTrace',
    );
  }

  Future<void> _writeAuthMetadataAndRefresh(AccountSession session) async {
    if (_auth.currentSession == null || _auth.currentUser == null) {
      throw StateError('Supabase Auth session is missing.');
    }
    await _auth.updateUser(
      UserAttributes(
        data: {
          _networkNameKey: session.networkName,
          _memberIdKey: session.memberId,
        },
      ),
    );
    await _auth.refreshSession();
  }

  AccountSessionAuthState _authState(
    AccountSession? accountSession, {
    required bool authRestored,
  }) {
    return AccountSessionAuthState(
      accountSession: accountSession,
      accountSessionExists: accountSession != null,
      supabaseSessionExists: _auth.currentSession != null,
      currentUserExists: _auth.currentUser != null,
      authRestored: authRestored,
      memberId: accountSession?.memberId,
      jwtMemberId: _jwtMetadataMemberId(_auth.currentSession),
    );
  }

  void _logAuthState(AccountSessionAuthState state) {
    developer.log(
      'accountSessionExists=${state.accountSessionExists} '
      'supabaseSessionExists=${state.supabaseSessionExists} '
      'currentUserExists=${state.currentUserExists} '
      'authRestored=${state.authRestored} memberId=${state.memberId ?? '<none>'}',
      name: 'maskan.session',
    );
  }

  static String _authEmailFor(String memberId) {
    final safeMemberId = memberId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'maskan-$safeMemberId@auth.maskan.app'.toLowerCase();
  }

  static String _authPasswordFor(String memberId, String memberPassword) {
    return 'Maskan:$memberId:${memberPassword.trim()}:SupabaseAuth';
  }

  static String? _jwtMetadataMemberId(dynamic session) {
    final String? accessToken;
    try {
      accessToken = session?.accessToken as String?;
    } catch (_) {
      return null;
    }
    if (accessToken == null) return null;
    final parts = accessToken.split('.');
    if (parts.length < 2) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final metadata = data['user_metadata'] as Map<String, dynamic>?;
      return metadata?[_memberIdKey] as String?;
    } catch (_) {
      return null;
    }
  }
}
