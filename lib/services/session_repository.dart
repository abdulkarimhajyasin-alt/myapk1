class AccountSession {
  const AccountSession({
    required this.networkName,
    required this.memberId,
  });

  final String networkName;
  final String memberId;
}

abstract class SessionRepository {
  Future<AccountSession?> getActiveSession();

  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
  });

  Future<void> clearActiveSession();
}
