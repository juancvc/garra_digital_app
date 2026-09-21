import 'package:dio/dio.dart';

import '../network/dio_client.dart';

class AppConfigModel {
  AppConfigModel({
    required this.environment,
    required this.maintenanceMode,
    this.maintenanceMessage,
    required this.minimumSupportedVersion,
    required this.latestVersion,
    required this.features,
    this.supportUrl,
    this.privacyUrl,
    this.termsUrl,
    this.storeUrl,
  });

  final String environment;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String minimumSupportedVersion;
  final String latestVersion;
  final Map<String, bool> features;
  final String? supportUrl;
  final String? privacyUrl;
  final String? termsUrl;
  final String? storeUrl;

  bool feature(String key) => features[key] ?? true;

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final features = <String, bool>{};
    if (rawFeatures is Map) {
      rawFeatures.forEach((k, v) {
        features[k.toString()] = v == true;
      });
    }
    return AppConfigModel(
      environment: json['environment']?.toString() ?? 'staging',
      maintenanceMode: json['maintenanceMode'] == true,
      maintenanceMessage: json['maintenanceMessage']?.toString(),
      minimumSupportedVersion:
          json['minimumSupportedVersion']?.toString() ?? '0.9.0',
      latestVersion: json['latestVersion']?.toString() ?? '1.0.0',
      features: features,
      supportUrl: json['supportUrl']?.toString(),
      privacyUrl: json['privacyUrl']?.toString(),
      termsUrl: json['termsUrl']?.toString(),
      storeUrl: json['storeUrl']?.toString(),
    );
  }

  static AppConfigModel fallback() => AppConfigModel(
        environment: 'staging',
        maintenanceMode: false,
        minimumSupportedVersion: '0.9.0',
        latestVersion: '1.0.0',
        features: const {
          'community': true,
          'marketplace': true,
          'solidaria': true,
          'events': true,
          'businessOffers': true,
          'matchday': true,
        },
        privacyUrl: '/legal/privacy',
        termsUrl: '/legal/terms',
      );
}

class AppConfigService {
  AppConfigService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;
  AppConfigModel _cached = AppConfigModel.fallback();

  AppConfigModel get current => _cached;

  Future<AppConfigModel> fetch({bool silent = true}) async {
    try {
      final response = await _dio.get('/app-config');
      final data = response.data['data'];
      if (data is Map) {
        _cached = AppConfigModel.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {
      if (!silent) rethrow;
    }
    return _cached;
  }
}

final appConfigService = AppConfigService();
