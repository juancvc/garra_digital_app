import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/secure_storage_service.dart';

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
      await _storage.clearSessionTokens();
      return false;
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final root = response.data;
      final data = root?['data'];
      if (data is! Map) {
        await _storage.clearSessionTokens();
        return false;
      }

      final access = data['token']?.toString();
      final nextRefresh = data['refreshToken']?.toString();
      if (access == null || access.isEmpty) {
        await _storage.clearSessionTokens();
        return false;
      }

      await _storage.saveToken(access);
      if (nextRefresh != null && nextRefresh.isNotEmpty) {
        await _storage.saveRefreshToken(nextRefresh);
      }
      return true;
    } on DioException {
      await _storage.clearSessionTokens();
      return false;
    } catch (_) {
      await _storage.clearSessionTokens();
      return false;
    }
  }
}
