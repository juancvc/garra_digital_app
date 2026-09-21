class ApiConfig {
  static const String baseUrl =
      'https://humorous-forgiveness-production-4439.up.railway.app/api/v1';
  static const String baseUrllocal = 'http://localhost:8081/api/v1';

  /// STOMP endpoint derived from REST base (…/api/v1 → …/ws).
  static String get websocketUrl {
    final rest = Uri.parse(baseUrl);
    final scheme = rest.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: rest.host,
      port: rest.hasPort ? rest.port : null,
      path: '/ws',
    ).toString();
  }
}
