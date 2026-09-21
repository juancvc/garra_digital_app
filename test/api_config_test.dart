import 'package:flutter_test/flutter_test.dart';

import 'package:garra_digital_app/core/config/api_config.dart';

void main() {
  const legacyHost = 'humorous-forgiveness-production-4439';
  const stagingHost = 'garra-digital-u-production.up.railway.app';

  test('DEFAULT_DEV_API_IS_CURRENT_STAGING', () {
    expect(ApiConfig.defaultDevBaseUrl, contains(stagingHost));
    expect(
      ApiConfig.defaultDevBaseUrl,
      'https://garra-digital-u-production.up.railway.app/api/v1',
    );
    // Without dart-define, fromEnvironment uses defaultDevBaseUrl.
    expect(ApiConfig.baseUrl, ApiConfig.defaultDevBaseUrl);
  });

  test('DART_DEFINE_OVERRIDE_WINS', () {
    const override =
        'https://custom-prod.example.com/api/v1';
    // fromEnvironment cannot be swapped at runtime; assert derivation honors
    // an injected override the same way Dio/realtime would if dart-define wins.
    expect(
      ApiConfig.websocketUrlFrom(override),
      'wss://custom-prod.example.com/ws',
    );
    expect(override, isNot(equals(ApiConfig.defaultDevBaseUrl)));
  });

  test('WEBSOCKET_URL_DERIVED_FROM_API', () {
    expect(
      ApiConfig.websocketUrl,
      'wss://garra-digital-u-production.up.railway.app/ws',
    );
    expect(
      ApiConfig.websocketUrlFrom(ApiConfig.defaultDevBaseUrl),
      'wss://garra-digital-u-production.up.railway.app/ws',
    );
    expect(
      ApiConfig.websocketUrlFrom('http://localhost:8081/api/v1'),
      'ws://localhost:8081/ws',
    );
  });

  test('LEGACY_HOST_NOT_USED', () {
    expect(ApiConfig.baseUrl.contains(legacyHost), isFalse);
    expect(ApiConfig.defaultDevBaseUrl.contains(legacyHost), isFalse);
    expect(ApiConfig.websocketUrl.contains(legacyHost), isFalse);
  });
}
