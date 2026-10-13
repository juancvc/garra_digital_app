// PRODUCT-10A.2D: focused Home V2.1 refinement coverage.
import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/config/app_config_service.dart';
import 'package:garra_digital_app/core/network/dio_client.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_matchday_poll_card.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:go_router/go_router.dart';

import 'home_matchday_poll_test.dart' show FakePollService, poll;
import 'home_screen_test.dart' show sampleHome;

class _Fan extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _Feed extends CommunityService {
  _Feed({this.posts = 3}) : super(dio: Dio());
  final int posts;
  final modes = <String>[];

  @override
  Future<FeedPage> getFeedPage({required String mode, String? cursor, int size = 20}) async {
    modes.add(mode);
    return FeedPage.posts(posts: List.generate(posts, (i) => WallPostModel(
      id: '$mode-$i', username: 'crema', fullName: 'Hincha Crema',
      content: '$mode publicación $i', imageUrl: null, locationTag: 'HOME',
      status: 'ACTIVE', reportCount: 0,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    )));
  }

  @override
  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async =>
      (await getFeedPage(mode: mode)).posts;
}

class _Harness {
  _Harness({this.withMatch = true, int posts = 3})
      : feed = _Feed(posts: posts),
        polls = FakePollService(poll());
  final bool withMatch;
  final _Feed feed;
  final FakePollService polls;
  int featuredCalls = 0;

  Widget app({double textScale = 1.0}) {
    final lima = limaWallClock(DateTime.now());
    final match = FootballMatch(id: 123, competitionId: 'LIGA_1',
      competition: 'Liga 1 Perú', round: 'Clausura - 11',
      home: 'Universitario', away: 'FBC Melgar', status: 'SCHEDULED',
      kickoff: DateTime(lima.year, lima.month, lima.day).add(const Duration(days: 1, hours: 19)),
      kickoffConfirmed: true, dataState: 'SEASON_SNAPSHOT',
      snapshotAt: DateTime.now().toUtc());
    final featured = FootballFeaturedResult(
        featured: withMatch ? FootballFeatured(next: match) : null);
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(path: '/marketplace', builder: (_, _) =>
          const Scaffold(body: Text('MARKETPLACE_ROUTE'))),
      GoRoute(path: '/comunidad/compose', builder: (_, _) =>
          const Scaffold(body: Text('COMPOSE_ROUTE'))),
      GoRoute(path: '/comunidad/buscar', builder: (_, _) =>
          const Scaffold(body: Text('SEARCH_ROUTE'))),
      GoRoute(path: '/muro-crema/posts/:id', builder: (_, s) =>
          Scaffold(body: Text('POST:${s.pathParameters['id']}'))),
      GoRoute(path: '/centro-garra/partido/:id', builder: (_, s) =>
          Scaffold(body: Text('DETAIL:${s.pathParameters['id']}'))),
    ]);
    return ProviderScope(
      overrides: [
        homeProvider.overrideWith((ref) async =>
            sampleHome(withMatch: withMatch, matchdayState: withMatch ? 'UPCOMING' : 'NO_MATCH')),
        homeFeaturedProvider.overrideWith((ref) async {
          featuredCalls++;
          return featured;
        }),
        homeMatchdayPollServiceProvider.overrideWithValue(polls),
        communityServiceProvider.overrideWithValue(feed),
        currentFanProvider.overrideWith(_Fan.new),
      ],
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
  }
}

Future<void> _setMarketplaceFlag(WidgetTester tester, bool enabled) async {
  final stub = InterceptorsWrapper(onRequest: (options, handler) {
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
      'data': {
        'environment': 'staging', 'maintenanceMode': false,
        'minimumSupportedVersion': '0.9.0', 'latestVersion': '1.0.0',
        'features': {'marketplace': enabled, 'community': true},
      },
    }));
  });
  DioClient.instance.interceptors.insert(0, stub);
  await tester.runAsync(() => appConfigService.fetch());
  DioClient.instance.interceptors.remove(stub);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Test isolation: the shared app Dio reads the auth token from secure
  // storage, which has no platform implementation under flutter_test.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  testWidgets('Home with match: tabs Para ti | Siguiendo | Marketplace, no shortcut tiles',
      (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.app());
    await _settle(tester);
    expect(find.text('Para ti'), findsOneWidget);
    expect(find.text('Siguiendo'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('Partido'), findsNothing);
    for (final k in ['partidos', 'comunidad', 'marketplace']) {
      expect(find.byKey(ValueKey('home_quick_$k')), findsNothing);
    }
    expect(find.byKey(const ValueKey('home_featured_match')), findsOneWidget);
    expect(find.text('Universitario'), findsOneWidget);
    expect(find.text('FBC Melgar'), findsOneWidget);
    expect(find.textContaining('19:00 (hora de Lima)'), findsOneWidget);
    expect(find.text('Próximo partido'), findsOneWidget);
    // Repeated headings removed.
    expect(find.text('PARTIDO DESTACADO'), findsNothing);
    expect(find.text('CENTRO GARRA'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home_featured_open')));
    await _settle(tester);
    expect(find.text('DETAIL:123'), findsOneWidget);
  });

  testWidgets('Tribuna follows the match: title, publish, first post', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final h = _Harness();
    await tester.pumpWidget(h.app());
    await _settle(tester);
    final match = tester.getBottomLeft(find.byKey(const ValueKey('home_featured_match'))).dy;
    final title = tester.getTopLeft(find.text('LA TRIBUNA CREMA')).dy;
    final compose = tester.getTopLeft(find.text('¿Qué vive la crema hoy?')).dy;
    final post = tester.getTopLeft(find.textContaining('FOR_YOU publicación 0')).dy;
    expect(match < title && title < compose && compose < post, isTrue);
    // No large gap between the match block and the Tribuna title.
    expect(title - match, lessThan(120));
    await tester.tap(find.text('¿Qué vive la crema hoy?'));
    await _settle(tester);
    expect(find.text('COMPOSE_ROUTE'), findsOneWidget);
  });

  testWidgets('Home without match keeps Tribuna and composer first', (tester) async {
    final h = _Harness(withMatch: false);
    await tester.pumpWidget(h.app());
    await _settle(tester);
    expect(find.byKey(const ValueKey('home_featured_match')), findsNothing);
    expect(find.byKey(const ValueKey('home_tribuna_alive')), findsOneWidget);
    expect(find.byType(HomeMatchdayPollCard), findsNothing);
    expect(find.text('LA TRIBUNA CREMA'), findsOneWidget);
    expect(find.text('¿Qué vive la crema hoy?'), findsOneWidget);
    expect(h.polls.gets, 0);
  });

  testWidgets('Poll is collapsed, expands on demand, votes, changes and refreshes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    final h = _Harness();
    await tester.pumpWidget(h.app());
    await _settle(tester);
    expect(find.text('¿Dónde alentarás a la U?'), findsOneWidget);
    expect(find.text('Iré al estadio'), findsNothing);
    expect(find.text('0 hinchas'), findsNothing);
    final toggle = find.byKey(const ValueKey('home_poll_toggle'));
    expect(find.text('Votar'), findsOneWidget);
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Votar en la encuesta'), findsOneWidget);
    expect(h.polls.gets, 1);

    await tester.tap(toggle);
    await _settle(tester);
    expect(find.text('Iré al estadio'), findsOneWidget);
    expect(find.bySemanticsLabel('Ocultar opciones de la encuesta'), findsOneWidget);
    final chip = find.ancestor(of: find.text('Iré al estadio'), matching: find.byType(InkWell)).first;
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    expect(h.polls.gets, 1, reason: 'expanding must not refetch');

    await tester.tap(find.text('Iré al estadio'));
    await _settle(tester);
    expect(h.polls.votes, 1);
    expect(find.textContaining('100 %'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Iré al estadio, 100 por ciento, tu voto')), findsOneWidget);
    expect(tester.getSize(find.widgetWithText(TextButton, 'Cambiar voto')).height,
        greaterThanOrEqualTo(48));

    await tester.tap(find.text('Cambiar voto'));
    await _settle(tester);
    await tester.tap(find.text('Lo veré en casa'));
    await _settle(tester);
    expect(h.polls.votes, 2);
    expect(find.text('1 hincha'), findsOneWidget);
    expect(h.polls.gets, 1);

    await tester.tap(find.text('Actualizar'));
    await _settle(tester);
    expect(h.polls.gets, 2, reason: 'manual refresh is the only extra GET');

    await tester.tap(find.text('Ocultar'));
    await _settle(tester);
    expect(find.text('Lo veré en casa'), findsNothing);
    expect(find.text('Ver resultados'), findsOneWidget);
    expect(h.polls.gets, 2);
    semantics.dispose();
  });

  testWidgets('Para ti and Siguiendo load their own feed once each', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.app());
    await _settle(tester);
    expect(h.feed.modes, ['FOR_YOU']);
    expect(find.textContaining('FOR_YOU publicación 0'), findsOneWidget);
    await tester.tap(find.text('Siguiendo'));
    await _settle(tester);
    expect(h.feed.modes, ['FOR_YOU', 'FOLLOWING']);
    expect(find.textContaining('FOLLOWING publicación 0'), findsOneWidget);
    expect(h.featuredCalls, 1);
  });

  testWidgets('Marketplace tab pushes the existing route; Back keeps the previous tab without refetch',
      (tester) async {
    await _setMarketplaceFlag(tester, true);
    final semantics = tester.ensureSemantics();
    final h = _Harness();
    await tester.pumpWidget(h.app());
    await _settle(tester);
    await tester.tap(find.text('Siguiendo'));
    await _settle(tester);
    final feedCalls = h.feed.modes.length;
    final pollGets = h.polls.gets;
    expect(tester.getSize(find.byKey(const ValueKey('home_tab_Marketplace'))).height,
        greaterThanOrEqualTo(48));

    await tester.tap(find.text('Marketplace'));
    await _settle(tester);
    expect(find.text('MARKETPLACE_ROUTE'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('MARKETPLACE_ROUTE'), findsNothing);
    expect(find.textContaining('FOLLOWING publicación 0'), findsOneWidget);
    final siguiendo = tester.getSemantics(find.byKey(const ValueKey('home_tab_Siguiendo')));
    expect(siguiendo.flagsCollection.isSelected, Tristate.isTrue);
    expect(h.feed.modes.length, feedCalls);
    expect(h.polls.gets, pollGets);
    expect(h.featuredCalls, 1);
    semantics.dispose();
  });

  testWidgets('Marketplace tab is hidden when the marketplace flag is off', (tester) async {
    await _setMarketplaceFlag(tester, false);
    try {
      expect(appConfigService.current.feature('marketplace'), isFalse);
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await _settle(tester);
      expect(find.text('Marketplace'), findsNothing);
      expect(find.text('Para ti'), findsOneWidget);
      expect(find.text('Siguiendo'), findsOneWidget);
    } finally {
      await _setMarketplaceFlag(tester, true);
    }
  });

  for (final size in const [Size(320, 640), Size(360, 640)]) {
    testWidgets('No overflow at ${size.width.toInt()}x${size.height.toInt()} textScale 1.3 (poll open)',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final h = _Harness();
      await tester.pumpWidget(h.app(textScale: 1.3));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('home_poll_toggle')));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Marketplace'), findsOneWidget);
      await tester.tap(find.text('Siguiendo'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
