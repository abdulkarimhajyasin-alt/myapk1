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
    String currentDataMode = 'local',
  })  : _repository = repository,
        _sessionRepository = sessionRepository,
        _currentDataMode = currentDataMode;

  final ExpenseNetworkRepository _repository;
  final SessionRepository _sessionRepository;
  final String _currentDataMode;

  Future<RestoredSession?> restore() async {
    final session = await _sessionRepository.getActiveSession();
    if (session == null) return null;
    if (session.dataMode != null &&
        session.dataMode!.trim().toLowerCase() !=
            _currentDataMode.trim().toLowerCase()) {
      return null;
    }

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
