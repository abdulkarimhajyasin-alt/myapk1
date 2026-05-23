import 'dart:convert';

import 'package:expense_network/services/supabase_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('active session persists after repository restart', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await SupabaseSessionRepository(
      auth: _AuthFake(),
      preferences: preferences,
    ).saveActiveSession(networkName: 'Flat', memberId: 'member_1');

    final restored = await SupabaseSessionRepository(
      auth: _AuthFake(),
      preferences: preferences,
    ).getActiveSession();

    expect(restored?.networkName, 'Flat');
    expect(restored?.memberId, 'member_1');
  });

  test('local saved session survives auth metadata write failure', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await SupabaseSessionRepository(
      auth: _AuthFake(updateError: Exception('metadata failed')),
      preferences: preferences,
    ).saveActiveSession(networkName: 'Flat', memberId: 'member_1');

    final restored = await SupabaseSessionRepository(
      auth: _AuthFake(),
      preferences: preferences,
    ).getActiveSession();

    expect(restored?.networkName, 'Flat');
    expect(restored?.memberId, 'member_1');
  });

  test('clear removes only explicit active session state', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SupabaseSessionRepository(
      auth: _AuthFake(),
      preferences: preferences,
    );

    await repository.saveActiveSession(
        networkName: 'Flat', memberId: 'member_1');
    await repository.clearActiveSession();

    expect(await repository.getActiveSession(), isNull);
  });

  test('corrupt partial local session is cleared safely', () async {
    SharedPreferences.setMockInitialValues({
      'maskan_network_name': 'Flat',
    });
    final preferences = await SharedPreferences.getInstance();

    final restored = await SupabaseSessionRepository(
      auth: _AuthFake(),
      preferences: preferences,
    ).getActiveSession();

    expect(restored, isNull);
    expect(preferences.getString('maskan_network_name'), isNull);
    expect(preferences.getString('maskan_member_id'), isNull);
  });

  test('auth metadata is migrated into local durable storage', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final restored = await SupabaseSessionRepository(
      auth: _AuthFake(
        metadata: const {
          'maskan_network_name': 'Flat',
          'maskan_member_id': 'member_1',
        },
      ),
      preferences: preferences,
    ).getActiveSession();

    expect(restored?.networkName, 'Flat');
    expect(preferences.getString('maskan_network_name'), 'Flat');
    expect(preferences.getString('maskan_member_id'), 'member_1');
  });

  test('saving with member password creates authenticated Supabase session',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final auth = _AuthFake();

    await SupabaseSessionRepository(
      auth: auth,
      preferences: preferences,
    ).saveActiveSession(
      networkName: 'Flat',
      memberId: 'member_1',
      memberPassword: 'secret',
    );

    expect(auth.signInEmail, 'maskan-member_1@auth.maskan.app');
    expect(auth.signUpEmail, 'maskan-member_1@auth.maskan.app');
    expect(auth.currentSession, isNotNull);
    expect(auth.metadata['maskan_member_id'], 'member_1');
    expect(auth.refreshed, isTrue);
  });

  test('saving with member password fails if auth metadata cannot refresh',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final auth = _AuthFake(updateError: Exception('metadata failed'));

    expect(
      () => SupabaseSessionRepository(
        auth: auth,
        preferences: preferences,
      ).saveActiveSession(
        networkName: 'Flat',
        memberId: 'member_1',
        memberPassword: 'secret',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('restoring account session refreshes existing Supabase auth metadata',
      () async {
    SharedPreferences.setMockInitialValues({
      'maskan_network_name': 'Flat',
      'maskan_member_id': 'member_1',
    });
    final preferences = await SharedPreferences.getInstance();
    final auth = _AuthFake(
      metadata: const {'maskan_member_id': 'other'},
      currentSession: _SessionFake.forMetadata(const {
        'maskan_member_id': 'other',
      }),
    );

    final state = await SupabaseSessionRepository(
      auth: auth,
      preferences: preferences,
    ).restoreAuthenticatedSession();

    expect(state.accountSessionExists, isTrue);
    expect(state.supabaseSessionExists, isTrue);
    expect(state.currentUserExists, isTrue);
    expect(state.authRestored, isTrue);
    expect(state.memberId, 'member_1');
    expect(auth.metadata['maskan_member_id'], 'member_1');
    expect(auth.refreshed, isTrue);
  });
}

class _AuthFake {
  _AuthFake({
    this.metadata = const {},
    this.updateError,
    this.currentSession,
  });

  Map<String, dynamic> metadata;
  final Object? updateError;
  Object? currentSession;
  String? signInEmail;
  String? signUpEmail;
  bool refreshed = false;

  _UserFake? get currentUser => _UserFake(metadata);

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInEmail = email;
    throw Exception('missing auth user');
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    signUpEmail = email;
    currentSession = _SessionFake.forMetadata(metadata);
  }

  Future<void> updateUser(dynamic attributes) async {
    final error = updateError;
    if (error != null) throw error;
    final data = attributes.data as Map<String, dynamic>;
    metadata = {...metadata, ...data};
  }

  Future<void> refreshSession() async {
    refreshed = true;
    currentSession = _SessionFake.forMetadata(metadata);
  }
}

class _UserFake {
  const _UserFake(this.userMetadata);

  final Map<String, dynamic> userMetadata;

  String get id => 'auth-user-id';
}

class _SessionFake {
  const _SessionFake(this.accessToken);

  factory _SessionFake.forMetadata(Map<String, dynamic> metadata) {
    final payload = base64Url.encode(
      '{"user_metadata":{"maskan_member_id":"${metadata['maskan_member_id'] ?? ''}"}}'
          .codeUnits,
    );
    return _SessionFake('header.$payload.signature');
  }

  final String accessToken;
}
