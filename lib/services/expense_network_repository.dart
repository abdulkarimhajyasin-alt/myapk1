import '../models/expense_network.dart';
import '../models/member.dart';
import '../models/network_notification.dart';

class AccountSession {
  const AccountSession({
    required this.networkName,
    required this.memberId,
  });

  final String networkName;
  final String memberId;
}

abstract class ExpenseNetworkRepository {
  Future<List<ExpenseNetwork>> getNetworks();
  Future<ExpenseNetwork?> findNetwork(String networkName);
  Future<Member?> findMember({
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
  Future<AccountSession?> getActiveSession();
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
  });
  Future<void> clearActiveSession();
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
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
