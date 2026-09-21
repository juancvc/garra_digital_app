/// API / WebSocket configuration.
///
/// Staging / release builds should pass:
/// `--dart-define=GARRA_API_BASE_URL=https://<staging-or-prod-host>/api/v1`
///
/// Default keeps current hosted URL for local/dev continuity (override for staging).
class ApiConfig {
  static const String _defaultBaseUrl =
      'https://humorous-forgiveness-production-4439.up.railway.app/api/v1';

  static const String baseUrl = String.fromEnvironment(
    'GARRA_API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  /// Local override helper for developers (not used by DioClient by default).
  static const String baseUrllocal = 'http://localhost:8081/api/v1';

  /// STOMP endpoint derived from REST base (…/api/v1 → …/ws).
  /// https → wss, http → ws.
  static String get websocketUrl {
    final rest = Uri.parse(baseUrl);
    if (rest.host.isEmpty) {
      throw StateError('GARRA_API_BASE_URL host is empty');
    }
    final scheme = rest.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: rest.host,
      port: rest.hasPort ? rest.port : null,
      path: '/ws',
    ).toString();
  }
}
