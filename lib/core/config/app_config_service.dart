import 'package:dio/dio.dart';

import '../network/dio_client.dart';
import 'semver.dart';

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
    this.fromFallback = false,
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

  /// True only for [AppConfigModel.fallback]: no `/app-config` answer was
  /// parsed (offline, timeout, error). PRODUCT-10A.2E.
  final bool fromFallback;

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
        fromFallback: true,
      );
}

/// PRODUCT-10A.2E: a store link the optional notice can actually open.
bool isLaunchableStoreUrl(String? raw) {
  final uri = raw == null ? null : Uri.tryParse(raw.trim());
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
}

/// PRODUCT-10A.2E: the optional (non-forced) update notice is shown only for
/// a real backend answer that also offers a launchable store link. Forced
/// update ([AppVersionStatus.updateRequired]) is decided elsewhere and is not
/// affected by this rule.
bool shouldShowOptionalUpdate(AppVersionStatus status, AppConfigModel config) =>
    status == AppVersionStatus.updateAvailable &&
    !config.fromFallback &&
    isLaunchableStoreUrl(config.storeUrl);

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
