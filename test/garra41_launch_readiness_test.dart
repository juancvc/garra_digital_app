import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/auth_refresh_coordinator.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/auth/session_events.dart';
import 'package:garra_digital_app/core/auth/session_scope.dart';
import 'package:garra_digital_app/core/network/dio_client.dart';
import 'package:garra_digital_app/core/storage/secure_storage_service.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/features/auth/data/auth_service.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/auth/presentation/complete_profile_page.dart';
import 'package:garra_digital_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/notifications/data/notification_service.dart';
import 'package:garra_digital_app/features/settings/presentation/settings_pages.dart';
import 'package:garra_digital_app/features/notifications/presentation/notifications_screen.dart';
import 'package:go_router/go_router.dart';

import 'home_screen_test.dart' show sampleHome;

NotificationItem _n(String id, {bool read = false}) => NotificationItem(
  id: id,
  type: 'SYSTEM',
  title: 'Aviso $id',
  message: 'Mensaje $id',
  createdAt: DateTime.utc(2026, 10, 1, 12),
  read: read,
);

class _Notifs extends NotificationService {
  _Notifs() : super(dio: Dio());

  final Map<String?, NotificationsPage> byCursor = {};
  final calls = <String?>[];
  final markRead_ = <String>[];
  int failMore = 0;
  bool failFirst = false;

  @override
  Future<NotificationsPage> getNotificationsPage({
    String? cursor,
    int size = 30,
  }) async {
    calls.add(cursor);
    if (cursor == null && failFirst) {
      throw DioException(
        requestOptions: RequestOptions(path: '/notifications/me'),
        type: DioExceptionType.connectionError,
      );
    }
    if (cursor != null && failMore > 0) {
      failMore--;
      throw DioException(
        requestOptions: RequestOptions(path: '/notifications/me'),
        type: DioExceptionType.connectionError,
      );
    }
    return byCursor[cursor] ?? const NotificationsPage(items: []);
  }

  @override
  Future<List<NotificationItem>> getMyNotifications({int size = 30}) async =>
      (await getNotificationsPage(size: size)).items;

  @override
  Future<void> markRead(String id) async => markRead_.add(id);

  @override
  Future<void> markAllRead() async {}
}

_Notifs _twoPages() => _Notifs()
  ..byCursor[null] = NotificationsPage(
    items: [for (var i = 1; i <= 16; i++) _n('n$i')],
    nextCursor: 'c1',
    hasNext: true,
  )
  ..byCursor['c1'] = NotificationsPage(
    items: [_n('n16'), _n('n17'), _n('n18')],
  );

Future<int Function()> _pumpNotifs(
  WidgetTester tester,
  _Notifs service, {
  Size size = const Size(400, 700),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var homeLoads = 0;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Stack(
          children: [
            const NotificationsScreen(),
            Consumer(
              builder: (_, ref, _) {
                ref.watch(homeProvider);
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(service),
        homeProvider.overrideWith((ref) {
          homeLoads++;
          return Completer<HomeModel>().future;
        }),
      ],
      child: MaterialApp.router(
        theme: theme ?? AppTheme.darkTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return () => homeLoads;
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

DioException _http(int status, [Object? data]) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: data,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SESSION: refresh failures', () {
    late SecureStorageService storage;
    late List<SessionEventKind> events;
    late StreamSubscription<SessionEventKind> sub;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      storage = SecureStorageService();
      events = [];
      sub = SessionEvents.stream.listen(events.add);
    });
    tearDown(() => sub.cancel());

    AuthRefreshCoordinator coordinatorFailing(DioException error) {
      final dio = Dio(BaseOptions(baseUrl: 'https://staging.test/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: error.type,
              response: error.response == null
                  ? null
                  : Response(
                      requestOptions: options,
                      statusCode: error.response!.statusCode,
                      data: error.response!.data,
                    ),
            ),
          ),
        ),
      );
      return AuthRefreshCoordinator(storage: storage, refreshDio: dio);
    }

    test('offline / timeout / 5xx while refreshing KEEP the session', () async {
      for (final error in [
        DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: DioExceptionType.connectionError,
        ),
        DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: DioExceptionType.receiveTimeout,
        ),
        _http(503),
        _http(500),
      ]) {
        await storage.saveToken('access');
        await storage.saveRefreshToken('refresh');
        expect(await coordinatorFailing(error).refresh(), isFalse);
        expect(await storage.getToken(), 'access', reason: '$error');
        expect(await storage.getRefreshToken(), 'refresh', reason: '$error');
      }
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
    });

    test(
      'a rejected refresh token ends the session once and says so',
      () async {
        await storage.saveToken('access');
        await storage.saveRefreshToken('refresh');
        expect(await coordinatorFailing(_http(401)).refresh(), isFalse);
        expect(await storage.getToken(), isNull);
        expect(await storage.getRefreshToken(), isNull);
        await Future<void>.delayed(Duration.zero);
        expect(events, [SessionEventKind.expired]);
      },
    );

    test('no session at all: nothing to expire, no event', () async {
      expect(await coordinatorFailing(_http(401)).refresh(), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
    });

    test('MEMBERSHIP_REQUIRED is recognised only with its typed code', () {
      DioException e(
        int status,
        Object? body, {
        String path = '/community/feed',
      }) => DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: status,
          data: body,
        ),
      );
      const typed = {
        'success': false,
        'errors': {'code': 'MEMBERSHIP_REQUIRED'},
      };
      expect(DioClient.isMembershipRequired(e(403, typed)), isTrue);
      // Any other 403 (blocked, private, no permission) is untouched.
      expect(
        DioClient.isMembershipRequired(
          e(403, {'success': false, 'message': 'Access denied'}),
        ),
        isFalse,
      );
      expect(DioClient.isMembershipRequired(e(401, typed)), isFalse);
      expect(DioClient.isMembershipRequired(e(403, null)), isFalse);
      expect(
        DioClient.isMembershipRequired(
          e(403, typed, path: '/auth/complete-profile'),
        ),
        isFalse,
      );
    });
  });

  group('LOGOUT', () {
    test(
      'revokes the refresh token, clears BOTH tokens and announces it',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final storage = SecureStorageService();
        await storage.saveToken('access');
        await storage.saveRefreshToken('refresh');
        final paths = <String>[];
        Object? sentBody;
        final dio = Dio(BaseOptions(baseUrl: 'https://staging.test/api/v1'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              paths.add('${options.method} ${options.path}');
              if (options.path == '/auth/logout') sentBody = options.data;
              handler.resolve(
                Response(requestOptions: options, statusCode: 200, data: {}),
              );
            },
          ),
        );
        final events = <SessionEventKind>[];
        final sub = SessionEvents.stream.listen(events.add);
        addTearDown(sub.cancel);

        await AuthService(dio: dio, storage: storage).logout();
        await Future<void>.delayed(Duration.zero);

        expect(paths, contains('POST /auth/logout'));
        expect(sentBody, {'refreshToken': 'refresh'});
        // A leftover refresh token would let a late 401 sign the user back in.
        expect(await storage.getToken(), isNull);
        expect(await storage.getRefreshToken(), isNull);
        expect(events, [SessionEventKind.ended]);
      },
    );

    test('an unreachable server never blocks logging out', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SecureStorageService();
      await storage.saveToken('access');
      await storage.saveRefreshToken('refresh');
      final dio = Dio(BaseOptions(baseUrl: 'https://staging.test/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          ),
        ),
      );
      await AuthService(dio: dio, storage: storage).logout();
      expect(await storage.getToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });

  group('SESSION SCOPE', () {
    late GoRouter router;

    Future<ProviderContainer> pump(
      WidgetTester tester, {
      List<Override> overrides = const [],
      Duration resumeAfter = const Duration(seconds: 45),
      Widget? home,
    }) async {
      router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => home ?? const Text('ROOT')),
          GoRoute(path: '/welcome', builder: (_, _) => const Text('WELCOME')),
          GoRoute(
            path: '/complete-profile',
            builder: (_, _) => const Text('COMPLETE'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (_, child) => SessionScope(
              router: router,
              resumeRefreshAfter: resumeAfter,
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
    }

    testWidgets(
      'an expired session goes to /welcome (no screen-by-screen 401s)',
      (tester) async {
        await pump(tester);
        SessionEvents.emit(SessionEventKind.expired);
        await tester.pumpAndSettle();
        expect(find.text('WELCOME'), findsOneWidget);
      },
    );

    testWidgets('MEMBERSHIP_REQUIRED sends to /complete-profile once', (
      tester,
    ) async {
      await pump(tester);
      SessionEvents.emit(SessionEventKind.membershipRequired);
      SessionEvents.emit(SessionEventKind.membershipRequired);
      await tester.pumpAndSettle();
      expect(find.text('COMPLETE'), findsOneWidget);
      // Already there: further 403s do not push the route again.
      SessionEvents.emit(SessionEventKind.membershipRequired);
      await tester.pumpAndSettle();
      expect(find.text('COMPLETE'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/complete-profile',
      );
    });

    testWidgets('logout A -> user B starts clean (no leaked follow state)', (
      tester,
    ) async {
      final container = await pump(tester);
      container.read(followStateProvider.notifier).report('x', true);
      expect(container.read(followStateProvider), {'x': true});
      SessionEvents.emit(SessionEventKind.ended);
      await tester.pump();
      expect(container.read(followStateProvider), isEmpty);
    });

    for (final c in [
      (const Duration(minutes: 2), 2, 'a long stay in background'),
      (const Duration(seconds: 5), 1, 'a quick app switch'),
    ]) {
      testWidgets('resume refreshes Home after ${c.$3} only when it is stale', (
        tester,
      ) async {
        var loads = 0;
        final overrides = [
          homeProvider.overrideWith((ref) async {
            loads++;
            return sampleHome();
          }),
        ];
        await pump(
          tester,
          overrides: overrides,
          resumeAfter: c.$1 == const Duration(minutes: 2)
              ? Duration.zero
              : const Duration(minutes: 10),
          home: Consumer(
            builder: (_, ref, _) {
              ref.watch(homeProvider);
              return const Text('HOME-WATCHER');
            },
          ),
        );
        expect(loads, 1);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(loads, c.$2);
      });
    }
  });

  group('HOME keeps its tab while it reloads', () {
    testWidgets(
      'a reload (resume / bell) keeps the Home tab and its feed, even if it fails',
      (tester) async {
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var homeLoads = 0;
        final reload = Completer<HomeModel>();
        final feed = _FollowingFeed();
        final router = GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeProvider.overrideWith((ref) async {
                homeLoads++;
                // The reload stays in flight so the loading frame is observable.
                if (homeLoads > 1) return reload.future;
                return sampleHome(matchdayState: 'MATCHDAY');
              }),
              communityServiceProvider.overrideWithValue(feed),
              currentFanProvider.overrideWith(_NoFan.new),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Siguiendo'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('FOLLOWING')), findsOneWidget);
        final feedCalls = feed.calls;

        ProviderScope.containerOf(
          tester.element(find.byType(HomePage)),
        ).invalidate(homeProvider);
        await tester.pump(); // reload in flight
        expect(find.byType(GarraHomeSkeleton), findsNothing);
        expect(find.byKey(const ValueKey('FOLLOWING')), findsOneWidget);
        await tester.pumpAndSettle();

        expect(homeLoads, 2);
        expect(find.byType(GarraErrorState), findsNothing);
        expect(find.byKey(const ValueKey('FOLLOWING')), findsOneWidget);
        expect(feed.calls, feedCalls, reason: 'the feed was not rebuilt');
      },
    );
  });

  group('NOTIFICATION CENTER', () {
    testWidgets('reaching the end loads the next page once, no duplicates', (
      tester,
    ) async {
      final svc = _twoPages();
      await _pumpNotifs(tester, svc);
      expect(svc.calls, [null]);

      await _scrollToEnd(tester);

      expect(svc.calls, [null, 'c1']);
      expect(
        find.byKey(
          const ValueKey('notification_item_n18'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('notification_item_n16'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'a failed next page keeps the rows, offers retry and recovers',
      (tester) async {
        final svc = _twoPages()..failMore = 1;
        await _pumpNotifs(tester, svc);

        await _scrollToEnd(tester);
        expect(
          find.byKey(const ValueKey('notifications_more_error')),
          findsOneWidget,
        );
        expect(find.text('Aviso n16', skipOffstage: false), findsOneWidget);
        expect(find.text('Todo tranquilo por ahora.'), findsNothing);
        // Scrolling again does not re-fire the failed request by itself.
        final afterFailure = svc.calls.length;
        await _scrollToEnd(tester);
        expect(svc.calls.length, afterFailure);

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('notifications_more_error')),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey('notification_item_n18'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'opening an unread row marks it read locally without reloading',
      (tester) async {
        final svc = _Notifs()
          ..byCursor[null] = NotificationsPage(
            items: [_n('n1'), _n('n2', read: true)],
          );
        final homeLoads = await _pumpNotifs(tester, svc);
        expect(homeLoads(), 1);

        await tester.tap(find.byKey(const ValueKey('notification_item_n1')));
        await tester.pumpAndSettle();

        expect(svc.markRead_, ['n1']);
        expect(svc.calls, [null], reason: 'loaded pages are not discarded');
        expect(homeLoads(), 2, reason: 'the bell badge is reconciled');
        // Read now: tapping again does not PATCH twice.
        await tester.tap(find.byKey(const ValueKey('notification_item_n1')));
        await tester.pumpAndSettle();
        expect(svc.markRead_, ['n1']);
      },
    );

    testWidgets('a failed pull-to-refresh keeps what is on screen', (
      tester,
    ) async {
      final svc = _twoPages();
      await _pumpNotifs(tester, svc);
      svc.failFirst = true;

      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 500),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Aviso n1'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(GarraErrorState), findsNothing);
    });

    testWidgets(
      'an initial failure is an error with retry, never "all quiet"',
      (tester) async {
        final svc = _twoPages()..failFirst = true;
        await _pumpNotifs(tester, svc);
        expect(find.byType(GarraErrorState), findsOneWidget);
        expect(find.text('Todo tranquilo por ahora.'), findsNothing);

        svc.failFirst = false;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('Aviso n1'), findsOneWidget);
      },
    );

    for (final width in [220.0, 320.0]) {
      for (final dark in [true, false]) {
        testWidgets('fits ${width.toInt()} px with a failed page '
            '(${dark ? 'Noche' : 'Crema'})', (tester) async {
          final svc = _twoPages()..failMore = 1;
          await _pumpNotifs(
            tester,
            svc,
            size: Size(width, 700),
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          );
          await _scrollToEnd(tester);
          expect(
            find.byKey(const ValueKey('notifications_more_error')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('DELETED / UNAVAILABLE TARGET', () {
    Future<void> openProfile(WidgetTester tester, _Profile svc) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: PublicFanProfilePage(userId: 'gone', communityService: svc),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final status in [404, 403]) {
      testWidgets('a profile that answers $status says it is unavailable', (
        tester,
      ) async {
        await openProfile(tester, _Profile(_http(status)));
        expect(
          find.text('Este perfil no est\u00e1 disponible'),
          findsOneWidget,
        );
        // Not a retry loop on something that will never come back.
        expect(find.text('Reintentar'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a network failure still offers retry', (tester) async {
      await openProfile(
        tester,
        _Profile(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('PERFIL GARRA: community rules', () {
    Future<_Auth> open(WidgetTester tester, {double width = 800}) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _Auth();
      final router = GoRouter(
        initialLocation: '/complete-profile',
        routes: [
          GoRoute(
            path: '/complete-profile',
            builder: (_, _) => const CompleteProfilePage(),
          ),
          GoRoute(path: '/welcome', builder: (_, _) => const Text('WELCOME')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(auth)],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('the rules are one tap away and the checkbox keeps its meaning', (
      tester,
    ) async {
      await open(tester);
      expect(
        find.text(
          'Me comprometo a respetar las normas de convivencia de la comunidad.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('He le\u00eddo'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('guidelines-link')));
      expect(find.text('Leer las normas de comunidad'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('guidelines-link')));
      await tester.pumpAndSettle();

      // Opening (or failing to open) the document never ticks the box.
      final tile = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('accept-guidelines')),
      );
      expect(tile.value, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the exit button uses the full logout', (tester) async {
      final auth = await open(tester);
      await tester.tap(find.byKey(const ValueKey('profile-logout')));
      await tester.pumpAndSettle();
      expect(auth.logouts, 1);
      expect(find.text('WELCOME'), findsOneWidget);
    });

    testWidgets('fits 220 px', (tester) async {
      await open(tester, width: 220);
      expect(find.byKey(const ValueKey('guidelines-link')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
  group('BLOCKS: review and undo', () {
    testWidgets('Ajustes links to the blocked users list', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SettingsHubPage()),
          GoRoute(
            path: '/comunidad/bloqueados',
            builder: (_, _) => const Text('BLOQUEADOS'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Usuarios bloqueados'), findsOneWidget);
      await tester.tap(find.text('Usuarios bloqueados'));
      await tester.pumpAndSettle();
      expect(find.text('BLOQUEADOS'), findsOneWidget);
    });

    Future<_Blocks> open(WidgetTester tester, _Blocks svc) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: BlockedUsersPage(service: svc),
        ),
      );
      await tester.pumpAndSettle();
      return svc;
    }

    testWidgets('a failed load is an error, not "Nadie bloqueado"', (
      tester,
    ) async {
      final svc = await open(tester, _Blocks()..failList = true);
      expect(find.byType(GarraErrorState), findsOneWidget);
      expect(find.text('Nadie bloqueado'), findsNothing);
      svc.failList = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('@ana'), findsOneWidget);
    });

    testWidgets(
      'unblock removes the row once; a failure keeps it and says so',
      (tester) async {
        final svc = await open(tester, _Blocks()..failUnblock = true);

        await tester.tap(find.text('Desbloquear').first);
        await tester.pumpAndSettle();
        expect(find.text('@ana'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);

        svc.failUnblock = false;
        await tester.pump(const Duration(seconds: 5));
        await tester.tap(find.text('Desbloquear').first);
        await tester.pumpAndSettle();
        expect(find.text('@ana'), findsNothing);
        expect(find.text('@beto'), findsOneWidget);
        expect(svc.unblocked, ['u1', 'u1']);
      },
    );
  });
}

class _Auth extends AuthService {
  _Auth() : super(dio: Dio());
  int logouts = 0;

  @override
  Future<void> logout() async => logouts++;

  @override
  Future<AuthUser?> me() async => null;
}

class _NoFan extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _FollowingFeed extends CommunityService {
  _FollowingFeed() : super(dio: Dio());
  int calls = 0;

  @override
  Future<FeedPage> getFeedPage({
    required String mode,
    String? cursor,
    int size = 20,
  }) async {
    calls++;
    return FeedPage.posts(posts: []);
  }
}

class _Profile extends CommunityService {
  _Profile(this.error) : super(dio: Dio());
  final DioException error;

  @override
  Future<Map<String, dynamic>> getPublicProfile(String userId) async =>
      throw error;
}

class _Blocks extends CommunityService {
  _Blocks() : super(dio: Dio());
  bool failList = false;
  bool failUnblock = false;
  final unblocked = <String>[];
  final _rows = [
    {'userId': 'u1', 'displayName': 'Ana', 'username': 'ana'},
    {'userId': 'u2', 'displayName': 'Beto', 'username': 'beto'},
  ];

  @override
  Future<List<Map<String, dynamic>>> listBlocks() async {
    if (failList) throw StateError('offline');
    return [for (final r in _rows) Map<String, dynamic>.from(r)];
  }

  @override
  Future<void> unblockUser(String userId) async {
    unblocked.add(userId);
    if (failUnblock) throw StateError('offline');
    _rows.removeWhere((r) => r['userId'] == userId);
  }
}
