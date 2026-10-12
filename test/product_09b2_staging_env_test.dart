import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/config/api_config.dart';

/// PRODUCT-09B.2: STAGING badge driven by GARRA_ENV, independent of the API host.
void main() {
  const official = 'https://api.garradigital.pe/api/v1';
  const railway = 'https://garra-digital-u-production.up.railway.app/api/v1';

  test('release + official host + GARRA_ENV=staging shows badge', () {
    expect(ApiConfig.stagingBadgeFor(apiBaseUrl: official, envName: 'staging', releaseMode: true, debugMode: false), isTrue);
    expect(ApiConfig.stagingBadgeFor(apiBaseUrl: official, envName: ' STAGING ', releaseMode: true, debugMode: false), isTrue);
  });

  test('release + official host without GARRA_ENV hides badge (production behaviour unchanged)', () {
    expect(ApiConfig.stagingBadgeFor(apiBaseUrl: official, envName: '', releaseMode: true, debugMode: false), isFalse);
    expect(ApiConfig.stagingBadgeFor(apiBaseUrl: official, envName: 'production', releaseMode: true, debugMode: false), isFalse);
  });

  test('legacy host heuristics unchanged', () {
    expect(ApiConfig.stagingBadgeFor(apiBaseUrl: railway, envName: '', releaseMode: true, debugMode: false), isTrue);
    expect(ApiConfig.stagingBadgeFor(apiBaseUrl: official, envName: '', releaseMode: false, debugMode: true), isTrue);
  });

  test('official host derives wss://api.garradigital.pe/ws', () {
    expect(ApiConfig.websocketUrlFrom(official), 'wss://api.garradigital.pe/ws');
  });
}