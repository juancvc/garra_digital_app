import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_cached_network_image.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/engagement_utils.dart';
import 'package:garra_digital_app/features/community/data/reaction_result.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_post_media_grid.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';
import 'package:go_router/go_router.dart';

WallPostModel _post({
  String? myReaction,
  int reactionCount = 0,
  Map<String, int> reactionSummary = const {},
}) {
  return WallPostModel(
    id: 'post-1',
    username: 'crema',
    fullName: 'Hincha Crema',
    content: 'Vamos la U',
    imageUrl: null,
    locationTag: 'HOME',
    status: 'ACTIVE',
    reportCount: 0,
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 8))
        .toIso8601String(),
    myReaction: myReaction,
    reactionCount: reactionCount,
    reactionSummary: reactionSummary,
  );
}

List<WallPostMediaItem> _media(int count) => List.generate(
  count,
  (index) => WallPostMediaItem(
    id: '$index',
    url: 'https://example.invalid/image-$index.jpg',
    sortOrder: index,
  ),
);

class _FakeCommunityService extends CommunityService {
  _FakeCommunityService(this.post) : super(dio: Dio());

  WallPostModel post;
  final List<String> reactionCalls = [];

  @override
  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async {
    return [post];
  }

  @override
  Future<ReactionResult> upsertReaction({
    required String postId,
    required String type,
  }) async {
    reactionCalls.add('upsert:$type');
    post = applyOptimisticReaction(post, type);
    return ReactionResult.success(
      message: 'ok',
      myReaction: post.myReaction,
      reactionSummary: post.reactionSummary,
      reactionCount: post.reactionCount,
    );
  }
}

class _FakeCurrentFanNotifier extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

void main() {
  group('GarraPostMediaGrid narrow layouts', () {
    for (final count in [1, 2, 3, 4]) {
      testWidgets('$count image layout stays constrained', (tester) async {
        await tester.binding.setSurfaceSize(const Size(280, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: GarraPostMediaGrid(media: _media(count))),
          ),
        );

        final size = tester.getSize(find.byType(GarraPostMediaGrid));
        final expectedHeight = switch (count) {
          1 => 210.0,
          2 => 157.5,
          3 => 210.0,
          _ => 280.0,
        };
        expect(size.width, 280);
        expect(size.height, expectedHeight);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('cached image shows placeholder and empty-url fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: GarraCachedNetworkImage(
            imageUrl: 'https://example.invalid/pending.jpg',
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('garra_cached_image_placeholder')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const MaterialApp(home: GarraCachedNetworkImage(imageUrl: '')),
    );
    expect(
      find.byKey(const ValueKey('garra_cached_image_error')),
      findsOneWidget,
    );
  });

  test('relative timestamp uses compact Spanish labels', () {
    final now = DateTime(2026, 9, 22, 13);
    expect(
      formatGarraRelativeTime(
        now.subtract(const Duration(minutes: 12)).toIso8601String(),
        now: now,
      ),
      'hace 12 min',
    );
  });

  testWidgets('social card wires reaction and comment actions', (tester) async {
    var reactions = 0;
    var comments = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraSocialPostCard(
            post: _post(),
            onOpen: () {},
            onReact: () => reactions++,
            onComment: () => comments++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Reaccionar'));
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    expect(reactions, 1);
    expect(comments, 1);
  });

  testWidgets('Home feed picker upserts selected reaction', (tester) async {
    final service = _FakeCommunityService(_post());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: SocialFeedTab(mode: 'FOR_YOU')),
        ),
        GoRoute(
          path: '/muro-crema/posts/:id',
          builder: (_, _) => const Scaffold(body: Text('DETAIL')),
        ),
        GoRoute(
          path: '/comunidad/compose',
          builder: (_, _) => const Scaffold(body: Text('COMPOSE')),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityServiceProvider.overrideWithValue(service),
          currentFanProvider.overrideWith(_FakeCurrentFanNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reaccionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reaction_option_FIRE')));
    await tester.pumpAndSettle();

    expect(service.reactionCalls, ['upsert:FIRE']);
    expect(find.text('🔥'), findsWidgets);
  });
}
