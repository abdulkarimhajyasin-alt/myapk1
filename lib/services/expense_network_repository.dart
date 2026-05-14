import '../models/expense_network.dart';

abstract class ExpenseNetworkRepository {
  Future<List<ExpenseNetwork>> getNetworks();
  Future<ExpenseNetwork?> findNetwork(String networkName);
  Future<ExpenseNetwork> createNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String currencyCode,
  });
  Future<ExpenseNetwork> joinNetwork({
    required String displayName,
    required String networkName,
    required String password,
  });
  Future<ExpenseNetwork> addExpense({
    required String networkName,
    required String memberName,
    required int amountCents,
    String? note,
  });
}

class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
