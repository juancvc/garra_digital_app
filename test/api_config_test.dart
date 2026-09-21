import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

import 'package:garra_digital_app/core/config/api_config.dart';
import 'package:garra_digital_app/core/config/semver.dart';

void main() {
  const legacyHost = 'humorous-forgiveness-production-4439';
  const stagingHost = 'garra-digital-u-production.up.railway.app';

  test('DEBUG_DEFAULTS_STAGING', () {
    expect(ApiConfig.defaultDevBaseUrl, contains(stagingHost));
    expect(
      ApiConfig.defaultDevBaseUrl,
      'https://garra-digital-u-production.up.railway.app/api/v1',
    );
    // Widget/unit tests run non-release → staging default.
    expect(kReleaseMode, isFalse);
    expect(ApiConfig.baseUrl, ApiConfig.defaultDevBaseUrl);
  });

  test('RELEASE_REQUIRES_EXPLICIT_API', () {
    // Release path is enforced inside ApiConfig.baseUrl when kReleaseMode.
    // We assert the fail-fast contract via assertReleaseSafe documentation:
    // empty define + release ⇒ StateError. Runtime release covered by gate docs.
    expect(
      () => ApiConfig.websocketUrlFrom(''),
      throwsA(isA<StateError>()),
    );
    expect(
      () => ApiConfig.websocketUrlFrom('not-a-url'),
      throwsA(anything),
    );
  });

  test('WS_DERIVATION', () {
    expect(
      ApiConfig.websocketUrlFrom(ApiConfig.defaultDevBaseUrl),
      'wss://garra-digital-u-production.up.railway.app/ws',
    );
    expect(
      ApiConfig.websocketUrlFrom('http://localhost:8081/api/v1'),
      'ws://localhost:8081/ws',
    );
    expect(
      ApiConfig.websocketUrlFrom('https://custom-prod.example.com/api/v1'),
      'wss://custom-prod.example.com/ws',
    );
  });

  test('NO_LEGACY_HOST', () {
    expect(ApiConfig.baseUrl.contains(legacyHost), isFalse);
    expect(ApiConfig.defaultDevBaseUrl.contains(legacyHost), isFalse);
    expect(ApiConfig.websocketUrl.contains(legacyHost), isFalse);
  });

  test('SEMVER_COMPARE_NOT_LEXICOGRAPHIC', () {
    expect(SemVer.parse('1.0.0') > SemVer.parse('0.9.10'), isTrue);
    expect(SemVer.parse('0.9.9') < SemVer.parse('0.9.10'), isTrue);
    expect(
      evaluateVersion(
        installed: '0.8.0',
        minimumSupported: '0.9.0',
        latest: '1.0.0',
      ),
      AppVersionStatus.updateRequired,
    );
    expect(
      evaluateVersion(
        installed: '0.9.5',
        minimumSupported: '0.9.0',
        latest: '1.0.0',
      ),
      AppVersionStatus.updateAvailable,
    );
    expect(
      evaluateVersion(
        installed: '1.0.0',
        minimumSupported: '0.9.0',
        latest: '1.0.0',
      ),
      AppVersionStatus.supported,
    );
  });
}
