import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../supabase/tests/local_only_test_client.dart';

void main() {
  test('HTTP test client rejects production and unauthorized targets', () {
    for (final target in [
      'https://skngodvomygvxemfaefn.supabase.co',
      'http://example.invalid:56321',
      'http://127.0.0.1:54322',
      'http://user:password@127.0.0.1:56321'
    ]) {
      expect(() => LocalOnlyTestClient(target), throwsStateError);
    }
  });
  test('external requests fail before the underlying HTTP transport', () {
    var calls = 0;
    final client = LocalOnlyTestClient('http://127.0.0.1:56321',
        inner: MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    }));
    expect(
        () => client.send(http.Request(
            'POST',
            Uri.parse(
                'https://skngodvomygvxemfaefn.supabase.co/rest/v1/expenses'))),
        throwsStateError);
    expect(calls, 0);
    client.close();
  });
  test('local requests cannot follow an external redirect', () async {
    final client = LocalOnlyTestClient('http://127.0.0.1:56321',
        inner: MockClient((request) async {
      expect(request.followRedirects, isFalse);
      return http.Response('{}', 200);
    }));
    expect(
        (await client.get(Uri.parse('http://127.0.0.1:56321/auth/v1/health')))
            .statusCode,
        200);
    client.close();
  });
}
