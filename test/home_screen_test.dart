import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/home_featured_match_card.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/home/presentation/home_matchday_poll_card.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:go_router/go_router.dart';

import 'centro_matchday_harness.dart';

HomeModel sampleHome({
  String matchdayState = 'UPCOMING',
  bool withMatch = true,
  String predictionState = 'NOT_PREDICTED',
  int unread = 3,
  bool withMission = false,
  HomeClanSummary? clan,
}) {
  return HomeModel(
    fan: const HomeFanSummary(
      displayName: 'Hincha Crema',
      username: 'cremafan',
      levelNumber: 2,
      levelName: 'Hincha Fiel',
      points: 1840,
      globalRank: 428,
    ),
    matchdayState: matchdayState,
    match: withMatch
        ? HomeMatch(
            id: 'm1',
            homeTeam: 'Universitario',
            awayTeam: 'Rival FC',
            matchDateTime: DateTime.now().add(const Duration(hours: 5)),
            stadium: 'Monumental',
            competition: 'Liga 1',
            status: 'OPEN_FOR_PREDICTION',
            matchdayState: matchdayState,
            homeScore: matchdayState == 'LIVE' || matchdayState == 'FINISHED'
                ? 1
                : null,
            awayScore: matchdayState == 'LIVE' || matchdayState == 'FINISHED'
                ? 0
                : null,
          )
        : null,
    prediction: HomePrediction(
      state: predictionState,
      matchId: withMatch ? 'm1' : null,
      predictedHomeScore: predictionState == 'NOT_PREDICTED' ? null : 2,
      predictedAwayScore: predictionState == 'NOT_PREDICTED' ? null : 1,
      pointsEarned: predictionState == 'SCORED' ? 10 : null,
      predictionsOpen:
          predictionState == 'NOT_PREDICTED' || predictionState == 'PREDICTED',
    ),
    checkIn: HomeCheckIn(
      showCheckInCta: matchdayState == 'MATCHDAY' || matchdayState == 'LIVE',
      hasActiveStadiumPoint: true,
      recentlyCheckedIn: false,
      ctaLabel: 'Hacer check-in',
    ),
    community: HomeCommunityPreview(
      matchId: withMatch ? 'm1' : null,
      posts: withMatch
          ? [
              HomeCommunityPost(
                id: 'p1',
                username: 'cremafan',
                displayName: 'Hincha Crema',
                content: 'Vamos la U',
                locationTag: 'HOME',
                createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
              ),
            ]
          : const [],
    ),
    notifications: HomeNotifications(unreadCount: unread),
    mission: withMission
        ? const HomeMissionSummary(
            id: 'mission-1',
            title: 'Fecha crema completa',
            completedSteps: 1,
            totalSteps: 3,
            rewardPoints: 25,
            completed: false,
          )
        : null,
    streak: withMission ? const HomeStreakSummary(current: 2, best: 4) : null,
    clan: clan,
  );
}

Widget pumpHome(HomeModel home, {void Function()? onFeaturedLoad}) {
  final lima = limaWallClock(DateTime.now());
  final kickoff = home.matchdayState == 'UPCOMING'
      ? DateTime(lima.year, lima.month, lima.day).add(const Duration(days: 1))
      : DateTime(lima.year, lima.month, lima.day, 19);
  final match = FootballMatch(id: 123, competitionId: 'LIGA_1',
    competition: 'Liga 1', home: 'Universitario', away: 'Rival FC',
    status: home.matchdayState == 'LIVE' ? 'FIRST_HALF' : 'SCHEDULED',
    kickoff: kickoff, kickoffConfirmed: true,
    dataState: home.matchdayState == 'LIVE' ? 'LIVE_SNAPSHOT' : 'SEASON_SNAPSHOT',
    snapshotAt: DateTime.now().toUtc());
  final featured = FootballFeaturedResult(featured: home.match == null
      ? null : FootballFeatured(
          live: home.matchdayState == 'LIVE' ? match : null,
          next: home.matchdayState == 'LIVE' ? null : match));
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/centro-garra/partido/:fixtureId',
          builder: (_, state) => Scaffold(body: Text(
              'DETAIL:${state.pathParameters['fixtureId']}:${state.uri.queryParameters['competition']}'))),
      GoRoute(
        path: '/passport',
        builder: (context, state) =>
            const Scaffold(body: Text('PASSPORT_ROUTE')),
      ),
      GoRoute(
        path: '/polla',
        builder: (context, state) => const Scaffold(body: Text('POLLA_ROUTE')),
      ),
      GoRoute(
        path: '/polla/:matchId',
        builder: (context, state) => const Scaffold(body: Text('POLLA_ROUTE')),
      ),
      GoRoute(
        path: '/matchday/:matchId/polls',
        builder: (context, state) =>
            const Scaffold(body: Text('MATCHDAY_ROUTE')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const Scaffold(body: Text('NOTIF_ROUTE')),
      ),
      GoRoute(
        path: '/mapa-crema',
        builder: (context, state) => Scaffold(
          body: Text(
            'MAPA_ROUTE:${state.uri.queryParameters['matchId'] ?? ''}',
          ),
        ),
      ),
      GoRoute(
        path: '/missions',
        builder: (context, state) =>
            const Scaffold(body: Text('MISSIONS_ROUTE')),
      ),
      GoRoute(
        path: '/muro-crema',
        builder: (context, state) => const Scaffold(body: Text('MURO_ROUTE')),
      ),
      GoRoute(
        path: '/muro-crema/posts/:id',
        builder: (context, state) => Scaffold(
          body: Text('POST_DETAIL:${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/clans',
        builder: (context, state) => const Scaffold(body: Text('CLANS_ROUTE')),
      ),
      GoRoute(
        path: '/comunidad/compose',
        builder: (context, state) =>
            const Scaffold(body: Text('COMPOSE_ROUTE')),
      ),
      GoRoute(
        path: '/comunidad/buscar',
        builder: (context, state) => const Scaffold(body: Text('SEARCH_ROUTE')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('LOGIN')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [homeProvider.overrideWith((ref) async => home),
      homeMatchdayPollProvider.overrideWith((ref, key) async => null),
      homeFeaturedProvider.overrideWith((ref) async {
        onFeaturedLoad?.call();
        return featured;
      })],
    child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  );
}

void main() {
  testWidgets('compact featured match keeps competition readable and time singular', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lima = limaWallClock(DateTime.now());
    final kickoff = DateTime(lima.year, lima.month, lima.day + 1, 19);
    final match = FootballMatch(id: 123, competitionId: 'LIGA_1',
      competition: 'Liga 1 Perú', round: 'Clausura · Fecha 11',
      home: 'Universitario', away: 'FBC Melgar', status: 'SCHEDULED',
      kickoff: kickoff, kickoffConfirmed: true);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: HomeFeaturedMatchCard(embedded: true, now: DateTime.now(),
        result: AsyncValue.data(FootballFeaturedResult(
          featured: FootballFeatured(next: match)))),
    ))));
    await tester.pump();
    expect(find.textContaining('Liga 1 Perú'), findsOneWidget);
    expect(find.textContaining('19:00 (hora de Lima)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('featured request is not repeated by feed tab changes', (tester) async {
    var calls = 0;
    await tester.pumpWidget(pumpHome(sampleHome(), onFeaturedLoad: () => calls++));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.tap(find.text('Siguiendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Para ti'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('HOME_LOADING_STATE', (tester) async {
    final completer = Completer<HomeModel>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeProvider.overrideWith((ref) => completer.future),
          homeMatchdayPollProvider.overrideWith((ref, key) async => null),
          homeFeaturedProvider.overrideWith((ref) async => const FootballFeaturedResult())],
        child: MaterialApp(theme: AppTheme.darkTheme, home: const HomePage()),
      ),
    );
    await tester.pump();
    expect(find.byType(GarraHomeSkeleton), findsOneWidget);
    completer.complete(sampleHome());
    await tester.pumpAndSettle();
  });

  testWidgets('HOME_UPCOMING_MATCH_STATE', (tester) async {
    await tester.pumpWidget(pumpHome(sampleHome(matchdayState: 'UPCOMING')));
    await tester.pumpAndSettle();
    expect(find.text('Para ti'), findsOneWidget);
    expect(find.textContaining('Próximo partido'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home_featured_open')));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL:123:LIGA_1'), findsOneWidget);
  });

  testWidgets('HOME_MATCHDAY_STATE', (tester) async {
    // PRODUCT-10A.2D: el estado del día se muestra una sola vez (pill
    // 'Hoy juega la U'); el bloque Matchday/check-in vivía en la pestaña
    // 'Partido', reemplazada por 'Marketplace'.
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(pumpHome(sampleHome(matchdayState: 'MATCHDAY')));
    await tester.pumpAndSettle();
    expect(find.text('Hoy juega la U'), findsOneWidget);
    expect(find.text('Para ti'), findsOneWidget);
    expect(find.text('Partido'), findsNothing);
  });

  testWidgets('HOME_LIVE_STATE', (tester) async {
    await tester.pumpWidget(pumpHome(sampleHome(matchdayState: 'LIVE')));
    await tester.pumpAndSettle();
    expect(find.textContaining('En vivo'), findsOneWidget);
    // PRODUCT-10A.2D: 'Entrar al partido' y el marcador del hero vivían en la
    // pestaña 'Partido' (reemplazada por 'Marketplace').
    expect(find.text('Partido'), findsNothing);
  });

  testWidgets('HOME_NO_MATCH_STATE', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      pumpHome(sampleHome(matchdayState: 'NO_MATCH', withMatch: false)),
    );
    // Feed load may keep a progress indicator animating; avoid pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('GARRA DIGITAL'), findsOneWidget);
    expect(find.text('Para ti'), findsOneWidget);
    expect(find.text('¿Qué vive la crema hoy?'), findsOneWidget);
    expect(find.text('LA TRIBUNA CREMA'), findsOneWidget);
  });

  testWidgets('HOME_PREDICTION_CTA', (tester) async {
    // PRODUCT-10A.2E: retargeted from Home 'Partido' tab to Centro · Para ti · Hoy.
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      pumpCentroMatchday(sampleHome(predictionState: 'NOT_PREDICTED')),
    );
    await tester.pumpAndSettle();
    final cta = find.text('Hacer predicción');
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('POLLA_ROUTE'), findsOneWidget);
  });

  testWidgets('HOME_NARROW_TEXT_SCALE_HAS_NO_OVERFLOW', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 700),
          textScaler: TextScaler.linear(1.2),
        ),
        child: pumpHome(sampleHome(matchdayState: 'MATCHDAY')),
      ),
    );
    await tester.pumpAndSettle();
    // PRODUCT-10A.2D: el titular repetido se eliminó; el estado queda en la pill.
    expect(find.text('Hoy juega la U'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HOME_CONTEXTUAL_CLAN_INSERT_STAYS_IN_SOCIAL_FEED', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpHome(
        sampleHome(
          matchdayState: 'NO_MATCH',
          withMatch: false,
          clan: const HomeClanSummary(
            slug: 'garra-surco',
            name: 'Garra Surco',
            memberCount: 1284,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const ValueKey('home-contextual-insert')),
      findsOneWidget,
    );
    expect(find.text('TU COMUNIDAD'), findsOneWidget);
    expect(find.text('Garra Surco'), findsOneWidget);
    expect(find.text('Para ti'), findsOneWidget);
  });

  testWidgets('Home Tribuna preview opens its exact post and Back returns Home',
      (tester) async {
    await tester.pumpWidget(pumpHome(sampleHome()));
    await tester.pumpAndSettle();
    expect(find.text('EN LA TRIBUNA'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-contextual-insert')));
    await tester.pumpAndSettle();
    expect(find.text('POST_DETAIL:p1'), findsOneWidget);
    expect(find.text('MURO_ROUTE'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('EN LA TRIBUNA'), findsOneWidget);
  });

  testWidgets('HOME_MATCH_COUNTDOWN_RENDERS_DD_HH_MM_SS_BLOCKS', (
    tester,
  ) async {
    // PRODUCT-10A.2E: retargeted from the Home 'Partido' hero to the match
    // detail (Centro Garra) expanded header.
    final lima = limaWallClock(DateTime.now());
    final kickoff = DateTime(lima.year, lima.month, lima.day)
        .add(const Duration(days: 2, hours: 19));
    await tester.pumpWidget(pumpMatchDetail(FootballMatch(id: 123,
      competitionId: 'LIGA_1', competition: 'Liga 1', home: 'Universitario',
      away: 'Rival FC', status: 'SCHEDULED', kickoff: kickoff,
      kickoffConfirmed: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('detail_countdown')), findsOneWidget);
    for (final unit in ['DD', 'HH', 'MM', 'SS']) {
      expect(find.byKey(ValueKey('countdown-$unit')), findsOneWidget);
      expect(find.text(unit), findsOneWidget);
    }
  });

  testWidgets('HOME_MATCHDAY_CHECKIN_IN_CENTRO', (tester) async {
    // PRODUCT-10A.2E: the check-in CTA of the ex Home 'Partido' tab
    // (HOME_MATCHDAY_STATE before 10A.2D) now lives in Centro · Para ti · Hoy.
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(pumpCentroMatchday(sampleHome(matchdayState: 'MATCHDAY')));
    await tester.pumpAndSettle();
    final checkIn = find.text('Hacer check-in');
    await tester.ensureVisible(checkIn);
    await tester.pumpAndSettle();
    expect(checkIn, findsOneWidget);
    await tester.tap(checkIn);
    await tester.pumpAndSettle();
    expect(find.text('MAPA_ROUTE:m1'), findsOneWidget);
  });

  testWidgets('HOME_PASSPORT_NAVIGATION', (tester) async {
    // Identity header removed from Home (V1 social feed); passport lives in Perfil.
  }, skip: true);

  testWidgets('HOME_NOTIFICATION_BADGE', (tester) async {
    await tester.pumpWidget(pumpHome(sampleHome(unread: 3)));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsWidgets);
    await tester.tap(find.byTooltip('Notificaciones'));
    await tester.pumpAndSettle();
    expect(find.text('NOTIF_ROUTE'), findsOneWidget);
  });

  testWidgets('HOME_ERROR_RETRY', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: GarraErrorState(onRetry: () => retried = true)),
      ),
    );
    expect(find.byType(GarraErrorState), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(retried, isTrue);
  });
}
