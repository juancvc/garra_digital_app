import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:go_router/go_router.dart';

HomeModel sampleHome({
  String matchdayState = 'UPCOMING',
  bool withMatch = true,
  String predictionState = 'NOT_PREDICTED',
  int unread = 3,
  bool withMission = false,
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
      predictionsOpen: predictionState == 'NOT_PREDICTED' ||
          predictionState == 'PREDICTED',
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
    streak: withMission
        ? const HomeStreakSummary(current: 2, best: 4)
        : null,
  );
}

Widget pumpHome(HomeModel home) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
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
          body: Text('MAPA_ROUTE:${state.uri.queryParameters['matchId'] ?? ''}'),
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
        builder: (context, state) =>
            const Scaffold(body: Text('SEARCH_ROUTE')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('LOGIN')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      homeProvider.overrideWith((ref) async => home),
    ],
    child: MaterialApp.router(
      theme: AppTheme.darkTheme,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('HOME_LOADING_STATE', (tester) async {
    final completer = Completer<HomeModel>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HomePage(),
        ),
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
    expect(find.text('Próximo partido'), findsOneWidget);
    expect(find.textContaining('Faltan'), findsOneWidget);
    expect(find.text('Rival FC'), findsOneWidget);
  });

  testWidgets('HOME_MATCHDAY_STATE', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(pumpHome(sampleHome(matchdayState: 'MATCHDAY')));
    await tester.pumpAndSettle();
    expect(find.text('Hoy juega la U'), findsOneWidget);
    expect(find.text('Entrar al Matchday'), findsOneWidget);
    final checkIn = find.text('Hacer check-in');
    await tester.ensureVisible(checkIn);
    await tester.pumpAndSettle();
    expect(checkIn, findsOneWidget);
    await tester.tap(checkIn);
    await tester.pumpAndSettle();
    expect(find.text('MAPA_ROUTE:m1'), findsOneWidget);
  });

  testWidgets('HOME_LIVE_STATE', (tester) async {
    await tester.pumpWidget(pumpHome(sampleHome(matchdayState: 'LIVE')));
    await tester.pumpAndSettle();
    expect(find.text('EN VIVO'), findsOneWidget);
    expect(find.text('Entrar al partido'), findsOneWidget);
    expect(find.textContaining('1 : 0'), findsOneWidget);
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
    expect(find.text('Garra Digital'), findsOneWidget);
    expect(find.text('Para ti'), findsOneWidget);
    expect(find.text('¿Qué vive la crema hoy?'), findsOneWidget);
  });

  testWidgets('HOME_PREDICTION_CTA', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      pumpHome(sampleHome(predictionState: 'NOT_PREDICTED')),
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
        home: Scaffold(
          body: GarraErrorState(onRetry: () => retried = true),
        ),
      ),
    );
    expect(find.byType(GarraErrorState), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(retried, isTrue);
  });
}
