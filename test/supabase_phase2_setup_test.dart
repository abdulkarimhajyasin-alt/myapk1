import 'package:expense_network/services/repository_factory.dart';
import 'package:expense_network/services/shared_preferences_expense_network_repository.dart';
import 'package:expense_network/services/shared_preferences_session_repository.dart';
import 'package:expense_network/services/supabase_config.dart';
import 'package:expense_network/services/supabase_expense_network_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('DATA_MODE defaults to local', () {
    const config = SupabaseConfig();

    expect(config.dataMode, 'local');
    expect(config.wantsSupabase, isFalse);
    expect(config.shouldUseSupabase, isFalse);
  });

  test('SupabaseConfig detects missing credentials', () {
    const config = SupabaseConfig(url: '', anonKey: '');

    expect(config.isConfigured, isFalse);
  });

  test('SupabaseConfig detects configured credentials', () {
    const config = SupabaseConfig(
      url: 'https://example.supabase.co',
      anonKey: 'public-anon-key',
      dataMode: 'supabase',
    );

    expect(config.isConfigured, isTrue);
    expect(config.shouldUseSupabase, isTrue);
  });

  test('Supabase mode requires both URL and anon key', () {
    const missingUrl = SupabaseConfig(
      url: '',
      anonKey: 'public-anon-key',
      dataMode: 'supabase',
    );
    const missingKey = SupabaseConfig(
      url: 'https://example.supabase.co',
      anonKey: '',
      dataMode: 'supabase',
    );

    expect(missingUrl.shouldUseSupabase, isFalse);
    expect(missingKey.shouldUseSupabase, isFalse);
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
        dataMode: 'local',
      ),
    );

    expect(
      repositories.expenseNetworkRepository,
      isA<SharedPreferencesExpenseNetworkRepository>(),
    );
  });

  test('Supabase repository is selected only when mode and config allow it',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    const supabaseRepository = SupabaseExpenseNetworkRepository.test();

    final repositories = await RepositoryFactory.create(
      preferences: preferences,
      supabaseConfig: const SupabaseConfig(
        url: 'https://example.supabase.co',
        anonKey: 'public-anon-key',
        dataMode: 'supabase',
      ),
      supabaseRepository: supabaseRepository,
    );

    expect(repositories.expenseNetworkRepository, same(supabaseRepository));
  });

  test('missing Supabase config falls back to local even in Supabase mode',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final repositories = await RepositoryFactory.create(
      preferences: preferences,
      supabaseConfig: const SupabaseConfig(dataMode: 'supabase'),
      supabaseRepository: const SupabaseExpenseNetworkRepository.test(),
    );

    expect(
      repositories.expenseNetworkRepository,
      isA<SharedPreferencesExpenseNetworkRepository>(),
    );
  });
}
