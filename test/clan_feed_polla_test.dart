import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/features/clans/data/clan_models.dart';
import 'package:garra_digital_app/features/clans/data/clan_service.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_polla_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_ranking_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_tribuna_page.dart';
import 'package:garra_digital_app/features/clans/presentation/providers/clans_provider.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reaction_bar.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:go_router/go_router.dart';

ClanModel memberClan({
  String slug = 'garra-surco',
  String name = 'Garra Surco',
}) {
  return ClanModel(
    id: 'clan-1',
    slug: slug,
    name: name,
    description: 'Comunidad crema',
    city: 'Lima',
    countryCode: 'PE',
    visibility: 'PUBLIC',
    joinPolicy: 'OPEN',
    status: 'ACTIVE',
    memberCount: 120,
    myMembership: const ClanMembershipSummary(
      role: 'MEMBER',
      status: 'ACTIVE',
    ),
    currentYearPollaPoints: 42,
    currentYearRank: 3,
  );
}

WallPostModel sampleClanPost({
  String id = 'post-1',
  String content = 'Vamos la U desde la tribuna del clan',
}) {
  return WallPostModel(
    id: id,
    matchId: '',
    username: 'cremafan',
    fullName: 'Hincha Crema',
    content: content,
    imageUrl: null,
    locationTag: 'HOME',
    status: 'ACTIVE',
    reportCount: 0,
    createdAt: DateTime(2026, 9, 20).toIso8601String(),
    reactionSummary: const {'LIKE': 2},
    reactionCount: 2,
    commentCount: 1,
    myReaction: null,
    contextType: 'CLAN',
    clanSlug: 'garra-surco',
    clanName: 'Garra Surco',
  );
}

ClanPollaMatchModel samplePolla({
  String state = 'OPEN',
  List<ClanPollaMemberPrediction> members = const [],
  ClanPollaPrediction? myPrediction,
  bool revealed = false,
}) {
  return ClanPollaMatchModel(
    match: const ClanPollaMatchInfo(
      id: 'match-1',
      homeTeam: 'Universitario',
      awayTeam: 'Alianza Lima',
      competition: 'Liga 1',
    ),
    state: state,
    memberCount: 120,
    participantCount: 67,
    participationPercent: 55.8,
    myPrediction: myPrediction ??
        const ClanPollaPrediction(homeScore: 2, awayScore: 1),
    memberPredictions: members,
    predictionsRevealed: revealed,
    scoredSummary: state == 'SCORED'
        ? const ClanPollaScoredSummary(totalClanPoints: 88, participants: 67)
        : null,
    year: 2026,
  );
}

class FakeClanFeedService extends ClanService {
  FakeClanFeedService({
    ClanModel? detail,
    List<WallPostModel>? posts,
    ClanPollaMatchModel? polla,
    List<ClanMemberRankingEntry>? memberRanking,
    List<ClanGlobalRankingEntry>? globalRanking,
    this.throwMembershipLostOnFeed = false,
    this.throwMembershipLostOnPolla = false,
  })  : detail = detail ?? memberClan(),
        posts = posts ?? const [],
        polla = polla ?? samplePolla(),
        memberRanking = memberRanking ?? const [],
        globalRanking = globalRanking ?? const [],
        super(dio: Dio(BaseOptions(baseUrl: 'http://localhost')));

  ClanModel detail;
  List<WallPostModel> posts;
  ClanPollaMatchModel polla;
  List<ClanMemberRankingEntry> memberRanking;
  List<ClanGlobalRankingEntry> globalRanking;
  bool throwMembershipLostOnFeed;
  bool throwMembershipLostOnPolla;
  int createPostCalls = 0;
  String? lastCreatedContent;

  @override
  Future<ClanModel> getClan(String slug) async => detail;

  @override
  Future<ClanPage<WallPostModel>> getClanPosts(
    String slug, {
    String? cursor,
    int size = 20,
  }) async {
    if (throwMembershipLostOnFeed) throw ClanMembershipLostException();
    return ClanPage(items: posts);
  }

  @override
  Future<WallPostModel> createClanPost(
    String slug,
    CreateClanPostRequest request,
  ) async {
    createPostCalls++;
    lastCreatedContent = request.content;
    final post = sampleClanPost(
      id: 'post-${posts.length + 1}',
      content: request.content,
    );
    posts = [...posts, post];
    return post;
  }

  @override
  Future<ClanPollaMatchModel> getClanPolla(String slug, String matchId) async {
    if (throwMembershipLostOnPolla) throw ClanMembershipLostException();
    return polla;
  }

  @override
  Future<ClanPage<ClanMemberRankingEntry>> getClanMemberRanking(
    String slug, {
    int? year,
    String? cursor,
    int size = 20,
  }) async {
    return ClanPage(items: memberRanking);
  }

  @override
  Future<ClanPage<ClanGlobalRankingEntry>> getGlobalClanRanking({
    int? year,
    String? cursor,
    int size = 20,
  }) async {
    return ClanPage(items: globalRanking);
  }
}

class FakeCommunityEngagementService extends CommunityService {
  FakeCommunityEngagementService()
      : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost')));

  WallPostModel? post;
  Object? postError;

  @override
  Future<WallPostModel> getPost(String postId) async {
    if (postError != null) throw postError!;
    return post ?? sampleClanPost(id: postId);
  }

  @override
  Future<CommentsPageResult> listComments({
    required String postId,
    String? cursor,
    int size = 20,
  }) async {
    return const CommentsPageResult(items: [], size: 0, hasNext: false);
  }
}

HomeModel sampleHomeWithMatch() {
  return HomeModel(
    fan: const HomeFanSummary(
      displayName: 'Hincha Crema',
      username: 'cremafan',
      levelNumber: 2,
      levelName: 'Hincha Fiel',
      points: 100,
      globalRank: 10,
    ),
    matchdayState: 'UPCOMING',
    match: HomeMatch(
      id: 'match-1',
      homeTeam: 'Universitario',
      awayTeam: 'Alianza Lima',
      matchDateTime: DateTime(2026, 9, 21),
      stadium: 'Monumental',
      competition: 'Liga 1',
      status: 'SCHEDULED',
      matchdayState: 'UPCOMING',
    ),
    prediction: const HomePrediction(
      state: 'NOT_PREDICTED',
      predictionsOpen: true,
    ),
    checkIn: const HomeCheckIn(
      showCheckInCta: false,
      hasActiveStadiumPoint: false,
      recentlyCheckedIn: false,
    ),
    community: const HomeCommunityPreview(posts: []),
    notifications: const HomeNotifications(unreadCount: 0),
  );
}

Widget pumpTribuna(FakeClanFeedService service) {
  return ProviderScope(
    overrides: [
      clanServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: ClanTribunaPage(slug: service.detail.slug),
    ),
  );
}

Widget pumpPolla(
  FakeClanFeedService service, {
  String? matchId = 'match-1',
}) {
  final router = GoRouter(
    initialLocation: '/clans/${service.detail.slug}/polla',
    routes: [
      GoRoute(
        path: '/clans/:slug/polla',
        builder: (context, state) => ClanPollaPage(
          slug: state.pathParameters['slug'] ?? '',
          matchId: matchId,
        ),
      ),
      GoRoute(
        path: '/polla/:matchId',
        builder: (context, state) => Scaffold(
          body: Text('GLOBAL_POLLA:${state.pathParameters['matchId']}'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      clanServiceProvider.overrideWithValue(service),
      homeProvider.overrideWith((ref) async => sampleHomeWithMatch()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.darkTheme,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('CLAN_FEED_RENDER', (tester) async {
    final service = FakeClanFeedService(posts: [sampleClanPost()]);
    await tester.pumpWidget(pumpTribuna(service));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué quieres compartir?'), findsOneWidget);
    expect(find.text('Vamos la U desde la tribuna del clan'), findsOneWidget);
    expect(find.byType(GarraReactionBar), findsOneWidget);
  });

  testWidgets('CLAN_FEED_EMPTY', (tester) async {
    final service = FakeClanFeedService(posts: const []);
    await tester.pumpWidget(pumpTribuna(service));
    await tester.pumpAndSettle();
    expect(find.text('Tribuna en silencio'), findsOneWidget);
    expect(find.byType(GarraEmptyState), findsWidgets);
  });

  testWidgets('CLAN_CREATE_POST', (tester) async {
    final service = FakeClanFeedService(posts: const []);
    await tester.pumpWidget(pumpTribuna(service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Arenga del clan');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(service.createPostCalls, 1);
    expect(service.lastCreatedContent, 'Arenga del clan');
    expect(find.text('Arenga del clan'), findsWidgets);
  });

  testWidgets('CLAN_REACTION_REUSE', (tester) async {
    final service = FakeClanFeedService(posts: [sampleClanPost()]);
    await tester.pumpWidget(pumpTribuna(service));
    await tester.pumpAndSettle();
    expect(find.byType(GarraReactionBar), findsOneWidget);
  });

  testWidgets('CLAN_COMMENT_REUSE', (tester) async {
    final service = FakeClanFeedService(posts: [sampleClanPost()]);
    final router = GoRouter(
      initialLocation: '/clans/garra-surco/tribuna',
      routes: [
        GoRoute(
          path: '/clans/:slug/tribuna',
          builder: (_, __) => const ClanTribunaPage(slug: 'garra-surco'),
        ),
        GoRoute(
          path: '/muro-crema/posts/:id',
          builder: (context, state) =>
              PostDetailScreen(postId: state.pathParameters['id'] ?? ''),
        ),
      ],
    );
    final community = FakeCommunityEngagementService()
      ..post = sampleClanPost();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clanServiceProvider.overrideWithValue(service),
          communityServiceProvider.overrideWithValue(community),
        ],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vamos la U desde la tribuna del clan'));
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
    expect(find.text('Vamos la U desde la tribuna del clan'), findsWidgets);
  });

  testWidgets('CLAN_POLLA_PRELOCK', (tester) async {
    final service = FakeClanFeedService(
      polla: samplePolla(state: 'OPEN'),
    );
    await tester.pumpWidget(pumpPolla(service));
    await tester.pumpAndSettle();
    expect(find.textContaining('67 de 120 miembros'), findsOneWidget);
    expect(find.text('2 - 1'), findsOneWidget);
    expect(find.text('Hacer mi Polla'), findsOneWidget);
  });

  testWidgets('CLAN_POLLA_PREDICTIONS_HIDDEN', (tester) async {
    final service = FakeClanFeedService(
      polla: samplePolla(
        state: 'OPEN',
        members: const [
          ClanPollaMemberPrediction(
            username: 'secret',
            displayName: 'No Debe Verse',
            homeScore: 3,
            awayScore: 0,
          ),
        ],
        revealed: false,
      ),
    );
    // Force prelock model to drop member predictions even if list was passed.
    service.polla = ClanPollaMatchModel(
      match: service.polla.match,
      state: 'OPEN',
      memberCount: 120,
      participantCount: 67,
      myPrediction: service.polla.myPrediction,
      memberPredictions: const [],
      predictionsRevealed: false,
    );
    await tester.pumpWidget(pumpPolla(service));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Las predicciones del clan se revelan cuando cierre La Polla.',
      ),
      findsOneWidget,
    );
    expect(find.text('No Debe Verse'), findsNothing);
  });

  testWidgets('CLAN_POLLA_POSTLOCK', (tester) async {
    final service = FakeClanFeedService(
      polla: samplePolla(
        state: 'LOCKED',
        revealed: true,
        members: const [
          ClanPollaMemberPrediction(
            username: 'andrea',
            displayName: 'Andrea',
            homeScore: 2,
            awayScore: 0,
          ),
          ClanPollaMemberPrediction(
            username: 'juan',
            displayName: 'Juan',
            homeScore: 1,
            awayScore: 1,
          ),
        ],
      ),
    );
    await tester.pumpWidget(pumpPolla(service));
    await tester.pumpAndSettle();
    expect(find.text('Predicciones del clan'), findsOneWidget);
    expect(find.text('Andrea'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
  });

  testWidgets('CLAN_POLLA_SCORED', (tester) async {
    final service = FakeClanFeedService(
      polla: samplePolla(
        state: 'SCORED',
        revealed: true,
        members: const [
          ClanPollaMemberPrediction(
            username: 'andrea',
            displayName: 'Andrea',
            homeScore: 2,
            awayScore: 1,
            pointsEarned: 9,
            rank: 1,
          ),
          ClanPollaMemberPrediction(
            username: 'juan',
            displayName: 'Juan',
            homeScore: 1,
            awayScore: 0,
            pointsEarned: 8,
            rank: 2,
          ),
        ],
      ),
    );
    await tester.pumpWidget(pumpPolla(service));
    await tester.pumpAndSettle();
    expect(find.textContaining('9 pts'), findsWidgets);
    expect(find.textContaining('8 pts'), findsWidgets);
    expect(find.textContaining('#1'), findsWidgets);
  });

  testWidgets('CLAN_POLLA_USES_GLOBAL_CTA', (tester) async {
    final service = FakeClanFeedService(polla: samplePolla(state: 'OPEN'));
    await tester.pumpWidget(pumpPolla(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hacer mi Polla'));
    await tester.pumpAndSettle();
    expect(find.text('GLOBAL_POLLA:match-1'), findsOneWidget);
  });

  testWidgets('CLAN_MEMBER_RANKING', (tester) async {
    final service = FakeClanFeedService(
      polla: samplePolla(state: 'LOCKED', revealed: true),
      memberRanking: const [
        ClanMemberRankingEntry(
          rank: 1,
          username: 'andrea',
          displayName: 'Andrea',
          predictionPoints: 40,
        ),
        ClanMemberRankingEntry(
          rank: 2,
          username: 'juan',
          displayName: 'Juan',
          predictionPoints: 33,
        ),
      ],
    );
    await tester.pumpWidget(pumpPolla(service));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ranking Polla'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Andrea'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Andrea'), findsOneWidget);
    expect(find.textContaining('40 pts'), findsOneWidget);
  });

  testWidgets('GLOBAL_CLAN_RANKING', (tester) async {
    final service = FakeClanFeedService(
      globalRanking: const [
        ClanGlobalRankingEntry(
          rank: 1,
          slug: 'crema-norte',
          name: 'Crema Norte',
          totalPoints: 200,
          memberCount: 90,
        ),
        ClanGlobalRankingEntry(
          rank: 2,
          slug: 'garra-surco',
          name: 'Garra Surco',
          totalPoints: 150,
          memberCount: 120,
          isPrimary: true,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clanServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ClanRankingPage(year: 2026),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ranking de Comunidades'), findsOneWidget);
    expect(find.text('Puntos Polla'), findsWidgets);
    expect(find.text('Crema Norte'), findsOneWidget);
    expect(find.text('Garra Surco'), findsOneWidget);
  });

  testWidgets('PRIMARY_CLAN_HIGHLIGHT', (tester) async {
    final service = FakeClanFeedService(
      globalRanking: const [
        ClanGlobalRankingEntry(
          rank: 1,
          slug: 'garra-surco',
          name: 'Garra Surco',
          totalPoints: 150,
          isPrimary: true,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clanServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ClanRankingPage(year: 2026),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tu comunidad'), findsOneWidget);
  });

  testWidgets('MEMBERSHIP_LOST_STATE', (tester) async {
    final service = FakeClanFeedService(throwMembershipLostOnFeed: true);
    await tester.pumpWidget(pumpTribuna(service));
    await tester.pumpAndSettle();
    expect(find.text('Acceso restringido'), findsOneWidget);
    expect(find.textContaining('miembros activos'), findsOneWidget);
  });

  testWidgets('CLAN_POLLA_NO_MATCH', (tester) async {
    final service = FakeClanFeedService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clanServiceProvider.overrideWithValue(service),
          homeProvider.overrideWith(
            (ref) async => HomeModel(
              fan: sampleHomeWithMatch().fan,
              matchdayState: 'NO_MATCH',
              match: null,
              prediction: sampleHomeWithMatch().prediction,
              checkIn: sampleHomeWithMatch().checkIn,
              community: sampleHomeWithMatch().community,
              notifications: sampleHomeWithMatch().notifications,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ClanPollaPage(slug: 'garra-surco'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin partido activo'), findsOneWidget);
  });
}
