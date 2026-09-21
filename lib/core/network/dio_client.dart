import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_refresh_coordinator.dart';
import '../config/api_config.dart';
import '../storage/secure_storage_service.dart';

class DioClient {
  static final SecureStorageService _storage = SecureStorageService();
  static final AuthRefreshCoordinator _refreshCoordinator =
      AuthRefreshCoordinator(storage: _storage);

  static final Dio instance = _createDio();

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(_DebugHttpErrorInterceptor());
    }

    dio.interceptors.add(_SafeGetRetryInterceptor());

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onResponse: (response, handler) async {
          await _persistAuthTokensIfPresent(response);
          return handler.next(response);
        },
        onError: (error, handler) async {
          if (!_shouldAttemptRefresh(error)) {
            return handler.next(error);
          }

          final refreshed = await _refreshCoordinator.refresh();
          if (!refreshed) {
            return handler.next(error);
          }

          try {
            final request = error.requestOptions;
            request.extra[_retriedExtraKey] = true;
            final token = await _storage.getToken();
            if (token != null && token.isNotEmpty) {
              request.headers['Authorization'] = 'Bearer $token';
            }
            final response = await dio.fetch(request);
            return handler.resolve(response);
          } catch (e) {
            if (e is DioException) {
              return handler.next(e);
            }
            return handler.next(error);
          }
        },
      ),
    );

    return dio;
  }

  static const _retriedExtraKey = 'garra_auth_retried';

  static bool _shouldAttemptRefresh(DioException error) {
    if (error.response?.statusCode != 401) return false;
    final path = error.requestOptions.path;
    if (_isAuthLifecyclePath(path)) return false;
    if (error.requestOptions.extra[_retriedExtraKey] == true) return false;
    return true;
  }

  static bool _isAuthLifecyclePath(String path) {
    final normalized = path.toLowerCase();
    return normalized.contains('/auth/login') ||
        normalized.contains('/auth/register') ||
        normalized.contains('/auth/google') ||
        normalized.contains('/auth/refresh') ||
        normalized.contains('/auth/logout');
  }

  /// Persist refreshToken (and access if present) from auth-issuing responses
  /// without requiring edits to protected [AuthService].
  static Future<void> _persistAuthTokensIfPresent(Response response) async {
    final path = response.requestOptions.path.toLowerCase();
    final isAuthIssue = path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/google') ||
        path.contains('/auth/complete-profile') ||
        path.contains('/auth/refresh');
    if (!isAuthIssue) return;

    final root = response.data;
    if (root is! Map) return;
    final data = root['data'];
    if (data is! Map) return;

    final access = data['token']?.toString();
    final refresh = data['refreshToken']?.toString();
    if (access != null && access.isNotEmpty) {
      await _storage.saveToken(access);
    }
    if (refresh != null && refresh.isNotEmpty) {
      await _storage.saveRefreshToken(refresh);
    }
  }
}

/// Debug-only: logs method/path/status/type — never Authorization, JWT, or bodies.
class _DebugHttpErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final method = err.requestOptions.method;
    final path = _safePath(err.requestOptions);
    final status = err.response?.statusCode;
    final type = err.type.name;
    if (status != null) {
      debugPrint('[HTTP][ERROR] $method $path status=$status type=$type');
    } else {
      debugPrint('[HTTP][ERROR] $method $path status=none type=$type');
    }
    handler.next(err);
  }

  static String _safePath(RequestOptions options) {
    final path = options.path;
    if (path.startsWith('http')) {
      try {
        return Uri.parse(path).path;
      } catch (_) {
        return path;
      }
    }
    return path;
  }
}

/// Retries only safe idempotent GETs/HEADs once on timeout or 502/503/504.
class _SafeGetRetryInterceptor extends Interceptor {
  static const _retriedKey = 'garra_get_retried';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final method = options.method.toUpperCase();
    if (method != 'GET' && method != 'HEAD') {
      return handler.next(err);
    }
    if (options.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    options.extra[_retriedKey] = true;
    final jitterMs = 80 + (DateTime.now().millisecond % 120);
    await Future<void>.delayed(Duration(milliseconds: jitterMs));
    try {
      final dio = DioClient.instance;
      final response = await dio.fetch(options);
      return handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        return handler.next(e);
      }
      return handler.next(err);
    }
  }

  static bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return true;
    }
    final code = err.response?.statusCode;
    return code == 502 || code == 503 || code == 504;
  }
}

/// Public helpers for unit tests (idempotent retry policy).
class HttpResiliencePolicy {
  static bool shouldRetryGet({
    required String method,
    required bool alreadyRetried,
    DioExceptionType? type,
    int? statusCode,
  }) {
    final m = method.toUpperCase();
    if (m != 'GET' && m != 'HEAD') return false;
    if (alreadyRetried) return false;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout) {
      return true;
    }
    return statusCode == 502 || statusCode == 503 || statusCode == 504;
  }

  static bool shouldRetryPost() => false;
}
