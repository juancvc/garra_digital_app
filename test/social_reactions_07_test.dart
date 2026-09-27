import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/reactor_model.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_comment_tile.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/notifications/data/notification_service.dart';
import 'package:garra_digital_app/features/notifications/presentation/notifications_screen.dart';
import 'package:go_router/go_router.dart';

WallPostModel _post({int reactionCount = 2}) => WallPostModel(
  id: 'post-1',
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
  reactionCount: reactionCount,
  reactionSummary: reactionCount == 0 ? const {} : const {'FIRE': 1, 'GARRA': 1},
);

ReactorItem _reactor(String id, String type, {String? avatar}) => ReactorItem(
  fanId: id,
  username: 'user_$id',
  displayName: 'Hincha $id',
  avatarUrl: avatar,
  type: type,
);

class _Reactors extends CommunityService {
  _Reactors() : super(dio: Dio());

  final List<String> calls = [];

  @override
  Future<ReactorsPage> getPostReactors(
    String postId, {
    String? cursor,
    int size = 30,
  }) async {
    calls.add('post:$postId:${cursor ?? ''}');
    if (cursor == null) {
      return ReactorsPage(
        items: [_reactor('a', 'FIRE'), _reactor('b', 'GARRA')],
        hasNext: true,
        nextCursor: 'c2',
      );
    }
    return ReactorsPage(items: [_reactor('c', 'LOVE')]);
  }

  @override
  Future<ReactorsPage> getCommentReactors(
    String commentId, {
    String? cursor,
    int size = 30,
  }) async {
    calls.add('comment:$commentId');
    return ReactorsPage(items: [_reactor('d', 'LOVE')]);
  }
}

Future<_Reactors> _pumpRoutes(
  WidgetTester tester,
  Widget home, {
  ThemeData? theme,
}) async {
  final service = _Reactors();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: home)),
      GoRoute(
        path: '/comunidad/u/:id',
        builder: (_, state) =>
            Scaffold(body: Text('PROFILE:${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityServiceProvider.overrideWithValue(service)],
      child: MaterialApp.router(
        theme: theme ?? AppTheme.darkTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

Widget _card(WallPostModel post) => SingleChildScrollView(
  child: GarraSocialPostCard(post: post, onOpen: () {}),
);

void main() {
  group('REACTIONS_07 who reacted', () {
    testWidgets('card "Ver N reacciones" opens the reactors sheet', (
      tester,
    ) async {
      final service = await _pumpRoutes(tester, _card(_post()));
      expect(find.text('Ver 2 reacciones'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('post_reactors_post-1')));
      await tester.pumpAndSettle();

      expect(service.calls, ['post:post-1:']);
      expect(find.byKey(const ValueKey('reactors_sheet')), findsOneWidget);
      expect(find.text('Reacciones'), findsOneWidget);
      expect(find.text('Hincha a'), findsOneWidget);
      expect(find.text('@user_a'), findsOneWidget);
      expect(find.text('Hincha b'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reactor_type_a_FIRE')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reactor_type_b_GARRA')),
        findsOneWidget,
      );
    });

    testWidgets('no reactions: no reactors entry', (tester) async {
      await _pumpRoutes(tester, _card(_post(reactionCount: 0)));
      expect(find.byKey(const ValueKey('post_reactors_post-1')), findsNothing);
    });

    testWidgets('one reaction uses singular label', (tester) async {
      await _pumpRoutes(tester, _card(_post(reactionCount: 1)));
      expect(find.text('Ver 1 reacci\u00f3n'), findsOneWidget);
    });

    testWidgets('Ver mas loads the next cursor page', (tester) async {
      final service = await _pumpRoutes(tester, _card(_post()));
      await tester.tap(find.byKey(const ValueKey('post_reactors_post-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reactors_more')));
      await tester.pumpAndSettle();
      expect(service.calls, ['post:post-1:', 'post:post-1:c2']);
      expect(find.text('Hincha c'), findsOneWidget);
      expect(find.byKey(const ValueKey('reactors_more')), findsNothing);
    });

    testWidgets('tapping a reactor opens the public profile', (tester) async {
      await _pumpRoutes(tester, _card(_post()));
      await tester.tap(find.byKey(const ValueKey('post_reactors_post-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reactor_b')));
      await tester.pumpAndSettle();
      expect(find.text('PROFILE:b'), findsOneWidget);
      expect(find.byKey(const ValueKey('reactors_sheet')), findsNothing);
    });

    testWidgets('comment reaction summary opens comment reactors', (
      tester,
    ) async {
      final comment = WallCommentModel.fromJson({
        'id': 'c1',
        'postId': 'post-1',
        'username': 'ana',
        'fullName': 'Ana',
        'content': 'Buen post',
        'createdAt': '2026-09-26T12:00:00Z',
        'reactionCount': 1,
        'reactionSummary': {'LOVE': 1},
      });
      final service = await _pumpRoutes(
        tester,
        GarraCommentTile(comment: comment),
      );
      await tester.tap(find.byKey(const ValueKey('comment_reactors_c1')));
      await tester.pumpAndSettle();
      expect(service.calls, ['comment:c1']);
      expect(find.text('Hincha d'), findsOneWidget);
    });

    for (final entry in {
      'CREMA': (() => AppTheme.lightTheme, GarraSemanticColors.crema),
      'NOCHE': (() => AppTheme.darkTheme, GarraSemanticColors.noche),
    }.entries) {
      testWidgets('reactors sheet uses theme tokens (${entry.key})', (
        tester,
      ) async {
        final (theme, colors) = entry.value;
        await _pumpRoutes(tester, _card(_post()), theme: theme());
        await tester.tap(find.byKey(const ValueKey('post_reactors_post-1')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
        expect(sheet.backgroundColor, colors.surface);
        expect(
          tester.widget<Text>(find.text('Reacciones')).style?.color,
          colors.textPrimary,
        );
        expect(
          tester.widget<Text>(find.text('Hincha a')).style?.color,
          colors.textPrimary,
        );
        expect(
          tester.widget<Text>(find.text('@user_a')).style?.color,
          colors.textSecondary,
        );
      });
    }
  });

  group('REACTIONS_07 activity', () {
    testWidgets('reaction notification opens the post and marks it read', (
      tester,
    ) async {
      final service = _Notifications();
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
          GoRoute(
            path: '/muro-crema/posts/:id',
            builder: (_, state) =>
                Scaffold(body: Text('DETAIL:${state.pathParameters['id']}')),
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
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('@reactora reaccion\u00f3 a tu publicaci\u00f3n'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('notification_item_n1')));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL:post-9'), findsOneWidget);
      expect(service.markReadCalls, ['n1']);
      expect(homeLoads, greaterThanOrEqualTo(2));
    });
  });
}

class _Notifications extends NotificationService {
  _Notifications() : super(dio: Dio());

  final List<String> markReadCalls = [];

  @override
  Future<List<NotificationItem>> getMyNotifications({int size = 30}) async => [
    NotificationItem(
      id: 'n1',
      type: 'COMMUNITY',
      title: 'Nueva reacci\u00f3n',
      message: '@reactora reaccion\u00f3 a tu publicaci\u00f3n',
      referenceType: 'POST',
      referenceId: 'post-9',
      createdAt: DateTime.utc(2026, 9, 27, 15),
      read: markReadCalls.contains('n1'),
    ),
  ];

  @override
  Future<void> markRead(String id) async => markReadCalls.add(id);
}