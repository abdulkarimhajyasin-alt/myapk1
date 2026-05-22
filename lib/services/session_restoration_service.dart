import '../models/expense_network.dart';
import 'expense_network_repository.dart';
import 'session_repository.dart';

class RestoredSession {
  const RestoredSession({
    required this.network,
    required this.memberId,
  });

  final ExpenseNetwork network;
  final String memberId;
}

enum SessionRestorationStatus {
  noSavedSession,
  restored,
  staleSessionCleared,
  unavailable,
}

class SessionRestorationResult {
  const SessionRestorationResult._({
    required this.status,
    this.restoredSession,
  });

  const SessionRestorationResult.noSavedSession()
      : this._(status: SessionRestorationStatus.noSavedSession);

  const SessionRestorationResult.restored(RestoredSession restoredSession)
      : this._(
          status: SessionRestorationStatus.restored,
          restoredSession: restoredSession,
        );

  const SessionRestorationResult.staleSessionCleared()
      : this._(status: SessionRestorationStatus.staleSessionCleared);

  const SessionRestorationResult.unavailable()
      : this._(status: SessionRestorationStatus.unavailable);

  final SessionRestorationStatus status;
  final RestoredSession? restoredSession;
}

class SessionRestorationService {
  const SessionRestorationService({
    required ExpenseNetworkRepository repository,
    required SessionRepository sessionRepository,
  })  : _repository = repository,
        _sessionRepository = sessionRepository;

  final ExpenseNetworkRepository _repository;
  final SessionRepository _sessionRepository;

  Future<RestoredSession?> restore() async {
    return (await restoreWithStatus()).restoredSession;
  }

  Future<SessionRestorationResult> restoreWithStatus() async {
    final session = await _sessionRepository.getActiveSession();
    if (session == null) return const SessionRestorationResult.noSavedSession();

    try {
      final network = await _repository.findNetwork(session.networkName);
      final member = network?.findMemberById(session.memberId);
      if (network == null || member == null) {
        await _sessionRepository.clearActiveSession();
        return const SessionRestorationResult.staleSessionCleared();
      }
      return SessionRestorationResult.restored(
        RestoredSession(network: network, memberId: member.id),
      );
    } on RepositoryException catch (error) {
      if (_isStaleSessionError(error)) {
        await _sessionRepository.clearActiveSession();
        return const SessionRestorationResult.staleSessionCleared();
      }
      return const SessionRestorationResult.unavailable();
    } catch (_) {
      await _sessionRepository.clearActiveSession();
      return const SessionRestorationResult.staleSessionCleared();
    }
  }

  bool _isStaleSessionError(RepositoryException error) {
    return switch (error.code) {
      'supabase_not_found' || 'network_not_found' || 'member_not_found' => true,
      _ => false,
    };
  }
}
