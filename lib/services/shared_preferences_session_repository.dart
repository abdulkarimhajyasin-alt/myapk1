import 'package:shared_preferences/shared_preferences.dart';

import 'session_repository.dart';
import 'shared_preferences_storage_keys.dart';

class SharedPreferencesSessionRepository implements SessionRepository {
  SharedPreferencesSessionRepository(
    this._preferences, {
    String dataMode = 'local',
  }) : _dataMode = dataMode.trim().toLowerCase();

  final SharedPreferences _preferences;
  final String _dataMode;

  @override
  Future<AccountSession?> getActiveSession() async {
    final networkName = _preferences.getString(
      SharedPreferencesStorageKeys.activeNetworkName,
    );
    final memberId = _preferences.getString(
      SharedPreferencesStorageKeys.activeMemberId,
    );
    final dataMode = _preferences.getString(
      SharedPreferencesStorageKeys.activeDataMode,
    );
    if (networkName == null ||
        networkName.trim().isEmpty ||
        memberId == null ||
        memberId.trim().isEmpty) {
      return null;
    }
    return AccountSession(
      networkName: networkName,
      memberId: memberId,
      dataMode: dataMode,
    );
  }

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
    String? dataMode,
  }) async {
    await _preferences.setString(
      SharedPreferencesStorageKeys.activeNetworkName,
      networkName,
    );
    await _preferences.setString(
      SharedPreferencesStorageKeys.activeMemberId,
      memberId,
    );
    await _preferences.setString(
      SharedPreferencesStorageKeys.activeDataMode,
      (dataMode ?? _dataMode).trim().toLowerCase(),
    );
  }

  @override
  Future<void> clearActiveSession() async {
    await _preferences.remove(SharedPreferencesStorageKeys.activeNetworkName);
    await _preferences.remove(SharedPreferencesStorageKeys.activeMemberId);
    await _preferences.remove(SharedPreferencesStorageKeys.activeDataMode);
  }
}
