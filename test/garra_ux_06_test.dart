import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/core/widgets/garra_cached_network_image.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';
import 'package:garra_digital_app/features/notifications/data/notification_service.dart';
import 'package:garra_digital_app/features/notifications/presentation/notifications_screen.dart';
import 'package:go_router/go_router.dart';

const _viewer = ValueKey('garra_media_viewer');

WallPostModel _post({
  String id = 'post-1',
  int commentCount = 0,
  bool withPhoto = true,
}) {
  return WallPostModel(
    id: id,
    username: 'crema',
    fullName: 'Hincha Crema',
    content: 'Vamos la U',
    imageUrl: null,
    locationTag: 'HOME',
    status: 'ACTIVE',
    reportCount: 0,
    createdAt: DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 8))
        .toIso8601String(),
    commentCount: commentCount,
    media: withPhoto
        ? const [
            WallPostMediaItem(
              id: 'm0',
              url: 'https://example.invalid/photo-0.jpg',
              sortOrder: 0,
            ),
          ]
        : const [],
  );
}

Widget _card(
  WallPostModel post, {
  VoidCallback? onOpen,
  VoidCallback? onComment,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.darkTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: GarraSocialPostCard(
          post: post,
          onOpen: onOpen ?? () {},
          onComment: onComment,
        ),
      ),
    ),
  );
}

class _Fan extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _FeedService extends CommunityService {
  _FeedService(this.posts) : super(dio: Dio());
  final List<WallPostModel> posts;

  @override
  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async =>
      posts;
}

class _ProfileCommunity extends CommunityService {
  _ProfileCommunity(this.profile) : super(dio: Dio());
  final Map<String, dynamic> profile;

  @override
  Future<Map<String, dynamic>> getPublicProfile(String userId) async => profile;
}

class _Chat extends ChatService {
  _Chat() : super(dio: Dio());

  @override
  Future<ChatRelationship> relationship(
    String userId, {
    String context = 'SOCIAL',
  }) async => ChatRelationship.none();
}

Map<String, dynamic> _wallPostJson(String id, int comments) => {
  'id': id,
  'username': 'anaq',
  'fullName': 'Ana Quispe',
  'content': 'Post $id de Ana',
  'status': 'PUBLISHED',
  'createdAt': '2026-09-24T12:00:00Z',
  'reactionCount': 0,
  'commentCount': comments,
  'media': [
    {
      'id': 'a-$id',
      'mediaAssetId': 'asset-$id',
      'url': 'https://example.invalid/$id.jpg',
      'sortOrder': 0,
    },
  ],
};

Map<String, dynamic> _profileJson() => {
  'id': 'fan-ana',
  'username': 'anaq',
  'displayName': 'Ana Quispe',
  'avatarUrl': null,
  'levelNumber': 3,
  'levelName': 'Hincha Fiel',
  'memberSince': '2025-03-14T15:00:00Z',
  'followerCount': 1,
  'followingCount': 2,
  'globalPostCount': 2,
  'isFollowedByMe': false,
  'isBlockedByMe': false,
  'isMe': false,
  'globalPosts': [_wallPostJson('p1', 0), _wallPostJson('p2', 3)],
};

class _Notifications extends NotificationService {
  _Notifications({this.failMarkAll = false}) : super(dio: Dio());

  final bool failMarkAll;
  final Set<String> readIds = {};
  final List<String> markReadCalls = [];
  int loads = 0;
  int markAllCalls = 0;

  @override
  Future<List<NotificationItem>> getMyNotifications({int size = 30}) async {
    loads++;
    return [
      for (final id in ['n1', 'n2'])
        NotificationItem(
          id: id,
          type: 'SYSTEM',
          title: 'Aviso $id',
          message: 'Mensaje $id',
          createdAt: DateTime.utc(2026, 9, 26, 12),
          read: readIds.contains(id),
        ),
    ];
  }

  @override
  Future<void> markRead(String id) async {
    markReadCalls.add(id);
    readIds.add(id);
  }

  @override
  Future<void> markAllRead() async {
    markAllCalls++;
    if (failMarkAll) throw Exception('network down');
    readIds.addAll(['n1', 'n2']);
  }
}

Future<int Function()> _pumpNotifications(
  WidgetTester tester,
  _Notifications service, {
  ThemeData? theme,
}) async {
  var homeLoads = 0;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Stack(
          children: [
            const NotificationsScreen(),
            // Stands in for the Home bell, which watches homeProvider.
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
    errorBuilder: (_, state) => Scaffold(body: Text('route:${state.uri}')),
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

void main() {
  group('UX_06 photo viewer', () {
    testWidgets('tapping a post photo opens the viewer, not the detail', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(_card(_post(), onOpen: () => opened++));
      await tester.tap(find.byKey(const ValueKey('post_media_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(_viewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(opened, 0);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(_viewer), findsNothing);
    });

    testWidgets('viewer opens on the root navigator (above bottom nav)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: SingleChildScrollView(
                    child: GarraSocialPostCard(post: _post(), onOpen: () {}),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: const Text('NAVBAR'),
          ),
        ),
      );
      expect(find.text('NAVBAR'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('post_media_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(_viewer), findsOneWidget);
      expect(find.text('NAVBAR'), findsNothing);
    });

    testWidgets('photo viewer opens the matching post and Back returns to feed', (
      tester,
    ) async {
      final post = _post(id: 'post-photo');
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: GarraSocialPostCard(
                  post: post,
                  onOpen: () => context.push('/muro-crema/posts/${post.id}'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/muro-crema/posts/:id',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('DETAIL:${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ));

      await tester.tap(find.byKey(const ValueKey('post_media_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(_viewer), findsOneWidget);
      expect(find.text('Ver publicación'), findsOneWidget);
      final image = tester.widget<GarraCachedNetworkImage>(
        find.descendant(
          of: find.byKey(_viewer),
          matching: find.byType(GarraCachedNetworkImage),
        ).first,
      );
      expect(image.imageUrl, 'https://example.invalid/photo-0.jpg');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(_viewer), findsNothing);
      expect(find.text('Vamos la U'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('post_media_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('viewer_view_post')));
      await tester.pumpAndSettle();
      expect(find.byKey(_viewer), findsNothing);
      expect(find.text('DETAIL:post-photo'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Vamos la U'), findsOneWidget);
      expect(find.byKey(_viewer), findsNothing);

      await tester.tap(find.text('Vamos la U'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL:post-photo'), findsOneWidget);
    });

    testWidgets('multiple photos still swipe in the fullscreen viewer', (
      tester,
    ) async {
      final post = _post().copyWith(media: const [
        WallPostMediaItem(id: 'm0', url: 'https://example.invalid/photo-0.jpg', sortOrder: 0),
        WallPostMediaItem(id: 'm1', url: 'https://example.invalid/photo-1.jpg', sortOrder: 1),
      ]);
      await tester.pumpWidget(_card(post));
      await tester.tap(find.byKey(const ValueKey('post_media_0')));
      await tester.pumpAndSettle();
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.controller!.page, 0);
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(pageView.controller!.page, 1);
      expect(find.text('Ver publicación'), findsOneWidget);
    });
  });

  group('UX_06 comments navigation', () {
    testWidgets('comment icon with 0 comments opens the detail', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        _card(_post(withPhoto: false), onOpen: () => opened++),
      );
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('comment icon prefers onComment; Ver N comentarios opens', (
      tester,
    ) async {
      var opened = 0;
      var commented = 0;
      await tester.pumpWidget(
        _card(
          _post(withPhoto: false, commentCount: 2),
          onOpen: () => opened++,
          onComment: () => commented++,
        ),
      );
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pump();
      expect((commented, opened), (1, 0));
      await tester.tap(find.text('· 0 compartidos'));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('UX_06 profile posts', () {
    Future<void> pumpProfile(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => PublicFanProfilePage(
              userId: 'fan-ana',
              communityService: _ProfileCommunity(_profileJson()),
              chatService: _Chat(),
            ),
          ),
          GoRoute(
            path: '/muro-crema/posts/:id',
            builder: (_, state) =>
                Scaffold(body: Text('DETAIL:${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('profile post shows photo + comments and opens detail', (
      tester,
    ) async {
      await pumpProfile(tester);
      expect(find.byKey(const Key('profile-post-p1')), findsOneWidget);
      expect(find.text('Comentar'), findsNWidgets(2));
      expect(find.text('3 comentarios'), findsOneWidget);

      await tester.tap(find.text('Post p1 de Ana'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL:p1'), findsOneWidget);
    });

    testWidgets('profile comments button opens that post detail', (
      tester,
    ) async {
      await pumpProfile(tester);
      await tester.tap(find.descendant(
        of: find.byKey(const Key('profile-post-p2')),
        matching: find.text('Comentar'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL:p2'), findsOneWidget);
    });

    testWidgets('profile post photo opens the viewer', (tester) async {
      await pumpProfile(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('profile-post-p2')),
          matching: find.byKey(const ValueKey('post_media_0')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_viewer), findsOneWidget);
      expect(find.textContaining('DETAIL'), findsNothing);
    });
  });

  group('UX_06 activity badge', () {
    testWidgets('tapping an unread item marks it read and refreshes badge', (
      tester,
    ) async {
      final service = _Notifications();
      final homeLoads = await _pumpNotifications(tester, service);
      expect((service.loads, homeLoads()), (1, 1));

      await tester.tap(find.byKey(const ValueKey('notification_item_n1')));
      await tester.pumpAndSettle();

      expect(service.markReadCalls, ['n1']);
      expect(service.loads, 2);
      expect(homeLoads(), 2);

      // Already read: no second PATCH.
      await tester.tap(find.byKey(const ValueKey('notification_item_n1')));
      await tester.pumpAndSettle();
      expect(service.markReadCalls, ['n1']);
    });

    testWidgets('Marcar leidas marks all and refreshes the badge', (
      tester,
    ) async {
      final service = _Notifications();
      final homeLoads = await _pumpNotifications(tester, service);
      await tester.tap(find.byKey(const ValueKey('notifications_mark_all')));
      await tester.pumpAndSettle();
      expect(service.markAllCalls, 1);
      expect(service.loads, 2);
      expect(homeLoads(), 2);
    });

    testWidgets('Marcar leidas failure keeps badge and shows an error', (
      tester,
    ) async {
      final service = _Notifications(failMarkAll: true);
      final homeLoads = await _pumpNotifications(tester, service);
      await tester.tap(find.byKey(const ValueKey('notifications_mark_all')));
      await tester.pumpAndSettle();
      expect(service.markAllCalls, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(service.loads, 1);
      expect(homeLoads(), 1);
    });
  });

  group('UX_06 Crema / Noche surfaces', () {
    for (final entry in {
      'CREMA': (() => AppTheme.lightTheme, GarraSemanticColors.crema),
      'NOCHE': (() => AppTheme.darkTheme, GarraSemanticColors.noche),
    }.entries) {
      testWidgets('Activity background uses theme (${entry.key})', (
        tester,
      ) async {
        final (theme, colors) = entry.value;
        await _pumpNotifications(tester, _Notifications(), theme: theme());
        final scaffold = tester.widget<Scaffold>(
          find.descendant(
            of: find.byType(NotificationsScreen),
            matching: find.byType(Scaffold),
          ),
        );
        expect(scaffold.backgroundColor, colors.background);
      });

      testWidgets('Home composer + post card use tokens (${entry.key})', (
        tester,
      ) async {
        final (theme, colors) = entry.value;
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              communityServiceProvider.overrideWithValue(
                _FeedService([_post(withPhoto: false)]),
              ),
              currentFanProvider.overrideWith(_Fan.new),
            ],
            child: MaterialApp(
              theme: theme(),
              home: const Scaffold(body: SocialFeedTab(mode: 'FOR_YOU')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final composer = tester.widget<Material>(
          find
              .ancestor(
                of: find.textContaining('vive la crema hoy'),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(composer.color, colors.surface);
        final hint = tester.widget<Text>(
          find.textContaining('vive la crema hoy'),
        );
        expect(hint.style?.color, colors.textSecondary);
        final borders = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(GarraSocialPostCard),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.border)
            .whereType<Border>()
            .map((b) => b.bottom.color);
        expect(borders, contains(colors.border));
      });
    }
  });
}
