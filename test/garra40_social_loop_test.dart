import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/clans/data/clan_service.dart';
import 'package:garra_digital_app/features/clans/presentation/providers/clans_provider.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/discovery_models.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/global_search_page.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_discovery_section.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';
import 'package:garra_digital_app/features/notifications/data/notification_service.dart';
import 'package:garra_digital_app/features/notifications/data/push_router.dart';
import 'package:garra_digital_app/features/notifications/presentation/notifications_screen.dart';
import 'package:go_router/go_router.dart';

/// GARRA40: the social loop (feed continuity, follow state, search, notifications).

WallPostModel _post(String id, {int comments = 1, String content = ''}) =>
    WallPostModel(
      id: id,
      username: 'u$id',
      fullName: 'Autor $id',
      content: content.isEmpty ? 'contenido $id' : content,
      imageUrl: null,
      locationTag: 'HOME',
      status: 'ACTIVE',
      reportCount: 0,
      createdAt: '2026-10-01T10:00:00Z',
      reactionCount: 3,
      commentCount: comments,
      authorId: 'author-$id',
    );

class _Svc extends CommunityService {
  _Svc({this.discovery}) : super(dio: Dio());

  /// cursor (null = first page) -> page
  final Map<String?, FeedPage> byCursor = {};
  final DiscoveryBundle? discovery;

  final calls = <({String mode, String? cursor})>[];
  int failMore = 0;
  final postReads = <String>[];
  WallPostModel? freshPost;
  Object? postError;
  final followed = <String>[];
  bool failFollow = false;
  Map<String, dynamic> profile = const {};

  @override
  Future<FeedPage> getFeedPage({
    required String mode,
    String? cursor,
    int size = 20,
  }) async {
    calls.add((mode: mode, cursor: cursor));
    if (cursor != null && failMore > 0) {
      failMore--;
      throw DioException(requestOptions: RequestOptions(path: '/x'));
    }
    return byCursor[cursor] ?? const FeedPage(posts: []);
  }

  @override
  Future<WallPostModel> getPost(String postId) async {
    postReads.add(postId);
    if (postError != null) throw postError!;
    return freshPost ?? _post(postId);
  }

  @override
  Future<DiscoveryBundle> getDiscovery() async =>
      discovery ?? const DiscoveryBundle();

  @override
  Future<void> followUser(String userId) async {
    if (failFollow) throw Exception('offline');
    followed.add(userId);
  }

  @override
  Future<void> unfollowUser(String userId) async {
    if (failFollow) throw Exception('offline');
    followed.remove(userId);
  }

  @override
  Future<Map<String, dynamic>> getPublicProfile(String userId) async => profile;

  @override
  Future<bool> registerProfileView(String userId) async => false;

  @override
  Future<Map<String, dynamic>> globalSearch(String q, {String? type}) async =>
      const {
        'fans': [],
        'communities': [],
        'businesses': [],
        'marketplace': [],
        'solidarity': [],
      };
}

class _Source implements ConnectivitySource {
  @override
  Future<List<ConnectivityResult>> check() async => [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get changes =>
      const Stream<List<ConnectivityResult>>.empty();
}

class _Clans extends ClanService {
  _Clans() : super(dio: Dio());
}

Future<void> _mount(
  WidgetTester tester,
  Widget child,
  _Svc svc, {
  Size size = const Size(400, 700),
  ThemeData? theme,
  GoRouter? router,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final r =
      router ??
      GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: child),
          ),
          GoRoute(
            path: '/muro-crema/posts/:id',
            builder: (context, s) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('DETAIL ${s.pathParameters['id']}'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/comunidad/buscar',
            builder: (_, _) => const Scaffold(body: Text('SEARCH')),
          ),
          GoRoute(
            path: '/comunidad/compose',
            builder: (_, _) => const Scaffold(body: Text('COMPOSE')),
          ),
        ],
      );
  addTearDown(r.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityServiceProvider.overrideWithValue(svc),
        clanServiceProvider.overrideWithValue(_Clans()),
        connectivitySourceProvider.overrideWithValue(_Source()),
      ],
      child: MaterialApp.router(theme: theme, routerConfig: r),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _list => find.descendant(
  of: find.byType(SocialFeedTab),
  matching: find.byType(ListView),
);

Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.drag(_list.first, const Offset(0, -2500));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('FEED CONTINUITY', () {
    _Svc paged() {
      final svc = _Svc();
      svc.byCursor[null] = FeedPage(
        posts: [for (var i = 1; i <= 12; i++) _post('a$i')],
        hasNext: true,
        nextCursor: 'c1',
      );
      svc.byCursor['c1'] = FeedPage(
        // a12 comes again: the list must not duplicate it.
        posts: [_post('a12'), _post('b1'), _post('b2')],
        hasNext: false,
      );
      return svc;
    }

    testWidgets(
      'reaching the end loads the next page once, without duplicates',
      (tester) async {
        final svc = paged();
        await _mount(tester, const SocialFeedTab(mode: 'FOLLOWING'), svc);
        expect(svc.calls, [(mode: 'FOLLOWING', cursor: null)]);

        await _scrollToEnd(tester);

        expect(
          svc.calls.where((c) => c.cursor == 'c1').length,
          1,
          reason: 'one request per cursor, never concurrent duplicates',
        );
        expect(find.text('contenido b2', skipOffstage: false), findsOneWidget);
        expect(find.text('contenido a12', skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a failed next page keeps the posts, offers retry and recovers',
      (tester) async {
        final svc = paged()..failMore = 1;
        await _mount(tester, const SocialFeedTab(mode: 'FOR_YOU'), svc);

        await _scrollToEnd(tester);

        expect(find.byKey(const ValueKey('feed_more_error')), findsOneWidget);
        expect(find.text('contenido a12', skipOffstage: false), findsOneWidget);
        // The feed is not replaced by an error / empty state.
        expect(find.text('No pudimos cargar el feed'), findsNothing);

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('feed_more_error')), findsNothing);
        expect(find.text('contenido b2', skipOffstage: false), findsOneWidget);
      },
    );

    testWidgets('pull to refresh restarts from the first page', (tester) async {
      final svc = paged();
      await _mount(tester, const SocialFeedTab(mode: 'FOR_YOU'), svc);
      svc.byCursor[null] = FeedPage(posts: [_post('fresh')], hasNext: false);

      await tester.fling(_list.first, const Offset(0, 500), 1000);
      await tester.pumpAndSettle();

      expect(svc.calls.where((c) => c.cursor == null).length, 2);
      expect(find.text('contenido fresh'), findsOneWidget);
      expect(find.text('contenido a1'), findsNothing);
    });

    testWidgets('coming back from a post only re-reads that post', (
      tester,
    ) async {
      final svc = paged()
        ..freshPost = _post('a1', comments: 9, content: 'contenido a1');
      await _mount(tester, const SocialFeedTab(mode: 'FOLLOWING'), svc);

      await tester.tap(find.text('contenido a1'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL a1'), findsOneWidget);
      await tester.tap(find.text('DETAIL a1'));
      await tester.pumpAndSettle();

      expect(svc.postReads, ['a1']);
      // No full reload: the first page was requested exactly once.
      expect(svc.calls.where((c) => c.cursor == null).length, 1);
      expect(find.text('contenido a1'), findsOneWidget);
    });

    testWidgets(
      'a post deleted while away disappears instead of staying dead',
      (tester) async {
        final svc = paged()
          ..postError = DioException(
            requestOptions: RequestOptions(path: '/x'),
            response: Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: 404,
            ),
          );
        await _mount(tester, const SocialFeedTab(mode: 'FOLLOWING'), svc);

        await tester.tap(find.text('contenido a1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('DETAIL a1'));
        await tester.pumpAndSettle();

        expect(find.text('contenido a1'), findsNothing);
        expect(find.text('contenido a2'), findsOneWidget);
      },
    );

    testWidgets('an offline return keeps what was on screen', (tester) async {
      final svc = paged()..postError = Exception('offline');
      await _mount(tester, const SocialFeedTab(mode: 'FOLLOWING'), svc);

      await tester.tap(find.text('contenido a1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DETAIL a1'));
      await tester.pumpAndSettle();

      expect(find.text('contenido a1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty Siguiendo orients instead of saying "no data"', (
      tester,
    ) async {
      await _mount(tester, const SocialFeedTab(mode: 'FOLLOWING'), _Svc());
      expect(find.text('Tu Garra empieza aqu\u00ed.'), findsOneWidget);
      expect(
        find.text('Descubre hinchas para llenar tu inicio.'),
        findsOneWidget,
      );
      expect(find.text('Buscar personas'), findsOneWidget);
    });

    for (final width in [220.0, 320.0]) {
      testWidgets('feed with a failed page fits ${width.toInt()} px', (
        tester,
      ) async {
        final svc = paged()..failMore = 1;
        await _mount(
          tester,
          const SocialFeedTab(mode: 'FOR_YOU'),
          svc,
          size: Size(width, 640),
          theme: AppTheme.darkTheme,
        );
        await _scrollToEnd(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('FOLLOW STATE CONSISTENCY', () {
    const bundle = DiscoveryBundle(
      people: [
        DiscoveryPerson(
          userId: 'fan-1',
          username: 'hincha_uno',
          displayName: 'Hincha Uno',
        ),
      ],
    );

    testWidgets('an unfollow made elsewhere is reflected in Discovery', (
      tester,
    ) async {
      final svc = _Svc(discovery: bundle);
      await _mount(tester, const GarraDiscoverySection(), svc);
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      expect(svc.followed, ['fan-1']);
      expect(find.text('Siguiendo'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GarraDiscoverySection)),
      );
      container.read(followStateProvider.notifier).report('fan-1', false);
      await tester.pumpAndSettle();

      expect(find.text('Seguir'), findsOneWidget);
      // ...and it can be followed again (the stale local flag no longer blocks it).
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      expect(svc.followed, ['fan-1', 'fan-1']);
    });

    Map<String, dynamic> profile(bool followed) => {
      'id': 'fan-9',
      'username': 'hincha_nueve',
      'displayName': 'Hincha Nueve',
      'profileVisibility': 'PUBLIC',
      'isFollowedByMe': followed,
      'followersCount': 2,
      'followingCount': 1,
    };

    testWidgets('following from a profile is reported to the other screens', (
      tester,
    ) async {
      final svc = _Svc()..profile = profile(false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connectivitySourceProvider.overrideWithValue(_Source())],
          child: MaterialApp(
            home: PublicFanProfilePage(
              userId: 'fan-9',
              communityService: svc,
              chatService: _Chat(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PublicFanProfilePage)),
      );

      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();

      expect(svc.followed, ['fan-9']);
      expect(container.read(followStateProvider)['fan-9'], isTrue);
    });

    testWidgets('a failed follow says so instead of failing silently', (
      tester,
    ) async {
      final svc = _Svc()
        ..profile = profile(false)
        ..failFollow = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connectivitySourceProvider.overrideWithValue(_Source())],
          child: MaterialApp(
            home: PublicFanProfilePage(
              userId: 'fan-9',
              communityService: svc,
              chatService: _Chat(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo actualizar el seguimiento'), findsOneWidget);
      expect(find.text('Seguir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SEARCH', () {
    Future<void> openSearch(WidgetTester tester, _Svc svc) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connectivitySourceProvider.overrideWithValue(_Source())],
          child: MaterialApp(home: GlobalSearchPage(service: svc)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no results names the query and the field can be cleared', (
      tester,
    ) async {
      await openSearch(tester, _Svc());
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(
        find.text('No encontramos resultados para \u201czzzz\u201d'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('search_clear')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(find.textContaining('No encontramos resultados'), findsNothing);
      expect(find.byKey(const ValueKey('search_clear')), findsNothing);
    });
  });

  group('NOTIFICATIONS', () {
    testWidgets('an empty inbox is calm, not "no data"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationServiceProvider.overrideWithValue(
              _EmptyNotifications(),
            ),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Todo tranquilo por ahora.'), findsOneWidget);
    });

    test('every social notification type has a real destination', () {
      const router = PushRouter();
      String route(String? ref, String id) => router.resolveRoute(
        authenticated: true,
        type: 'COMMUNITY',
        referenceType: ref,
        referenceId: id,
      );
      expect(route('FAN_USER', 'u1'), '/comunidad/u/u1'); // follow
      expect(
        route('POST', 'p1'),
        '/muro-crema/posts/p1',
      ); // comment / reaction / mention
      expect(
        route('POST_COMMENT:p1', 'c1'),
        '/muro-crema/posts/p1?commentId=c1',
      ); // reply / comment mention
      // Unknown or empty references fall back to the inbox, never to a dead route.
      expect(route('SOMETHING_NEW', 'x'), '/notifications');
      expect(route('POST', ''), '/notifications');
    });
  });
}

class _EmptyNotifications extends NotificationService {
  _EmptyNotifications() : super(dio: Dio());

  @override
  Future<NotificationsPage> getNotificationsPage({String? cursor, int size = 30}) async =>
      NotificationsPage(items: await getMyNotifications(size: size));

  @override
  Future<List<NotificationItem>> getMyNotifications({int size = 30}) async =>
      const [];
}

class _Chat extends ChatService {
  _Chat() : super(dio: Dio());

  @override
  Future<ChatRelationship> relationship(
    String userId, {
    String context = 'SOCIAL',
  }) async => ChatRelationship.none();
}
