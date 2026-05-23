class AccountSession {
  const AccountSession({
    required this.networkName,
    required this.memberId,
  });

  final String networkName;
  final String memberId;
}

class AccountSessionAuthState {
  const AccountSessionAuthState({
    required this.accountSession,
    required this.accountSessionExists,
    required this.supabaseSessionExists,
    required this.currentUserExists,
    required this.authRestored,
    this.memberId,
    this.jwtMemberId,
  });

  final AccountSession? accountSession;
  final bool accountSessionExists;
  final bool supabaseSessionExists;
  final bool currentUserExists;
  final bool authRestored;
  final String? memberId;
  final String? jwtMemberId;
}

abstract class SessionRepository {
  Future<AccountSession?> getActiveSession();

  Future<AccountSessionAuthState> restoreAuthenticatedSession();

  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
    String? memberPassword,
    String? networkId,
  });

  Future<void> clearActiveSession();
}
