import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/config/api_config.dart';
import 'core/config/app_config_service.dart';
import 'core/config/semver.dart';
import 'core/router/app_router.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/telemetry/telemetry.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_gates.dart';
import 'core/widgets/staging_banner.dart';
import 'features/notifications/data/push_router.dart';
import 'features/notifications/data/push_session_coordinator.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.assertReleaseSafe();
  ApiConfig.logDebugConfig();

  await Firebase.initializeApp();
  await privacyConsentStore.load();
  await CrashReporting.installHooks();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  unawaited(initializeDateFormatting('es_PE', null));

  runApp(const ProviderScope(child: GarraDigitalApp()));
}

class GarraDigitalApp extends StatefulWidget {
  const GarraDigitalApp({super.key});

  @override
  State<GarraDigitalApp> createState() => _GarraDigitalAppState();
}

class _GarraDigitalAppState extends State<GarraDigitalApp> {
  final _pushRouter = const PushRouter();
  final _storage = SecureStorageService();
  bool _handledInitial = false;
  bool _bootstrapped = false;
  bool _maintenance = false;
  bool _updateRequired = false;
  bool _updateAvailable = false;
  bool _dismissOptionalUpdate = false;
  AppConfigModel _config = AppConfigModel.fallback();

  @override
  void initState() {
    super.initState();
    _bootstrapPush();
    _bootstrapAppConfig();
  }

  Future<void> _bootstrapAppConfig() async {
    try {
      final cfg = await appConfigService.fetch().timeout(
        const Duration(seconds: 4),
      );
      final info = await PackageInfo.fromPlatform();
      final status = evaluateVersion(
        installed: info.version,
        minimumSupported: cfg.minimumSupportedVersion,
        latest: cfg.latestVersion,
      );
      if (!mounted) return;
      setState(() {
        _config = cfg;
        _maintenance = cfg.maintenanceMode;
        _updateRequired = status == AppVersionStatus.updateRequired;
        _updateAvailable = status == AppVersionStatus.updateAvailable;
        _bootstrapped = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _bootstrapped = true);
    }
  }

  Future<void> _bootstrapPush() async {
    try {
      final hasAuth = await _storage.hasToken();
      await pushSessionCoordinator.bootstrapIfAuthenticated(hasAuth: hasAuth);
    } catch (_) {}

    FirebaseMessaging.onMessage.listen((_) {});
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

    if (!_handledInitial) {
      _handledInitial = true;
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        _handleOpen(initial);
      }
    }
  }

  Future<void> _handleOpen(RemoteMessage message) async {
    final authenticated = await _storage.hasToken();
    final data = message.data;
    _pushRouter.navigate(
      appRouter,
      authenticated: authenticated,
      type: data['type']?.toString(),
      referenceType: data['referenceType']?.toString(),
      referenceId: data['referenceId']?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapped && (_maintenance || _updateRequired)) {
      final gate = _maintenance
          ? MaintenanceGatePage(
              message: _config.maintenanceMessage ?? '',
              onRetry: () async {
                setState(() => _bootstrapped = false);
                await _bootstrapAppConfig();
              },
            )
          : UpdateRequiredPage(config: _config);
      return MaterialApp(
        title: 'GarraDigital',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: StagingBanner(child: gate),
      );
    }

    return MaterialApp.router(
      title: 'GarraDigital',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        Widget body = content;
        if (_updateAvailable && !_dismissOptionalUpdate) {
          body = Stack(
            children: [
              content,
              Positioned(
                top: MediaQuery.paddingOf(context).top + 6,
                left: 12,
                right: 12,
                child: OptionalUpdateBanner(
                  latestVersion: _config.latestVersion,
                  storeUrl: _config.storeUrl,
                  onDismiss: () =>
                      setState(() => _dismissOptionalUpdate = true),
                ),
              ),
            ],
          );
        }
        return StagingBanner(child: body);
      },
    );
  }
}
