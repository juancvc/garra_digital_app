import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/features/clans/data/clan_models.dart';
import 'package:garra_digital_app/features/clans/data/clan_service.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_detail_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_invitations_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clans_page.dart';
import 'package:garra_digital_app/features/clans/presentation/providers/clans_provider.dart';
import 'package:garra_digital_app/features/explore/presentation/explore_page.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/passport/data/passport_models.dart';
import 'package:garra_digital_app/features/passport/presentation/passport_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/providers/passport_provider.dart';
import 'package:go_router/go_router.dart';

/// Widget-test fixtures only — not production seed clans.
ClanModel sampleClan({
  String id = 'clan-1',
  String slug = 'garra-surco',
  String name = 'Garra Surco',
  String? description = 'Comunidad crema del sur.',
  String city = 'Lima',
  String countryCode = 'PE',
  String joinPolicy = 'OPEN',
  String visibility = 'PUBLIC',
  String status = 'ACTIVE',
  int memberCount = 1284,
  String? logoUrl,
  String? bannerUrl,
  ClanMembershipSummary? myMembership,
  ClanJoinRequestSummary? pendingJoinRequest,
}) {
  return ClanModel(
    id: id,
    slug: slug,
    name: name,
    description: description,
    city: city,
    countryCode: countryCode,
    visibility: visibility,
    joinPolicy: joinPolicy,
    status: status,
    memberCount: memberCount,
    logoUrl: logoUrl,
    bannerUrl: bannerUrl,
    myMembership: myMembership,
    pendingJoinRequest: pendingJoinRequest,
  );
}

MyClanMembership sampleMembership({
  ClanModel? clan,
  String role = 'MEMBER',
  bool isPrimary = false,
}) {
  return MyClanMembership(
    clan: clan ?? sampleClan(),
    role: role,
    status: 'ACTIVE',
    isPrimary: isPrimary,
  );
}

ClanInvitationModel sampleInvitation({
  String id = 'inv-1',
  String status = 'PENDING',
  ClanModel? clan,
}) {
  return ClanInvitationModel(
    id: id,
    status: status,
    clan: clan ?? sampleClan(slug: 'crema-norte', name: 'Crema Norte'),
    invitedByDisplayName: 'Admin Crema',
  );
}

PassportModel samplePassport({PassportClanSummary? primaryClan}) {
  return PassportModel(
    identity: const PassportIdentity(
      username: 'cremafan',
      displayName: 'Hincha Crema',
      city: 'Lima',
      countryCode: 'PE',
      supporterSinceYear: 1998,
    ),
    level: const PassportLevel(
      number: 2,
      name: 'Hincha Fiel',
      points: 100,
      levelMinPoints: 50,
      nextLevelPoints: 150,
      progressPercent: 50,
      pointsToNextLevel: 50,
    ),
    stats: const PassportStats(
      checkIns: 3,
      predictions: 5,
      predictionPoints: 21,
      posts: 2,
      streakCurrent: 2,
      streakBest: 5,
    ),
    globalRank: 12,
    profileVisibility: 'PUBLIC',
    viewerIsOwner: true,
    primaryClan: primaryClan,
  );
}

HomeModel sampleHome({HomeClanSummary? clan}) {
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
      state: 'NOT_PREDICTED',
      predictionsOpen: false,
    ),
    checkIn: const HomeCheckIn(
      showCheckInCta: false,
      hasActiveStadiumPoint: false,
      recentlyCheckedIn: false,
    ),
    community: const HomeCommunityPreview(posts: []),
    notifications: const HomeNotifications(unreadCount: 0),
    clan: clan,
  );
}

class FakeClanService extends ClanService {
  FakeClanService({
    this.discover = const [],
    this.myClans = const [],
    this.detail,
    this.members = const [],
    this.joinRequests = const [],
    this.invitations = const [],
  }) : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost')));

  List<ClanModel> discover;
  List<MyClanMembership> myClans;
  ClanModel? detail;
  List<ClanMemberModel> members;
  List<ClanJoinRequestModel> joinRequests;
  List<ClanInvitationModel> invitations;

  String? lastJoinedSlug;
  String? lastPrimarySlug;
  String? lastAcceptedInvitationId;
  String? lastDeclinedInvitationId;
  int joinCalls = 0;

  @override
  Future<ClanPage<ClanModel>> discoverClans({
    String? search,
    String? city,
    String? countryCode,
    String? cursor,
    int size = 20,
  }) async {
    final q = search?.toLowerCase() ?? '';
    final items = discover.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.slug.toLowerCase().contains(q);
    }).toList();
    return ClanPage(items: items);
  }

  @override
  Future<List<MyClanMembership>> getMyClans() async => myClans;

  @override
  Future<ClanModel> getClan(String slug) async {
    if (detail != null && detail!.slug == slug) return detail!;
    return discover.firstWhere(
      (c) => c.slug == slug,
      orElse: () => sampleClan(slug: slug),
    );
  }

  @override
  Future<ClanModel> joinClan(String slug) async {
    joinCalls++;
    lastJoinedSlug = slug;
    final current = await getClan(slug);
    if (current.joinPolicy.toUpperCase() == 'REQUEST') {
      detail = ClanModel(
        id: current.id,
        slug: current.slug,
        name: current.name,
        description: current.description,
        city: current.city,
        countryCode: current.countryCode,
        visibility: current.visibility,
        joinPolicy: current.joinPolicy,
        status: current.status,
        memberCount: current.memberCount,
        logoUrl: current.logoUrl,
        pendingJoinRequest: const ClanJoinRequestSummary(
          id: 'req-1',
          status: 'PENDING',
        ),
      );
      return detail!;
    }
    detail = ClanModel(
      id: current.id,
      slug: current.slug,
      name: current.name,
      description: current.description,
      city: current.city,
      countryCode: current.countryCode,
      visibility: current.visibility,
      joinPolicy: current.joinPolicy,
      status: current.status,
      memberCount: current.memberCount + 1,
      logoUrl: current.logoUrl,
      myMembership: const ClanMembershipSummary(
        role: 'MEMBER',
        status: 'ACTIVE',
      ),
    );
    return detail!;
  }

  @override
  Future<void> setPrimaryClan(String slug) async {
    lastPrimarySlug = slug;
    myClans = myClans
        .map(
          (m) => MyClanMembership(
            clan: m.clan,
            role: m.role,
            status: m.status,
            isPrimary: m.clan.slug == slug,
            joinedAt: m.joinedAt,
          ),
        )
        .toList();
  }

  @override
  Future<ClanPage<ClanMemberModel>> getMembers(
    String slug, {
    String? cursor,
    int size = 20,
  }) async {
    return ClanPage(items: members);
  }

  @override
  Future<List<ClanJoinRequestModel>> getJoinRequests(String slug) async =>
      joinRequests;

  @override
  Future<List<ClanInvitationModel>> getMyInvitations() async => invitations;

  @override
  Future<void> acceptInvitation(String invitationId) async {
    lastAcceptedInvitationId = invitationId;
    invitations = invitations
        .where((i) => i.id != invitationId)
        .toList(growable: false);
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    lastDeclinedInvitationId = invitationId;
    invitations = invitations
        .where((i) => i.id != invitationId)
        .toList(growable: false);
  }
}

Widget pumpClans(FakeClanService service) {
  final router = GoRouter(
    initialLocation: '/clans',
    routes: [
      GoRoute(path: '/clans', builder: (context, state) => const ClansPage()),
      GoRoute(
        path: '/clans/invitations',
        builder: (context, state) => const ClanInvitationsPage(),
      ),
      GoRoute(
        path: '/clans/:slug',
        builder: (context, state) =>
            ClanDetailPage(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/clans/:slug/manage',
        builder: (context, state) =>
            Scaffold(body: Text('MANAGE:${state.pathParameters['slug']}')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [clanServiceProvider.overrideWithValue(service)],
    child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  );
}

Widget pumpClanDetail(FakeClanService service, String slug) {
  return ProviderScope(
    overrides: [clanServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: ClanDetailPage(slug: slug),
    ),
  );
}

void main() {
  testWidgets('CLAN_DISCOVERY_RENDER', (tester) async {
    final service = FakeClanService(
      discover: [
        sampleClan(),
        sampleClan(slug: 'crema-norte', name: 'Crema Norte', memberCount: 420),
      ],
    );
    await tester.pumpWidget(pumpClans(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descubrir'));
    await tester.pumpAndSettle();
    expect(find.text('Descubrir'), findsWidgets);
    expect(find.text('Garra Surco'), findsWidgets);
    expect(find.text('Crema Norte'), findsOneWidget);
  });

  testWidgets('CLAN_EMPTY_STATE', (tester) async {
    final service = FakeClanService();
    await tester.pumpWidget(pumpClans(service));
    await tester.pumpAndSettle();
    expect(find.byType(GarraEmptyState), findsWidgets);
    expect(find.text('Aún no tienes comunidad'), findsOneWidget);
    await tester.tap(find.text('Descubrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin resultados'), findsOneWidget);
  });

  testWidgets('CLAN_DETAIL_RENDER', (tester) async {
    final service = FakeClanService(
      detail: sampleClan(),
      members: const [
        ClanMemberModel(
          username: 'cremafan',
          displayName: 'Hincha Crema',
          role: 'OWNER',
        ),
      ],
    );
    await tester.pumpWidget(pumpClanDetail(service, 'garra-surco'));
    await tester.pumpAndSettle();
    expect(find.text('Garra Surco'), findsWidgets);
    expect(find.textContaining('Comunidad crema'), findsOneWidget);
    expect(find.textContaining('miembros'), findsWidgets);
    expect(find.text('Unirme'), findsOneWidget);
  });

  testWidgets('OPEN_CLAN_JOIN', (tester) async {
    final service = FakeClanService(detail: sampleClan(joinPolicy: 'OPEN'));
    await tester.pumpWidget(pumpClanDetail(service, 'garra-surco'));
    await tester.pumpAndSettle();
    expect(find.text('Unirme'), findsOneWidget);
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    expect(service.joinCalls, 1);
    expect(service.lastJoinedSlug, 'garra-surco');
    expect(find.textContaining('miembro'), findsWidgets);
  });

  testWidgets('REQUEST_CLAN_JOIN', (tester) async {
    final service = FakeClanService(detail: sampleClan(joinPolicy: 'REQUEST'));
    await tester.pumpWidget(pumpClanDetail(service, 'garra-surco'));
    await tester.pumpAndSettle();
    expect(find.text('Solicitar ingreso'), findsOneWidget);
    await tester.tap(find.text('Solicitar ingreso'));
    await tester.pumpAndSettle();
    expect(service.joinCalls, 1);
    expect(find.text('Solicitud pendiente'), findsOneWidget);
  });

  testWidgets('INVITE_ONLY_STATE', (tester) async {
    final service = FakeClanService(
      detail: sampleClan(joinPolicy: 'INVITE_ONLY'),
    );
    await tester.pumpWidget(pumpClanDetail(service, 'garra-surco'));
    await tester.pumpAndSettle();
    expect(find.text('Solo por invitación'), findsOneWidget);
    expect(find.text('Unirme'), findsNothing);
    expect(find.text('Solicitar ingreso'), findsNothing);
  });

  testWidgets('JOIN_PENDING_STATE', (tester) async {
    final service = FakeClanService(
      detail: sampleClan(
        joinPolicy: 'REQUEST',
        pendingJoinRequest: const ClanJoinRequestSummary(
          id: 'req-1',
          status: 'PENDING',
        ),
      ),
    );
    await tester.pumpWidget(pumpClanDetail(service, 'garra-surco'));
    await tester.pumpAndSettle();
    expect(find.text('Solicitud pendiente'), findsOneWidget);
    expect(find.text('Unirme'), findsNothing);
  });

  testWidgets('MY_CLANS_RENDER', (tester) async {
    final service = FakeClanService(
      myClans: [
        sampleMembership(isPrimary: true),
        sampleMembership(
          clan: sampleClan(slug: 'crema-norte', name: 'Crema Norte'),
          role: 'ADMIN',
        ),
      ],
    );
    await tester.pumpWidget(pumpClans(service));
    await tester.pumpAndSettle();
    expect(find.text('Mis comunidades'), findsOneWidget);
    expect(find.text('Garra Surco'), findsWidgets);
    expect(find.text('Crema Norte'), findsOneWidget);
    expect(find.text('Principal'), findsWidgets);
    expect(find.byTooltip('Marcar principal'), findsOneWidget);
  });

  testWidgets('SET_PRIMARY_CLAN', (tester) async {
    final service = FakeClanService(
      myClans: [
        sampleMembership(isPrimary: true),
        sampleMembership(
          clan: sampleClan(slug: 'crema-norte', name: 'Crema Norte'),
        ),
      ],
    );
    await tester.pumpWidget(pumpClans(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Marcar principal'));
    await tester.pumpAndSettle();
    expect(service.lastPrimarySlug, 'crema-norte');
  });

  testWidgets('COMMUNITIES_NARROW_LAYOUT_HAS_CLEAR_MEMBER_STATE', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = FakeClanService(
      myClans: [
        sampleMembership(
          clan: sampleClan(
            name: 'Comunidad Crema de Nombre Extenso',
            city: '',
            countryCode: '',
          ),
          isPrimary: true,
        ),
      ],
    );

    await tester.pumpWidget(pumpClans(service));
    await tester.pumpAndSettle();

    expect(find.text('Mis comunidades'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('Crear comunidad'), findsNothing);
  });

  testWidgets('PASSPORT_PRIMARY_CLAN', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith(
            (ref) async => samplePassport(
              primaryClan: const PassportClanSummary(
                slug: 'garra-surco',
                name: 'Garra Surco',
                memberCount: 1284,
                role: 'MEMBER',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PassportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mi Clan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mi Clan'), findsOneWidget);
    expect(find.text('Garra Surco'), findsOneWidget);
    expect(find.textContaining('miembros'), findsOneWidget);
  });

  testWidgets('PASSPORT_NO_CLAN_CTA', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith((ref) async => samplePassport()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PassportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Encuentra tu clan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Encuentra tu clan'), findsOneWidget);
  });

  testWidgets('INVITE_ACCEPT', (tester) async {
    final service = FakeClanService(invitations: [sampleInvitation()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clanServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ClanInvitationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crema Norte'), findsOneWidget);
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(service.lastAcceptedInvitationId, 'inv-1');
  });

  testWidgets('INVITE_DECLINE', (tester) async {
    final service = FakeClanService(invitations: [sampleInvitation()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clanServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ClanInvitationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();
    expect(service.lastDeclinedInvitationId, 'inv-1');
  });

  testWidgets('OWNER_MANAGEMENT_ENTRY', (tester) async {
    final service = FakeClanService(
      detail: sampleClan(
        myMembership: const ClanMembershipSummary(
          role: 'OWNER',
          status: 'ACTIVE',
        ),
      ),
    );
    final router = GoRouter(
      initialLocation: '/clans/garra-surco',
      routes: [
        GoRoute(
          path: '/clans/:slug',
          builder: (context, state) =>
              ClanDetailPage(slug: state.pathParameters['slug'] ?? ''),
        ),
        GoRoute(
          path: '/clans/:slug/manage',
          builder: (context, state) =>
              Scaffold(body: Text('MANAGE:${state.pathParameters['slug']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clanServiceProvider.overrideWithValue(service)],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Administrar'), findsOneWidget);
    await tester.tap(find.text('Administrar'));
    await tester.pumpAndSettle();
    expect(find.text('MANAGE:garra-surco'), findsOneWidget);
  });

  testWidgets('HOME_CLAN_CTA', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/explorar',
      routes: [
        GoRoute(path: '/explorar', builder: (_, _) => const ExplorePage()),
        GoRoute(
          path: '/clans',
          builder: (_, _) => const Scaffold(body: Text('CLANS_ROUTE')),
        ),
        GoRoute(
          path: '/comunidad/buscar',
          builder: (_, _) => const Scaffold(body: Text('SEARCH')),
        ),
        GoRoute(
          path: '/marketplace',
          builder: (_, _) => const Scaffold(body: Text('MARKET')),
        ),
        GoRoute(
          path: '/eventos',
          builder: (_, _) => const Scaffold(body: Text('EVENTS')),
        ),
        GoRoute(
          path: '/ruta-templo',
          builder: (_, _) => const Scaffold(body: Text('MAP')),
        ),
        GoRoute(
          path: '/solidaria',
          builder: (_, _) => const Scaffold(body: Text('SOLIDARIA')),
        ),
        GoRoute(
          path: '/rewards',
          builder: (_, _) => const Scaffold(body: Text('REWARDS')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final clanCta = find.text('Encuentra tu gente crema');
    await tester.scrollUntilVisible(
      clanCta,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(clanCta, findsOneWidget);
    await tester.tap(clanCta);
    await tester.pumpAndSettle();
    expect(find.text('CLANS_ROUTE'), findsOneWidget);
  });
}
