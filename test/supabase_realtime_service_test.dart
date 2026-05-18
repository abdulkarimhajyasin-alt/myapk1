import 'package:expense_network/services/supabase_config.dart';
import 'package:expense_network/services/supabase_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('realtime service waits for Supabase configuration', () {
    final service = SupabaseRealtimeService();

    expect(service.canInitialize, isFalse);
  });

  test('realtime service can initialize when Supabase is configured', () {
    final service = SupabaseRealtimeService(
      config: const SupabaseConfig(
        url: 'https://example.supabase.co',
        anonKey: 'anon',
      ),
    );

    expect(service.canInitialize, isTrue);
  });

  test('dispose is safe without active subscriptions', () async {
    final service = SupabaseRealtimeService();

    await service.dispose();
  });

  test('realtime events trigger refresh callbacks after debounce', () async {
    var refreshCount = 0;
    final service = SupabaseRealtimeService(
      debounceDuration: const Duration(milliseconds: 1),
    );

    service.handleEventForTesting(() => refreshCount++);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(refreshCount, 1);
    await service.dispose();
  });
}
