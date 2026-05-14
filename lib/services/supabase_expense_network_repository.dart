import '../models/expense_network.dart';
import '../models/member.dart';
import '../models/network_notification.dart';
import 'expense_network_repository.dart';

/// Future Supabase-backed implementation of [ExpenseNetworkRepository].
///
/// This class is intentionally dormant in Phase 2. The app still selects the
/// SharedPreferences repository by default so existing local behavior is not
/// changed while the remote schema and client setup are prepared.
class SupabaseExpenseNetworkRepository implements ExpenseNetworkRepository {
  const SupabaseExpenseNetworkRepository();

  Future<T> _notEnabled<T>() async {
    throw const RepositoryException(
      'Supabase repository is not enabled yet.',
      code: 'supabase_not_enabled',
    );
  }

  @override
  Future<ExpenseNetwork> addExpense({
    required String networkName,
    required String memberName,
    required String addedByMemberId,
    required int amountCents,
    String? note,
  }) {
    return _notEnabled();
  }

  @override
  Future<ExpenseNetwork> authenticateMember({
    required String networkName,
    required String memberName,
    required String memberPassword,
  }) {
    return _notEnabled();
  }

  @override
  Future<ExpenseNetwork> createNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
    required String currencyCode,
  }) {
    return _notEnabled();
  }

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) {
    return _notEnabled();
  }

  @override
  Future<Member?> findMember({
    required String networkName,
    required String memberId,
  }) {
    return _notEnabled();
  }

  @override
  Future<Member?> getMemberHistory({
    required String networkName,
    required String memberId,
  }) {
    return _notEnabled();
  }

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) {
    return _notEnabled();
  }

  @override
  Future<List<ExpenseNetwork>> getNetworks() {
    return _notEnabled();
  }

  @override
  Future<ExpenseNetwork> joinNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
  }) {
    return _notEnabled();
  }

  @override
  Future<void> markAllNotificationsRead({
    required String networkId,
    required String memberId,
  }) {
    return _notEnabled();
  }

  @override
  Future<void> markNotificationRead(String notificationId) {
    return _notEnabled();
  }

  @override
  Future<void> saveNetwork(ExpenseNetwork network) {
    return _notEnabled();
  }
}
