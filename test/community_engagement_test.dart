import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/engagement_utils.dart';
import 'package:garra_digital_app/features/community/data/reaction_result.dart';
import 'package:garra_digital_app/features/community/data/reaction_type.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reaction_bar.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reaction_picker.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:go_router/go_router.dart';

WallPostModel samplePost({
  String id = 'post-1',
  Map<String, int>? reactionSummary,
  int reactionCount = 0,
  int commentCount = 0,
  String? myReaction,
  String content = 'Vamos la U',
}) {
  return WallPostModel(
    id: id,
    matchId: 'm1',
    username: 'cremafan',
    fullName: 'Hincha Crema',
    content: content,
    imageUrl: null,
    locationTag: 'STADIUM',
    status: 'ACTIVE',
    reportCount: 0,
    createdAt: DateTime.now().toIso8601String(),
    reactionSummary: reactionSummary ?? emptyReactionSummary(),
    reactionCount: reactionCount,
    commentCount: commentCount,
    myReaction: myReaction,
  );
}

HomeModel sampleHomeWithEngagement() {
  return HomeModel(
    fan: const HomeFanSummary(
      displayName: 'Hincha Crema',
      username: 'cremafan',
      levelNumber: 2,
      levelName: 'Hincha Fiel',
      points: 1840,
      globalRank: 428,
    ),
    matchdayState: 'UPCOMING',
    match: HomeMatch(
      id: 'm1',
      homeTeam: 'Universitario',
      awayTeam: 'Rival FC',
      matchDateTime: DateTime.now().add(const Duration(hours: 5)),
      stadium: 'Monumental',
      competition: 'Liga 1',
      status: 'OPEN_FOR_PREDICTION',
      matchdayState: 'UPCOMING',
    ),
    prediction: const HomePrediction(
      state: 'NOT_PREDICTED',
      matchId: 'm1',
      predictionsOpen: true,
    ),
    checkIn: const HomeCheckIn(
      showCheckInCta: false,
      hasActiveStadiumPoint: true,
      recentlyCheckedIn: false,
    ),
    community: HomeCommunityPreview(
      matchId: 'm1',
      posts: [
        HomeCommunityPost(
          id: 'p1',
          username: 'cremafan',
          displayName: 'Hincha Crema',
          content: 'Vamos la U',
          locationTag: 'HOME',
          createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
          reactionSummary: const {'FIRE': 4, 'LIKE': 2},
          reactionCount: 6,
          commentCount: 3,
          myReaction: 'FIRE',
        ),
      ],
    ),
    notifications: const HomeNotifications(unreadCount: 0),
  );
}

class FakeCommunityService extends CommunityService {
  FakeCommunityService({
    this.post,
    List<WallCommentModel>? comments,
    this.failReaction = false,
    this.failComment = false,
    this.hasNextPage = false,
  })  : comments = comments ?? <WallCommentModel>[],
        super(dio: Dio());

  WallPostModel? post;
  List<WallCommentModel> comments;
  bool failReaction;
  bool failComment;
  bool hasNextPage;
  int listCalls = 0;
  final List<String> reactionCalls = [];
  final List<String> createdComments = [];

  @override
  Future<WallPostModel> getPost(String postId) async {
    final p = post;
    if (p == null) {
      throw Exception('not found');
    }
    return p;
  }

  @override
  Future<ReactionResult> upsertReaction({
    required String postId,
    required String type,
  }) async {
    reactionCalls.add('upsert:$type');
    if (failReaction) {
      return ReactionResult.failure('falló');
    }
    final current = post ?? samplePost(id: postId);
    final updated = applyOptimisticReaction(current, type);
    post = updated;
    return ReactionResult.success(
      message: 'ok',
      myReaction: updated.myReaction,
      reactionSummary: updated.reactionSummary,
      reactionCount: updated.reactionCount,
    );
  }

  @override
  Future<ReactionResult> removeReaction(String postId) async {
    reactionCalls.add('remove');
    if (failReaction) {
      return ReactionResult.failure('falló');
    }
    final current = post ?? samplePost(id: postId);
    final updated = applyOptimisticReaction(current, null);
    post = updated;
    return ReactionResult.success(
      message: 'ok',
      myReaction: null,
      reactionSummary: updated.reactionSummary,
      reactionCount: updated.reactionCount,
    );
  }

  @override
  Future<CommentsPageResult> listComments({
    required String postId,
    String? cursor,
    int size = 20,
  }) async {
    listCalls += 1;
    if (cursor == null) {
      final pageSize = hasNextPage ? 1 : size;
      final first = comments.take(pageSize).toList();
      final more = hasNextPage && comments.length > first.length;
      return CommentsPageResult(
        items: first,
        size: pageSize,
        hasNext: more,
        nextCursor: more ? 'c2' : null,
      );
    }
    return CommentsPageResult(
      items: comments.skip(1).toList(),
      size: size,
      hasNext: false,
      nextCursor: null,
    );
  }

  @override
  Future<CommentActionResult> createComment({
    required String postId,
    required String content,
  }) async {
    if (failComment) {
      return CommentActionResult.failure('No se pudo publicar el comentario');
    }
    createdComments.add(content);
    final comment = WallCommentModel(
      id: 'c-${createdComments.length}',
      postId: postId,
      username: 'cremafan',
      fullName: 'Hincha Crema',
      content: content,
      createdAt: DateTime.now().toIso8601String(),
      isMine: true,
    );
    comments = [comment, ...comments];
    return CommentActionResult.success(
      message: 'Comentario publicado',
      comment: comment,
    );
  }
}

Widget pumpDetail(FakeCommunityService fake) {
  return ProviderScope(
    overrides: [
      communityServiceProvider.overrideWith((ref) => fake),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: PostDetailScreen(postId: fake.post?.id ?? 'post-1'),
    ),
  );
}

void main() {
  test('WallPostModel parses engagement defaults safely', () {
    final post = WallPostModel.fromJson({
      'id': '1',
      'matchId': 'm',
      'username': 'u',
      'fullName': 'F',
      'content': 'hola',
      'locationTag': 'HOME',
      'status': 'ACTIVE',
      'createdAt': '2026-01-01T00:00:00Z',
    });
    expect(post.reactionCount, 0);
    expect(post.commentCount, 0);
    expect(post.myReaction, isNull);
    expect(post.reactionSummary['LIKE'], 0);
    expect(post.reactionSummary['GARRA'], 0);
  });

  testWidgets('REACTION_BAR_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraReactionBar(
            reactionSummary: const {
              'FIRE': 5,
              'LIKE': 2,
              'LOVE': 0,
              'ANGER': 0,
              'SAD': 0,
              'GARRA': 1,
            },
            reactionCount: 8,
            commentCount: 4,
            myReaction: 'FIRE',
          ),
        ),
      ),
    );

    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.textContaining('🔥'), findsWidgets);
  });

  testWidgets('REACTION_PICKER_OPTIONS', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: GarraReactionPicker(),
        ),
      ),
    );

    expect(find.text('Me gusta'), findsOneWidget);
    expect(find.text('Me encanta'), findsOneWidget);
    expect(find.text('Está que arde'), findsOneWidget);
    expect(find.text('Me enoja'), findsOneWidget);
    expect(find.text('Me entristece'), findsOneWidget);
    expect(find.text('Garra'), findsOneWidget);
    expect(find.byKey(const ValueKey('reaction_option_LIKE')), findsOneWidget);
    expect(find.byKey(const ValueKey('reaction_option_GARRA')), findsOneWidget);
  });

  test('REACTION_SELECT', () {
    final post = samplePost();
    final next = applyOptimisticReaction(post, 'FIRE');
    expect(next.myReaction, 'FIRE');
    expect(next.reactionCount, 1);
    expect(next.reactionSummary['FIRE'], 1);
  });

  test('REACTION_CHANGE', () {
    final post = samplePost(
      myReaction: 'LIKE',
      reactionCount: 3,
      reactionSummary: {
        ...emptyReactionSummary(),
        'LIKE': 2,
        'FIRE': 1,
      },
    );
    final next = applyOptimisticReaction(post, 'FIRE');
    expect(next.myReaction, 'FIRE');
    expect(next.reactionCount, 3);
    expect(next.reactionSummary['LIKE'], 1);
    expect(next.reactionSummary['FIRE'], 2);
  });

  test('REACTION_REMOVE', () {
    final post = samplePost(
      myReaction: 'FIRE',
      reactionCount: 2,
      reactionSummary: {
        ...emptyReactionSummary(),
        'FIRE': 2,
      },
    );
    final next = applyOptimisticReaction(post, 'FIRE');
    expect(next.myReaction, isNull);
    expect(next.reactionCount, 1);
    expect(next.reactionSummary['FIRE'], 1);
  });

  testWidgets('REACTION_OPTIMISTIC_ROLLBACK', (tester) async {
    final fake = FakeCommunityService(
      post: samplePost(reactionCount: 0),
      failReaction: true,
    );

    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(pumpDetail(fake));
    await tester.pumpAndSettle();

    expect(find.text('Reaccionar'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('reaction_cta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reaction_option_FIRE')));
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo actualizar la reacción. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Reaccionar'), findsWidgets);
  });

  testWidgets('POST_DETAIL_RENDER', (tester) async {
    final fake = FakeCommunityService(
      post: samplePost(
        content: 'Arenga de detalle',
        reactionCount: 2,
        commentCount: 0,
        reactionSummary: {
          ...emptyReactionSummary(),
          'LIKE': 2,
        },
      ),
    );

    await tester.pumpWidget(pumpDetail(fake));
    await tester.pumpAndSettle();

    expect(find.text('Arenga de detalle'), findsOneWidget);
    expect(find.text('Hincha Crema'), findsOneWidget);
    expect(find.text('Comentarios'), findsOneWidget);
    expect(find.byType(GarraReactionBar), findsOneWidget);
  });

  testWidgets('COMMENT_EMPTY_STATE', (tester) async {
    final fake = FakeCommunityService(
      post: samplePost(commentCount: 0),
      comments: const [],
    );

    await tester.pumpWidget(pumpDetail(fake));
    await tester.pumpAndSettle();

    expect(find.byType(GarraEmptyState), findsOneWidget);
    expect(find.text('Aún no hay comentarios'), findsOneWidget);
  });

  testWidgets('COMMENT_SEND', (tester) async {
    final fake = FakeCommunityService(
      post: samplePost(commentCount: 0),
      comments: const [],
    );

    await tester.pumpWidget(pumpDetail(fake));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('comment_composer')),
      'Grande la U',
    );
    await tester.tap(find.byKey(const ValueKey('comment_send')));
    await tester.pumpAndSettle();

    expect(fake.createdComments, ['Grande la U']);
    expect(find.text('Grande la U'), findsOneWidget);
    expect(find.text('Comentario publicado'), findsOneWidget);
  });

  testWidgets('COMMENT_VALIDATION', (tester) async {
    final fake = FakeCommunityService(
      post: samplePost(commentCount: 0),
      comments: const [],
    );

    await tester.pumpWidget(pumpDetail(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('comment_send')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un comentario antes de enviar.'), findsOneWidget);
    expect(fake.createdComments, isEmpty);
  });

  testWidgets('COMMENT_PAGINATION', (tester) async {
    final fake = FakeCommunityService(
      post: samplePost(commentCount: 2),
      hasNextPage: true,
      comments: [
        WallCommentModel(
          id: 'c1',
          postId: 'post-1',
          username: 'a',
          fullName: 'Usuario A',
          content: 'Primero',
          createdAt: DateTime.now().toIso8601String(),
        ),
        WallCommentModel(
          id: 'c2',
          postId: 'post-1',
          username: 'b',
          fullName: 'Usuario B',
          content: 'Segundo',
          createdAt: DateTime.now().toIso8601String(),
        ),
      ],
    );

    await tester.pumpWidget(pumpDetail(fake));
    await tester.pumpAndSettle();

    expect(find.text('Primero'), findsOneWidget);
    expect(find.text('Segundo'), findsNothing);
    expect(find.text('Cargar más'), findsOneWidget);

    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();

    expect(find.text('Segundo'), findsOneWidget);
    expect(fake.listCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('HOME_PREVIEW_ENGAGEMENT', (tester) async {
    // V1: engagement lives in the social feed (Para ti), not a Home dashboard preview.
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/muro-crema/posts/:id',
          builder: (context, state) => Scaffold(
            body: Text('DETAIL_${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/muro-crema',
          builder: (context, state) => const Scaffold(body: Text('MURO')),
        ),
        GoRoute(
          path: '/comunidad/compose',
          builder: (context, state) => const Scaffold(body: Text('COMPOSE')),
        ),
        GoRoute(
          path: '/comunidad/buscar',
          builder: (context, state) => const Scaffold(body: Text('SEARCH')),
        ),
        GoRoute(
          path: '/passport',
          builder: (context, state) => const Scaffold(body: Text('P')),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const Scaffold(body: Text('N')),
        ),
        GoRoute(
          path: '/polla',
          builder: (context, state) => const Scaffold(body: Text('PO')),
        ),
        GoRoute(
          path: '/mapa-crema',
          builder: (context, state) => const Scaffold(body: Text('M')),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('L')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProvider.overrideWith((ref) async {
            return HomeModel(
              fan: const HomeFanSummary(
                displayName: 'Hincha Crema',
                username: 'cremafan',
                levelNumber: 2,
                levelName: 'Hincha Fiel',
                points: 1840,
                globalRank: 428,
              ),
              matchdayState: 'NO_MATCH',
              match: null,
              prediction: const HomePrediction(
                state: 'NONE',
                predictionsOpen: false,
              ),
              checkIn: const HomeCheckIn(
                showCheckInCta: false,
                hasActiveStadiumPoint: false,
                recentlyCheckedIn: false,
              ),
              community: const HomeCommunityPreview(posts: []),
              notifications: const HomeNotifications(unreadCount: 0),
            );
          }),
        ],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Para ti'), findsOneWidget);
    expect(find.text('¿Qué vive la crema hoy?'), findsOneWidget);
  });
}
