import 'package:flutter/foundation.dart';

/// API / WebSocket configuration.
///
/// Default development (`flutter run`) targets current Railway staging.
/// Production (or alternate hosts) can override:
/// `--dart-define=GARRA_API_BASE_URL=https://<host>/api/v1`
class ApiConfig {
  /// Canonical staging REST base used when no dart-define is provided.
  static const String defaultDevBaseUrl =
      'https://garra-digital-u-production.up.railway.app/api/v1';

  static const String baseUrl = String.fromEnvironment(
    'GARRA_API_BASE_URL',
    defaultValue: defaultDevBaseUrl,
  );

  /// Local override helper for developers (not used by DioClient by default).
  static const String baseUrllocal = 'http://localhost:8081/api/v1';

  /// STOMP endpoint derived from REST base (…/api/v1 → …/ws).
  /// https → wss, http → ws.
  static String get websocketUrl => websocketUrlFrom(baseUrl);

  /// Pure derivation for tests and callers that inject a base URL.
  static String websocketUrlFrom(String apiBaseUrl) {
    final rest = Uri.parse(apiBaseUrl);
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

  /// Debug-only boot log: host/scheme/path only — never tokens.
  static void logDebugConfig() {
    if (!kDebugMode) return;
    final api = Uri.parse(baseUrl);
    final ws = Uri.parse(websocketUrl);
    debugPrint('[GARRA_CONFIG] API host=${api.host}');
    debugPrint('[GARRA_CONFIG] WS host=${ws.host}');
    debugPrint('[GARRA_CONFIG] API scheme=${api.scheme} path=${api.path}');
    debugPrint('[GARRA_CONFIG] WS scheme=${ws.scheme} path=${ws.path}');
  }
}
