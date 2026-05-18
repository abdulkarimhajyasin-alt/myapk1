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

class SessionRestorationService {
  const SessionRestorationService({
    required ExpenseNetworkRepository repository,
    required SessionRepository sessionRepository,
  })  : _repository = repository,
        _sessionRepository = sessionRepository;

  final ExpenseNetworkRepository _repository;
  final SessionRepository _sessionRepository;

  Future<RestoredSession?> restore() async {
    final session = await _sessionRepository.getActiveSession();
    if (session == null) return null;

    try {
      final network = await _repository.findNetwork(session.networkName);
      final member = network?.findMemberById(session.memberId);
      if (network == null || member == null) {
        await _sessionRepository.clearActiveSession();
        return null;
      }
      return RestoredSession(network: network, memberId: member.id);
    } on RepositoryException {
      return null;
    } catch (_) {
      await _sessionRepository.clearActiveSession();
      return null;
    }
  }
}
