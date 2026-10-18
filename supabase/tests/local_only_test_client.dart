import 'package:http/http.dart' as http;

/// Test-only HTTP transport. Rejects every origin except its explicit loopback API.
class LocalOnlyTestClient extends http.BaseClient {
  LocalOnlyTestClient(String apiUrl, {http.Client? inner})
      : endpoint = Uri.parse(apiUrl),
        _inner = inner ?? http.Client() {
    if (endpoint.userInfo.isNotEmpty ||
        endpoint.scheme != 'http' ||
        !['127.0.0.1', 'localhost'].contains(endpoint.host) ||
        ![54321, 55321, 56321].contains(endpoint.port)) {
      throw StateError('Only an isolated loopback test API is allowed.');
    }
  }
  final Uri endpoint;
  final http.Client _inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.userInfo.isNotEmpty ||
        request.url.origin != endpoint.origin) {
      throw StateError('External test traffic is forbidden.');
    }
    request.followRedirects = false;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
