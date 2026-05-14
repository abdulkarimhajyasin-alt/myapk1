import 'package:expense_network/services/repository_factory.dart';
import 'package:expense_network/services/shared_preferences_expense_network_repository.dart';
import 'package:expense_network/services/shared_preferences_session_repository.dart';
import 'package:expense_network/services/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('SupabaseConfig detects missing credentials', () {
    const config = SupabaseConfig(url: '', anonKey: '');

    expect(config.isConfigured, isFalse);
  });

  test('SupabaseConfig detects configured credentials', () {
    const config = SupabaseConfig(
      url: 'https://example.supabase.co',
      anonKey: 'public-anon-key',
    );

    expect(config.isConfigured, isTrue);
  });

  test('local repositories remain default when Supabase is not configured',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final repositories = await RepositoryFactory.create(
      preferences: preferences,
      supabaseConfig: const SupabaseConfig(url: '', anonKey: ''),
    );

    expect(
      repositories.expenseNetworkRepository,
      isA<SharedPreferencesExpenseNetworkRepository>(),
    );
    expect(
      repositories.sessionRepository,
      isA<SharedPreferencesSessionRepository>(),
    );
  });

  test('local repositories remain default during Phase 2 when configured',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final repositories = await RepositoryFactory.create(
      preferences: preferences,
      supabaseConfig: const SupabaseConfig(
        url: 'https://example.supabase.co',
        anonKey: 'public-anon-key',
      ),
    );

    expect(
      repositories.expenseNetworkRepository,
      isA<SharedPreferencesExpenseNetworkRepository>(),
    );
  });
}
