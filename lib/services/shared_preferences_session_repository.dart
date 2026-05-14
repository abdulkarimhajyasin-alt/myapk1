import 'package:shared_preferences/shared_preferences.dart';

import 'session_repository.dart';
import 'shared_preferences_storage_keys.dart';

class SharedPreferencesSessionRepository implements SessionRepository {
  SharedPreferencesSessionRepository(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<AccountSession?> getActiveSession() async {
    final networkName = _preferences.getString(
      SharedPreferencesStorageKeys.activeNetworkName,
    );
    final memberId = _preferences.getString(
      SharedPreferencesStorageKeys.activeMemberId,
    );
    if (networkName == null ||
        networkName.trim().isEmpty ||
        memberId == null ||
        memberId.trim().isEmpty) {
      return null;
    }
    return AccountSession(networkName: networkName, memberId: memberId);
  }

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
  }) async {
    await _preferences.setString(
      SharedPreferencesStorageKeys.activeNetworkName,
      networkName,
    );
    await _preferences.setString(
      SharedPreferencesStorageKeys.activeMemberId,
      memberId,
    );
  }

  @override
  Future<void> clearActiveSession() async {
    await _preferences.remove(SharedPreferencesStorageKeys.activeNetworkName);
    await _preferences.remove(SharedPreferencesStorageKeys.activeMemberId);
  }
}
