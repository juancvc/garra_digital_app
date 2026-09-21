import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:garra_digital_app/core/auth/auth_refresh_coordinator.dart';
import 'package:garra_digital_app/core/storage/secure_storage_service.dart';

/// Adapter-backed test mirroring DioClient retry-once + auth exclusions.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService storage;
  late Dio apiDio;
  late Dio refreshDio;
  late AuthRefreshCoordinator coordinator;
  late int protectedHits;
  late int refreshHits;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageService();
    await storage.clearAll();
    await storage.saveToken('access-old');
    await storage.saveRefreshToken('refresh-old');

    protectedHits = 0;
    refreshHits = 0;

    refreshDio = Dio(BaseOptions(baseUrl: 'https://staging.test/api/v1'));
    refreshDio.httpClientAdapter = _ScriptedAdapter((options) async {
      if (options.path.contains('/auth/refresh')) {
        refreshHits++;
        return ResponseBody.fromString(
          '{"success":true,"data":{"token":"access-new","refreshToken":"refresh-new"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString('{}', 404);
    });

    coordinator = AuthRefreshCoordinator(
      storage: storage,
      refreshDio: refreshDio,
    );

    apiDio = Dio(BaseOptions(baseUrl: 'https://staging.test/api/v1'));
    apiDio.httpClientAdapter = _ScriptedAdapter((options) async {
      if (options.path.contains('/protected')) {
        protectedHits++;
        final auth = options.headers['Authorization']?.toString() ?? '';
        if (auth.contains('access-old')) {
          return ResponseBody.fromString(
            '{"message":"expired"}',
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString(
          '{"ok":true}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      if (options.path.contains('/auth/login')) {
        return ResponseBody.fromString(
          '{"message":"bad credentials"}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString('{}', 404);
    });

    apiDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode != 401) {
            return handler.next(error);
          }
          final path = error.requestOptions.path.toLowerCase();
          if (path.contains('/auth/login') ||
              path.contains('/auth/refresh') ||
              path.contains('/auth/register') ||
              path.contains('/auth/google') ||
              path.contains('/auth/logout')) {
            return handler.next(error);
          }
          if (error.requestOptions.extra['garra_auth_retried'] == true) {
            return handler.next(error);
          }
          final ok = await coordinator.refresh();
          if (!ok) return handler.next(error);
          final req = error.requestOptions;
          req.extra['garra_auth_retried'] = true;
          final token = await storage.getToken();
          if (token != null) {
            req.headers['Authorization'] = 'Bearer $token';
          }
          final response = await apiDio.fetch(req);
          return handler.resolve(response);
        },
      ),
    );
  });

  test('ORIGINAL_REQUEST_RETRIED_ONCE', () async {
    final response = await apiDio.get('/protected');
    expect(response.statusCode, 200);
    expect(protectedHits, 2);
    expect(refreshHits, 1);
    expect(await storage.getToken(), 'access-new');
  });

  test('AUTH_LOGIN_401_DOES_NOT_REFRESH', () async {
    await expectLater(
      () => apiDio.post('/auth/login', data: {}),
      throwsA(isA<DioException>()),
    );
    expect(refreshHits, 0);
  });
}
