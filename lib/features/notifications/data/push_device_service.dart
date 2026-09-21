import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';

/// Registers / refreshes FCM device tokens with the Garra API.
class PushDeviceService {
  PushDeviceService({
    Dio? dio,
    SecureStorageService? storage,
    FirebaseMessaging? messaging,
  })  : _dio = dio ?? DioClient.instance,
        _storage = storage ?? SecureStorageService(),
        _messaging = messaging ?? FirebaseMessaging.instance;

  final Dio _dio;
  final SecureStorageService _storage;
  final FirebaseMessaging _messaging;

  Future<bool> requestPermissionIfNeeded() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> registerCurrentToken() async {
    final allowed = await requestPermissionIfNeeded();
    if (!allowed) return;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _upsertToken(token);
  }

  void listenForRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      if (token.isEmpty) return;
      await _upsertToken(token);
    });
  }

  Future<void> _upsertToken(String token) async {
    final hasAuth = await _storage.hasToken();
    if (!hasAuth) return;
    final response = await _dio.post(
      '/devices',
      data: {'token': token, 'platform': _platform()},
    );
    final data = response.data['data'];
    if (data is Map && data['id'] != null) {
      await _storage.saveDeviceTokenId(data['id'].toString());
      await _storage.saveFcmToken(token);
    }
  }

  /// Best-effort deactivate before logout. Never throws.
  Future<void> deactivateCurrent() async {
    try {
      final id = await _storage.getDeviceTokenId();
      if (id == null || id.isEmpty) return;
      await _dio.delete('/devices/$id');
    } catch (_) {
      // Ignore — logout must continue.
    } finally {
      try {
        await _storage.clearDevicePushKeys();
      } catch (_) {}
    }
  }

  String _platform() {
    if (kIsWeb) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    return 'ANDROID';
  }
}
