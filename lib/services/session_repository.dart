class AccountSession {
  const AccountSession({
    required this.networkName,
    required this.memberId,
    this.dataMode,
  });

  final String networkName;
  final String memberId;
  final String? dataMode;
}

abstract class SessionRepository {
  Future<AccountSession?> getActiveSession();

  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
    String? dataMode,
  });

  Future<void> clearActiveSession();
}
