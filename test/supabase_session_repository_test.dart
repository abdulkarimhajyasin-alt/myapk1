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

    await repository.saveActiveSession(networkName: 'Flat', memberId: 'member_1');
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
}

class _AuthFake {
  _AuthFake({this.metadata = const {}, this.updateError});

  Map<String, dynamic> metadata;
  final Object? updateError;
  Object? currentSession;

  _UserFake? get currentUser => _UserFake(metadata);

  Future<void> signInAnonymously() async {
    currentSession = Object();
  }

  Future<void> updateUser(dynamic attributes) async {
    final error = updateError;
    if (error != null) throw error;
    final data = attributes.data as Map<String, dynamic>;
    metadata = {...metadata, ...data};
  }
}

class _UserFake {
  const _UserFake(this.userMetadata);

  final Map<String, dynamic> userMetadata;
}
