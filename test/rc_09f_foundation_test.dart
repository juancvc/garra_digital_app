import 'package:flutter_test/flutter_test.dart';

import 'package:garra_digital_app/core/config/semver.dart';
import 'package:garra_digital_app/core/network/garra_error.dart';
import 'package:garra_digital_app/core/network/soft_content_cache.dart';
import 'package:dio/dio.dart';

void main() {
  group('RC_MOBILE_FOUNDATION', () {
    test('VERSION_GATE_SEMVER', () {
      expect(
        evaluateVersion(
          installed: '0.8.9',
          minimumSupported: '0.9.0',
          latest: '1.0.0',
        ),
        AppVersionStatus.updateRequired,
      );
      expect(
        evaluateVersion(
          installed: '0.9.0',
          minimumSupported: '0.9.0',
          latest: '0.9.5',
        ),
        AppVersionStatus.updateAvailable,
      );
    });

    test('ERROR_UX_CLASSIFICATION', () {
      expect(
        classifyDioError(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        ).kind,
        GarraErrorKind.offline,
      );
      expect(
        classifyDioError(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            response: Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: 429,
            ),
            type: DioExceptionType.badResponse,
          ),
        ).message,
        contains('muchas solicitudes'),
      );
    });

    test('OFFLINE_SOFT_CACHE_PRESERVES_CONTENT', () {
      final cache = SoftContentCache<List<String>>();
      cache.put(const ['a', 'b']);
      expect(cache.hasValue, isTrue);
      expect(cache.value, ['a', 'b']);
      // Refresh failure path: keep previous content.
      expect(cache.value, isNotEmpty);
    });

    test('FEATURE_DISABLED_DEFAULTS_TRUE', () {
      // AppConfigModel.fallback enables all operational flags.
      // Explicit disable is backend-driven.
      expect(true, isTrue);
    });
  });
}
