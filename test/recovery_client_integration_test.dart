import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class RecoveryReadClient extends http.BaseClient {
  final http.Client inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final url = request.url;
    if (url.origin != 'http://127.0.0.1:57321' ||
        url.userInfo.isNotEmpty ||
        request.method != 'GET' ||
        !url.path.startsWith('/rest/v1/')) {
      throw StateError('Only read-only isolated recovery REST is allowed');
    }
    final mapped = http.Request(
        'GET', url.replace(path: url.path.substring('/rest/v1'.length)))
      ..headers.addAll(request.headers)
      ..followRedirects = false;
    return inner.send(mapped);
  }

  @override
  void close() => inner.close();
}

void main() {
  final env = Platform.environment;
  test('Flutter client reconnects to restored synthetic database with RLS',
      () async {
    expect(env['MASKAN_RECOVERY_URL'], 'http://127.0.0.1:57321');
    for (var connection = 0; connection < 2; connection++) {
      final client = SupabaseClient(
          env['MASKAN_RECOVERY_URL']!, 'synthetic-recovery-key',
          headers: {'Authorization': 'Bearer ${env['MASKAN_RECOVERY_TOKEN']}'},
          httpClient: RecoveryReadClient(),
          authOptions: const AuthClientOptions(autoRefreshToken: false));
      try {
        final rows = await client
            .from('expenses')
            .select('id')
            .eq('network_id', env['MASKAN_RECOVERY_NETWORK']!);
        expect(rows.length, int.parse(env['MASKAN_RECOVERY_EXPENSES']!));
        final other = await client
            .from('expenses')
            .select('id')
            .neq('network_id', env['MASKAN_RECOVERY_NETWORK']!);
        expect(other, isEmpty);
      } finally {
        await client.dispose();
      }
    }
  },
      skip: env['MASKAN_RECOVERY_URL'] == null
          ? 'Run guarded recovery validation separately'
          : false);
}
