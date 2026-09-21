import 'package:flutter/foundation.dart';

/// API / WebSocket configuration.
///
/// DEBUG `flutter run` defaults to Railway staging.
/// RELEASE builds require an explicit `--dart-define=GARRA_API_BASE_URL=...`
/// and fail fast if missing/invalid — never ship staging by accident.
class ApiConfig {
  /// Canonical staging REST base used when no dart-define is provided (debug only).
  static const String defaultDevBaseUrl =
      'https://garra-digital-u-production.up.railway.app/api/v1';

  static const String _envBaseUrl = String.fromEnvironment(
    'GARRA_API_BASE_URL',
    defaultValue: '',
  );

  /// Resolved REST base. Release without define throws [StateError].
  static String get baseUrl {
    final fromEnv = _envBaseUrl.trim();
    if (fromEnv.isNotEmpty) {
      _assertValidApiBase(fromEnv);
      return fromEnv;
    }
    if (kReleaseMode) {
      throw StateError(
        'GARRA_API_BASE_URL is required for release builds. '
        'Pass --dart-define=GARRA_API_BASE_URL=https://<host>/api/v1',
      );
    }
    return defaultDevBaseUrl;
  }

  /// Whether this process is pointing at the default staging host.
  static bool get isStagingDefault {
    try {
      return Uri.parse(baseUrl).host == Uri.parse(defaultDevBaseUrl).host;
    } catch (_) {
      return false;
    }
  }

  /// Show discrete STAGING badge (debug / non-production hosts only).
  static bool get showStagingBadge {
    if (kReleaseMode && !_looksLikeStaging(baseUrl)) return false;
    return _looksLikeStaging(baseUrl) || kDebugMode;
  }

  static bool _looksLikeStaging(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.contains('railway.app') ||
        host.contains('staging') ||
        host == 'localhost' ||
        host == '127.0.0.1';
  }

  static void _assertValidApiBase(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty || !uri.path.contains('/api/')) {
      throw StateError('Invalid GARRA_API_BASE_URL: $url');
    }
    if (uri.scheme != 'https' && uri.host != 'localhost' && uri.host != '127.0.0.1') {
      throw StateError('GARRA_API_BASE_URL must use https (except localhost)');
    }
  }

  /// Local override helper for developers (not used by DioClient by default).
  static const String baseUrllocal = 'http://localhost:8081/api/v1';

  static String get websocketUrl => websocketUrlFrom(baseUrl);

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
    try {
      final api = Uri.parse(baseUrl);
      final ws = Uri.parse(websocketUrl);
      debugPrint('[GARRA_CONFIG] API host=${api.host}');
      debugPrint('[GARRA_CONFIG] WS host=${ws.host}');
      debugPrint('[GARRA_CONFIG] API scheme=${api.scheme} path=${api.path}');
      debugPrint('[GARRA_CONFIG] WS scheme=${ws.scheme} path=${ws.path}');
    } catch (e) {
      debugPrint('[GARRA_CONFIG][ERROR] $e');
    }
  }

  /// Validates release configuration at startup (throws if invalid).
  static void assertReleaseSafe() {
    if (!kReleaseMode) return;
    // Touching [baseUrl] enforces required define.
    final _ = baseUrl;
  }
}
