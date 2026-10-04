import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/secure_storage_service.dart';
import 'session_events.dart';

/// Single-flight refresh coordinator for Dio 401 recovery.
///
/// Uses a bare [Dio] (no auth interceptors) so `/auth/refresh` never recurses.
class AuthRefreshCoordinator {
  AuthRefreshCoordinator({
    SecureStorageService? storage,
    Dio? refreshDio,
  })  : _storage = storage ?? SecureStorageService(),
        _refreshDio = refreshDio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final SecureStorageService _storage;
  final Dio _refreshDio;

  Future<bool>? _inFlight;

  /// Returns true when a new access (+ refresh) token pair was stored.
  Future<bool> refresh() {
    return _inFlight ??= _doRefresh().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return await _endSession();
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final root = response.data;
      final data = root?['data'];
      if (data is! Map) {
        return await _endSession();
      }

      final access = data['token']?.toString();
      final nextRefresh = data['refreshToken']?.toString();
      if (access == null || access.isEmpty) {
        return await _endSession();
      }

      await _storage.saveToken(access);
      if (nextRefresh != null && nextRefresh.isNotEmpty) {
        await _storage.saveRefreshToken(nextRefresh);
      }
      return true;
    } on DioException catch (e) {
      // Only a definitive "this refresh token is not valid" ends the session.
      // Offline, a timeout or a 5xx must keep the tokens: the user is still
      // signed in and the next request can refresh normally.
      if (rejectsRefreshToken(e)) return await _endSession();
      return false;
    } catch (_) {
      return false;
    }
  }

  /// The refresh token was rejected (or there is none): clear it and tell the
  /// app once, so it routes to sign-in instead of failing request by request.
  Future<bool> _endSession() async {
    final hadSession = await _storage.hasToken();
    await _storage.clearSessionTokens();
    if (hadSession) SessionEvents.emit(SessionEventKind.expired);
    return false;
  }

  /// 400/401/403 from /auth/refresh = invalid, expired or revoked token.
  static bool rejectsRefreshToken(DioException e) {
    final status = e.response?.statusCode;
    return status == 400 || status == 401 || status == 403;
  }
}
