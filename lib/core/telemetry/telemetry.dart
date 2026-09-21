import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Privacy consent center — analytics/diagnostics opt-in for beta.
class PrivacyConsentStore {
  static const _analyticsKey = 'garra_consent_analytics';
  static const _diagnosticsKey = 'garra_consent_diagnostics';

  bool analyticsEnabled = false;
  bool diagnosticsEnabled = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    analyticsEnabled = prefs.getBool(_analyticsKey) ?? false;
    diagnosticsEnabled = prefs.getBool(_diagnosticsKey) ?? false;
    await applyToFirebase();
  }

  Future<void> setAnalytics(bool value) async {
    analyticsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsKey, value);
    await applyToFirebase();
  }

  Future<void> setDiagnostics(bool value) async {
    diagnosticsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_diagnosticsKey, value);
    await applyToFirebase();
  }

  Future<void> applyToFirebase() async {
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(analyticsEnabled);
    } catch (_) {}
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(diagnosticsEnabled);
    } catch (_) {}
  }
}

final privacyConsentStore = PrivacyConsentStore();

/// Thin analytics facade — never log PII / post text / tokens.
class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object>? params}) async {
    if (!privacyConsentStore.analyticsEnabled) return;
    final safe = _sanitize(params);
    if (kDebugMode) {
      debugPrint('[ANALYTICS] $name $safe');
    }
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: safe);
    } catch (_) {}
  }

  Map<String, Object> _sanitize(Map<String, Object>? params) {
    if (params == null) return const {};
    final out = <String, Object>{};
    for (final e in params.entries) {
      final k = e.key.toLowerCase();
      if (k.contains('email') ||
          k.contains('token') ||
          k.contains('password') ||
          k.contains('phone') ||
          k.contains('lat') ||
          k.contains('lng') ||
          k.contains('content') ||
          k.contains('query') ||
          k.contains('username')) {
        continue;
      }
      out[e.key] = e.value;
    }
    return out;
  }
}

final analyticsService = AnalyticsService();

class CrashReporting {
  static Future<void> installHooks() async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      recordError(details.exception, details.stack, fatal: true);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, fatal: true);
      return true;
    };
  }

  static void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    if (!privacyConsentStore.diagnosticsEnabled && !fatal) return;
    if (kDebugMode) {
      debugPrint('[CRASH] fatal=$fatal error=$error');
    }
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
    } catch (_) {}
  }

  static void breadcrumb(String screen, String operation, {int? httpStatus}) {
    if (!privacyConsentStore.diagnosticsEnabled) return;
    final msg =
        'screen=$screen operation=$operation${httpStatus != null ? ' http_status=$httpStatus' : ''}';
    if (kDebugMode) {
      debugPrint('[CRASH][BREADCRUMB] $msg');
    }
    try {
      FirebaseCrashlytics.instance.log(msg);
    } catch (_) {}
  }
}
