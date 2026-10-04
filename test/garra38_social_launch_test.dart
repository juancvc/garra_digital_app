import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_official_badge.dart';
import 'package:garra_digital_app/features/clans/data/clan_models.dart';
import 'package:garra_digital_app/features/clans/data/clan_service.dart';
import 'package:garra_digital_app/features/clans/presentation/providers/clans_provider.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/discovery_models.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/profile_follows_page.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_discovery_section.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';
import 'package:garra_digital_app/features/retention/data/retention_models.dart';
import 'package:garra_digital_app/features/retention/data/retention_service.dart';
import 'package:garra_digital_app/features/retention/presentation/onboarding_interests_page.dart';
import 'package:garra_digital_app/features/solidarity/data/solidarity_service.dart';
import 'package:garra_digital_app/features/solidarity/presentation/solidaria_page.dart';
import 'package:go_router/go_router.dart';

const _ok = '\u00ed';

WallPostModel _post(String id, String content, {String account = 'STANDARD'}) =>
    WallPostModel(
      id: id,
      username: 'u$id',
      fullName: 'Autor $id',
      content: content,
      imageUrl: null,
      locationTag: 'HOME',
      status: 'ACTIVE',
      reportCount: 0,
      createdAt: '2026-10-01T10:00:00Z',
      reactionCount: 3,
      commentCount: 1,
      accountType: account,
    );

ClanModel _clan(String slug, String name, String policy, {int members = 12}) =>
    ClanModel(
      id: slug,
      slug: slug,
      name: name,
      city: 'Lima',
      visibility: 'PUBLIC',
      joinPolicy: policy,
      status: 'ACTIVE',
      memberCount: members,
    );

DiscoveryBundle _bundle({List<DiscoveryPerson>? people}) => DiscoveryBundle(
  people:
      people ??
      const [
        DiscoveryPerson(
          userId: 'official-1',
          username: 'cuenta_x',
          displayName: 'Nombre cualquiera',
          accountType: 'PLATFORM_OFFICIAL',
          reason: 'OFFICIAL_ACCOUNT',
        ),
        DiscoveryPerson(
          userId: 'fan-1',
          username: 'hincha_uno',
          displayName: 'Hincha Uno',
        ),
        DiscoveryPerson(
          userId: 'fan-2',
          username: 'hincha_dos',
          displayName: 'Hincha Dos',
        ),
      ],
  communities: [
    _clan('open-club', 'Comunidad Abierta', 'OPEN'),
    _clan('req-club', 'Comunidad Con Solicitud', 'REQUEST'),
  ],
  posts: [_post('p1', 'Publicaci\u00f3n p\u00fablica sugerida')],
  solidarity: const [
    DiscoverySolidarity(
      id: 's1',
      title: 'Colecta de abrigo',
      type: 'FOOD',
      city: 'Lima',
      district: 'Ate',
    ),
  ],
);

class _FakeCommunity extends CommunityService {
  _FakeCommunity({
    this.bundle,
    this.feed = const [],
    this.failDiscovery = false,
    this.failFollow = false,
  }) : super(dio: Dio());

  DiscoveryBundle? bundle;
  List<WallPostModel> feed;
  bool failDiscovery;
  bool failFollow;
  int discoveryCalls = 0;
  final followed = <String>[];

  @override
  Future<DiscoveryBundle> getDiscovery() async {
    discoveryCalls++;
    if (failDiscovery) throw Exception('boom');
    return bundle ?? const DiscoveryBundle();
  }

  @override
  Future<FeedPage> getFeedPage({required String mode, String? cursor, int size = 20}) async => FeedPage(posts: await getGlobalFeed(mode: mode));

  @override
  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async =>
      feed;

  @override
  Future<List<Map<String, dynamic>>> getProfileFollows(
    String userId, {
    required bool followers,
  }) async => const [];

  @override
  Future<void> followUser(String userId) async {
    if (failFollow) throw Exception('nope');
    followed.add(userId);
  }
}

class _FakeClans extends ClanService {
  _FakeClans() : super(dio: Dio());
  final joined = <String>[];

  @override
  Future<ClanModel> joinClan(String slug) async {
    joined.add(slug);
    return _clan(slug, 'x', 'OPEN');
  }
}

class _FakeSolidarity extends SolidarityService {
  _FakeSolidarity(this.campaign) : super(dio: Dio());
  final SolidarityCampaign campaign;

  @override
  Future<SolidarityCampaign> get(String id) async => campaign;
}

class _FakeRetention extends RetentionService {
  _FakeRetention() : super(dio: Dio());
  final calls = <({List<String> interests, bool completed})>[];

  @override
  Future<InterestPreferencesModel> updateInterests({
    String? city,
    String? region,
    required List<String> interests,
    bool onboardingCompleted = true,
  }) async {
    calls.add((interests: interests, completed: onboardingCompleted));
    throw StateError('offline'); // the page must still reach Home
  }
}

class _Source implements ConnectivitySource {
  _Source(this.result);
  final ConnectivityResult result;

  @override
  Future<List<ConnectivityResult>> check() async => [result];

  @override
  Stream<List<ConnectivityResult>> get changes =>
      const Stream<List<ConnectivityResult>>.empty();
}

Future<GoRouter> _mount(
  WidgetTester tester,
  Widget child, {
  _FakeCommunity? community,
  _FakeClans? clans,
  ThemeData? theme,
  ConnectivityResult connectivity = ConnectivityResult.wifi,
  Size size = const Size(800, 2600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Widget stub(String label) => Scaffold(body: Text(label));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/comunidad/u/:id',
        builder: (_, s) => stub('PROFILE ${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/clans/:slug',
        builder: (_, s) => stub('CLAN ${s.pathParameters['slug']}'),
      ),
      GoRoute(
        path: '/muro-crema/posts/:id',
        builder: (_, s) => stub('POST ${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/solidaria/:id',
        builder: (_, s) => stub('SOLIDARIA ${s.pathParameters['id']}'),
      ),
      GoRoute(path: '/comunidad/buscar', builder: (_, _) => stub('SEARCH')),
      GoRoute(path: '/home', builder: (_, _) => stub('HOME')),
      GoRoute(path: '/clans', builder: (_, _) => stub('CLANS')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityServiceProvider.overrideWithValue(
          community ?? _FakeCommunity(bundle: _bundle()),
        ),
        clanServiceProvider.overrideWithValue(clans ?? _FakeClans()),
        connectivitySourceProvider.overrideWithValue(_Source(connectivity)),
      ],
      child: MaterialApp.router(theme: theme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('Discovery section', () {
    testWidgets('normal: people, communities, post and verified initiative', (
      tester,
    ) async {
      await _mount(tester, const GarraDiscoverySection());
      expect(find.text('Descubre en Garra'), findsOneWidget);
      expect(find.text('Hincha Uno'), findsOneWidget);
      expect(find.text('@hincha_uno'), findsOneWidget);
      expect(find.text('Comunidad Abierta'), findsOneWidget);
      expect(find.text('Unirme'), findsOneWidget);
      expect(find.text('Solicitar'), findsOneWidget);
      expect(
        find.textContaining('Publicaci\u00f3n p\u00fablica'),
        findsOneWidget,
      );
      expect(find.text('Iniciativa verificada'), findsOneWidget);
      expect(find.text('Verificado por Garra'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('official badge only comes from accountType, not the name', (
      tester,
    ) async {
      await _mount(tester, const GarraDiscoverySection());
      // Exactly the PLATFORM_OFFICIAL person gets the badge; the verified
      // Solidaria initiative never uses it.
      expect(find.byType(GarraOfficialBadge), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('discovery_person_official-1')),
          matching: find.byType(GarraOfficialBadge),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('discovery_solidarity_s1')),
          matching: find.byType(GarraOfficialBadge),
        ),
        findsNothing,
      );
      expect(find.text('Garra Oficial'), findsOneWidget);
    });

    testWidgets('empty bundle renders nothing', (tester) async {
      await _mount(
        tester,
        const GarraDiscoverySection(),
        community: _FakeCommunity(bundle: const DiscoveryBundle()),
      );
      expect(find.text('Descubre en Garra'), findsNothing);
      expect(
        find.byKey(const ValueKey('garra_discovery_section')),
        findsNothing,
      );
    });

    testWidgets('failure degrades to a retry row and recovers', (tester) async {
      final community = _FakeCommunity(bundle: _bundle(), failDiscovery: true);
      await _mount(tester, const GarraDiscoverySection(), community: community);
      expect(find.text('No pudimos cargar sugerencias.'), findsOneWidget);
      community.failDiscovery = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(community.discoveryCalls, 2);
      expect(find.text('Descubre en Garra'), findsOneWidget);
    });

    testWidgets('follow only happens on tap and flips to Siguiendo', (
      tester,
    ) async {
      final community = _FakeCommunity(bundle: _bundle());
      await _mount(tester, const GarraDiscoverySection(), community: community);
      expect(community.followed, isEmpty); // never automatic
      await tester.tap(find.byKey(const ValueKey('discovery_follow_fan-1')));
      await tester.pumpAndSettle();
      expect(community.followed, ['fan-1']);
      expect(find.text('Siguiendo'), findsOneWidget);
      expect(find.text('Seguir'), findsNWidgets(2));
    });

    testWidgets('follow failure keeps the button available and informs', (
      tester,
    ) async {
      final community = _FakeCommunity(bundle: _bundle(), failFollow: true);
      await _mount(tester, const GarraDiscoverySection(), community: community);
      await tester.tap(find.byKey(const ValueKey('discovery_follow_fan-1')));
      await tester.pumpAndSettle();
      expect(find.text('Siguiendo'), findsNothing);
      expect(find.textContaining('No pudimos seguir'), findsOneWidget);
    });

    testWidgets('community CTA reuses the clan join flow (OPEN and REQUEST)', (
      tester,
    ) async {
      final clans = _FakeClans();
      await _mount(tester, const GarraDiscoverySection(), clans: clans);
      await tester.tap(find.byKey(const ValueKey('discovery_join_open-club')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discovery_join_req-club')));
      await tester.pumpAndSettle();
      expect(clans.joined, ['open-club', 'req-club']);
      expect(find.text('Ya eres parte'), findsOneWidget);
      expect(find.text('Solicitud enviada'), findsOneWidget);
    });

    testWidgets('cards open profile, community, post and initiative', (
      tester,
    ) async {
      final router = await _mount(tester, const GarraDiscoverySection());
      Future<void> openAndBack(String key, String expected) async {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
      }

      await openAndBack('discovery_person_fan-1', 'PROFILE fan-1');
      await openAndBack('discovery_community_open-club', 'CLAN open-club');
      await openAndBack('discovery_post_p1', 'POST p1');
      await openAndBack('discovery_solidarity_s1', 'SOLIDARIA s1');
    });

    testWidgets('does not duplicate posts already in the host feed', (
      tester,
    ) async {
      await _mount(tester, const GarraDiscoverySection(excludePostIds: {'p1'}));
      expect(find.byKey(const ValueKey('discovery_post_p1')), findsNothing);
      expect(find.text('Hincha Uno'), findsOneWidget);
    });

    testWidgets('compact (onboarding) shows only people and communities', (
      tester,
    ) async {
      await _mount(tester, const GarraDiscoverySection(compact: true));
      expect(find.text('Hincha Uno'), findsOneWidget);
      expect(find.text('Comunidad Abierta'), findsOneWidget);
      expect(find.byKey(const ValueKey('discovery_post_p1')), findsNothing);
      expect(
        find.byKey(const ValueKey('discovery_solidarity_s1')),
        findsNothing,
      );
    });

    testWidgets('offline disables actions but keeps loaded content', (
      tester,
    ) async {
      final community = _FakeCommunity(bundle: _bundle());
      await _mount(
        tester,
        const GarraDiscoverySection(),
        community: community,
        connectivity: ConnectivityResult.none,
      );
      expect(find.text('Hincha Uno'), findsOneWidget);
      final follow = tester.widget<FilledButton>(
        find.byKey(const ValueKey('discovery_follow_fan-1')),
      );
      expect(follow.onPressed, isNull);
      final join = tester.widget<FilledButton>(
        find.byKey(const ValueKey('discovery_join_open-club')),
      );
      expect(join.onPressed, isNull);
    });

    for (final themeName in const ['Noche', 'Crema']) {
      testWidgets('no overflow at 220px with long names ($themeName)', (
        tester,
      ) async {
        final community = _FakeCommunity(
          bundle: DiscoveryBundle(
            people: const [
              DiscoveryPerson(
                userId: 'official-1',
                username: 'un_username_extremadamente_largo_de_prueba',
                displayName:
                    'Un nombre muy pero muy largo para una cuenta oficial de la plataforma',
                accountType: 'PLATFORM_OFFICIAL',
              ),
              DiscoveryPerson(
                userId: 'fan-9',
                username: 'otro_username_larguisimo_para_probar',
                displayName: 'Hincha con nombre larguisimo e inolvidable',
              ),
            ],
            communities: [
              _clan(
                'club-largo',
                'Comunidad de hinchas crema con un nombre excesivamente largo',
                'REQUEST',
                members: 123456,
              ),
            ],
            posts: [
              _post(
                'long',
                'Un texto muy largo ' * 20,
                account: 'PLATFORM_OFFICIAL',
              ),
            ],
            solidarity: const [
              DiscoverySolidarity(
                id: 'sl',
                title:
                    'Una iniciativa solidaria con un titulo extraordinariamente largo',
                type: 'SCHOOL_SUPPLIES',
                city: 'Lima Metropolitana',
                district: 'San Juan de Lurigancho',
              ),
            ],
          ),
        );
        await _mount(
          tester,
          const GarraDiscoverySection(),
          community: community,
          theme: themeName == 'Noche'
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          size: const Size(220, 2600),
        );
        expect(
          find.byKey(const ValueKey('garra_discovery_section')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Feed continuity', () {
    testWidgets('empty FOLLOWING feed keeps one action and shows discovery', (
      tester,
    ) async {
      final community = _FakeCommunity(bundle: _bundle());
      await _mount(
        tester,
        const SocialFeedTab(mode: 'FOLLOWING'),
        community: community,
      );
      expect(
        find.text('Tu Garra empieza aqu$_ok.'),
        findsOneWidget,
      );
      expect(find.text('Buscar personas'), findsOneWidget);
      expect(find.text('Descubre en Garra'), findsOneWidget);
      expect(community.discoveryCalls, 1);
    });

    testWidgets('discovery closes the feed, excludes duplicates, loads once', (
      tester,
    ) async {
      final community = _FakeCommunity(
        bundle: _bundle(),
        feed: [
          _post('p1', 'Ya est\u00e1 en mi feed'),
          _post('f2', 'Otro post del feed'),
        ],
      );
      await _mount(
        tester,
        const SocialFeedTab(mode: 'FOR_YOU'),
        community: community,
      );
      expect(find.text('Ya est\u00e1 en mi feed'), findsOneWidget);
      expect(find.text('Descubre en Garra'), findsOneWidget);
      // p1 is already part of the feed -> not repeated as a suggestion.
      expect(find.byKey(const ValueKey('discovery_post_p1')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(community.discoveryCalls, 1);
    });

    testWidgets('a discovery failure never breaks the feed', (tester) async {
      final community = _FakeCommunity(
        bundle: _bundle(),
        failDiscovery: true,
        feed: [_post('f1', 'Post que sigue visible')],
      );
      await _mount(
        tester,
        const SocialFeedTab(mode: 'FOR_YOU'),
        community: community,
      );
      expect(find.text('Post que sigue visible'), findsOneWidget);
      expect(find.text('No pudimos cargar sugerencias.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Social onboarding', () {
    testWidgets(
      'continue reaches discovery, nothing is followed, ends at Home',
      (tester) async {
        final community = _FakeCommunity(bundle: _bundle());
        await _mount(
          tester,
          OnboardingInterestsPage(service: _FakeRetention()),
          community: community,
        );
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(find.text('Listo para explorar'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('onboarding_explain')),
          findsOneWidget,
        );
        expect(find.text('Hincha Uno'), findsOneWidget);
        expect(find.text('Comunidad Abierta'), findsOneWidget);
        expect(community.followed, isEmpty); // never obligatory / automatic
        await tester.tap(find.text('Ir a mi inicio'));
        await tester.pumpAndSettle();
        expect(find.text('HOME'), findsOneWidget);
        expect(community.followed, isEmpty);
      },
    );

    testWidgets('skip is always available and goes to Home', (tester) async {
      final retention = _FakeRetention();
      await _mount(tester, OnboardingInterestsPage(service: retention));
      await tester.tap(find.text('Omitir'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(retention.calls.single.completed, isTrue);
      expect(retention.calls.single.interests, isEmpty);
    });

    testWidgets('onboarding fits 220px in both themes', (tester) async {
      for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
        await _mount(
          tester,
          OnboardingInterestsPage(service: _FakeRetention()),
          theme: theme,
          size: const Size(220, 900),
        );
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Empty states', () {
    testWidgets('follows list is not a dead end', (tester) async {
      await _mount(
        tester,
        ProfileFollowsPage(
          userId: 'fan',
          followers: false,
          service: _FakeCommunity(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Descubrir personas'), findsOneWidget);
      await tester.tap(find.text('Descubrir personas'));
      await tester.pumpAndSettle();
      expect(find.text('SEARCH'), findsOneWidget);
    });
  });

  group('Solidaria', () {
    SolidarityCampaign campaign(String verification) => SolidarityCampaign(
      id: 'c1',
      title: 'Colecta de prueba',
      description: 'Descripci\u00f3n',
      type: 'BLOOD',
      city: 'Lima',
      contactWhatsapp: '51999000111',
      status: verification == 'VERIFIED' ? 'ACTIVE' : 'DRAFT',
      verificationStatus: verification,
    );

    testWidgets('VERIFIED has its own wording, never "Garra Oficial"', (
      tester,
    ) async {
      await _mount(
        tester,
        SolidariaDetailPage(
          campaignId: 'c1',
          service: _FakeSolidarity(campaign('VERIFIED')),
        ),
      );
      expect(find.text('Iniciativa verificada'), findsOneWidget);
      expect(find.text('Verificado por Garra'), findsNothing);
      expect(find.byType(GarraOfficialBadge), findsNothing);
      expect(find.text('Donaci\u00f3n de sangre'), findsOneWidget);
      expect(find.textContaining('no procesa dinero'), findsOneWidget);
      expect(find.text('Contactar por WhatsApp'), findsOneWidget);
    });

    testWidgets('PENDING and REJECTED never look verified', (tester) async {
      await _mount(
        tester,
        SolidariaDetailPage(
          campaignId: 'c1',
          service: _FakeSolidarity(campaign('PENDING')),
        ),
      );
      expect(
        find.byKey(const ValueKey('solidarity_review_pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('solidarity_verified_chip')),
        findsNothing,
      );
      expect(find.text('Iniciativa verificada'), findsNothing);

      await _mount(
        tester,
        SolidariaDetailPage(
          campaignId: 'c1',
          service: _FakeSolidarity(campaign('REJECTED')),
        ),
      );
      expect(find.text('No aprobada'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('solidarity_verified_chip')),
        findsNothing,
      );
    });
  });
}
