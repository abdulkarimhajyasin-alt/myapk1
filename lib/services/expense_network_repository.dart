import '../models/expense_network.dart';
import '../models/member.dart';
import '../models/network_notification.dart';

/// UI-facing persistence contract.
///
/// Supabase and local repositories should both implement this interface so UI
/// code does not know whether data is local or remote. Session and language
/// preferences intentionally live outside this contract.
abstract class ExpenseNetworkRepository {
  Future<List<ExpenseNetwork>> getNetworks();

  Future<ExpenseNetwork?> findNetwork(String networkName);

  Future<Member?> findMember({
    required String networkName,
    required String memberId,
  });

  Future<Member?> getMemberHistory({
    required String networkName,
    required String memberId,
  });

  Future<ExpenseNetwork> createNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
    required String currencyCode,
  });

  Future<ExpenseNetwork> joinNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
  });

  Future<void> saveNetwork(ExpenseNetwork network);

  Future<ExpenseNetwork> authenticateMember({
    required String networkName,
    required String memberName,
    required String memberPassword,
  });

  Future<ExpenseNetwork> addExpense({
    required String networkName,
    required String memberName,
    required String addedByMemberId,
    required int amountCents,
    String? note,
  });

  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  });

  Future<void> markNotificationRead(String notificationId);

  Future<void> markAllNotificationsRead({
    required String networkId,
    required String memberId,
  });
}

class RepositoryException implements Exception {
  const RepositoryException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
