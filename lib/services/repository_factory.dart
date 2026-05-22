import 'package:shared_preferences/shared_preferences.dart';

import 'expense_network_repository.dart';
import 'session_repository.dart';
import 'supabase_expense_network_repository.dart';
import 'supabase_session_repository.dart';

class AppRepositoryBundle {
  const AppRepositoryBundle({
    required this.expenseNetworkRepository,
    required this.sessionRepository,
  });

  final ExpenseNetworkRepository expenseNetworkRepository;
  final SessionRepository sessionRepository;
}

class RepositoryFactory {
  const RepositoryFactory._();

  static AppRepositoryBundle create({
    ExpenseNetworkRepository? supabaseRepository,
    SessionRepository? sessionRepository,
    SharedPreferences? preferences,
  }) {
    return AppRepositoryBundle(
      expenseNetworkRepository:
          supabaseRepository ?? SupabaseExpenseNetworkRepository.active(),
      sessionRepository: sessionRepository ??
          SupabaseSessionRepository.active(preferences: preferences),
    );
  }
}
