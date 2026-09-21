import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router/app_router.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/data/push_router.dart';
import 'features/notifications/data/push_session_coordinator.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handler must be a top-level function. Routing happens on open.
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_PE', null);
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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

  @override
  void initState() {
    super.initState();
    _bootstrapPush();
  }

  Future<void> _bootstrapPush() async {
    try {
      final hasAuth = await _storage.hasToken();
      await pushSessionCoordinator.bootstrapIfAuthenticated(hasAuth: hasAuth);
    } catch (_) {}

    FirebaseMessaging.onMessage.listen((_) {
      // Foreground: in-app list/badge refresh only — no disruptive OS duplicate.
    });

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
    return MaterialApp.router(
      title: 'GarraDigital',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
