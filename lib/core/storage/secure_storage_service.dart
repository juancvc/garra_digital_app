import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _deviceTokenIdKey = 'garra_device_token_id';
  static const _fcmTokenKey = 'garra_fcm_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearToken() {
    return _storage.delete(key: _tokenKey);
  }

  Future<void> saveRefreshToken(String refreshToken) {
    return _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearRefreshToken() {
    return _storage.delete(key: _refreshTokenKey);
  }

  /// Clears access + refresh only (keeps device push keys unless [clearAll]).
  Future<void> clearSessionTokens() async {
    await clearToken();
    await clearRefreshToken();
  }

  Future<void> clearAll() {
    return _storage.deleteAll();
  }

  Future<void> saveDeviceTokenId(String id) {
    return _storage.write(key: _deviceTokenIdKey, value: id);
  }

  Future<String?> getDeviceTokenId() {
    return _storage.read(key: _deviceTokenIdKey);
  }

  Future<void> saveFcmToken(String token) {
    return _storage.write(key: _fcmTokenKey, value: token);
  }

  Future<String?> getFcmToken() {
    return _storage.read(key: _fcmTokenKey);
  }

  Future<void> clearDevicePushKeys() async {
    await _storage.delete(key: _deviceTokenIdKey);
    await _storage.delete(key: _fcmTokenKey);
  }
}
