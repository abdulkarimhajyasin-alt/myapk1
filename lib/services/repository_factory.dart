import 'package:shared_preferences/shared_preferences.dart';

import 'expense_network_repository.dart';
import 'session_repository.dart';
import 'shared_preferences_expense_network_repository.dart';
import 'shared_preferences_session_repository.dart';
import 'supabase_config.dart';

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

  static Future<AppRepositoryBundle> create({
    required SharedPreferences preferences,
    SupabaseConfig supabaseConfig = SupabaseConfig.defaultConfig,
  }) async {
    if (supabaseConfig.isConfigured) {
      // Phase 2 initializes Supabase only. Runtime data remains local until the
      // Supabase repository is implemented and selected in a later phase.
      return _createLocal(preferences);
    }

    return _createLocal(preferences);
  }

  static Future<AppRepositoryBundle> _createLocal(
    SharedPreferences preferences,
  ) async {
    final expenseNetworkRepository = SharedPreferencesExpenseNetworkRepository();
    await expenseNetworkRepository.init();

    return AppRepositoryBundle(
      expenseNetworkRepository: expenseNetworkRepository,
      sessionRepository: SharedPreferencesSessionRepository(preferences),
    );
  }
}
