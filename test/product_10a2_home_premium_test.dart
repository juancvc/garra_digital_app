import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_feed_featured_block.dart';
import 'package:garra_digital_app/features/home/presentation/home_featured_match_card.dart';
import 'package:garra_digital_app/features/home/presentation/home_matchday_poll_card.dart';
import 'package:go_router/go_router.dart';

const scheduled = FootballMatch(
  id: 2811, competitionId: 'LIGA_1', competition: 'Liga 1 Perú',
  home: 'Universitario', away: 'FBC Melgar', status: 'SCHEDULED',
  kickoffConfirmed: true,
);

Widget surface(FootballFeaturedResult value, {bool largeText = false}) {
  final router = GoRouter(initialLocation: '/home', routes: [
    GoRoute(path: '/home', builder: (context, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: largeText ? const TextScaler.linear(1.6) : null),
      child: Scaffold(
        body: SingleChildScrollView(child: HomeFeedFeaturedBlock(
          featured: AsyncValue.data(value),
        )),
      ),
    )),
    GoRoute(path: '/centro-garra', builder: (_, _) => const Scaffold(
      body: Text('CENTRO'))),
    GoRoute(path: '/comunidad', builder: (_, _) => const Scaffold(
      body: Text('COMUNIDAD'))),
    GoRoute(path: '/marketplace', builder: (_, _) => const Scaffold(
      body: Text('MARKETPLACE'))),
    GoRoute(path: '/centro-garra/partido/:fixtureId', builder: (_, state) =>
      Scaffold(body: Text('FIXTURE:${state.pathParameters['fixtureId']}'))),
  ]);
  return ProviderScope(
    overrides: [homeMatchdayPollProvider.overrideWith((ref, key) async => null)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('trusted fixture leads, with existing route and no shortcut tiles',
      (tester) async {
    await tester.pumpWidget(surface(FootballFeaturedResult(
      featured: FootballFeatured(next: scheduled))));
    await tester.pumpAndSettle();
    expect(find.text('Universitario'), findsOneWidget);
    expect(find.text('FBC Melgar'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_tribuna_alive')), findsNothing);
    // PRODUCT-10A.2D: los accesos grandes Partidos/Comunidad/Marketplace se
    // retiraron de Home (Marketplace pasa a la pestaña superior).
    expect(find.byKey(const ValueKey('home_quick_partidos')), findsNothing);
    expect(find.byKey(const ValueKey('home_quick_comunidad')), findsNothing);
    expect(find.byKey(const ValueKey('home_quick_marketplace')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home_featured_open')));
    await tester.pumpAndSettle();
    expect(find.text('FIXTURE:2811'), findsOneWidget);
  });

  testWidgets('no trusted match gives Tribuna priority without fictitious data',
      (tester) async {
    await tester.pumpWidget(surface(FootballFeaturedResult(featured: null)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home_tribuna_alive')), findsOneWidget);
    expect(find.text('La pasión también se cuenta.'), findsOneWidget);
    expect(find.textContaining('Faltan'), findsNothing);
    expect(find.byType(HomeMatchdayPollCard), findsNothing);
  });

  testWidgets('unconfirmed fixture does not claim a reliable match',
      (tester) async {
    await tester.pumpWidget(surface(FootballFeaturedResult(featured:
      FootballFeatured(next: const FootballMatch(
        id: 11, competitionId: 'LIGA_1', competition: 'Liga 1',
        home: 'Universitario', away: 'Rival', status: 'UNKNOWN',
      )))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home_tribuna_alive')), findsOneWidget);
  });

  testWidgets('live and finished keep real scores without countdown',
      (tester) async {
    final live = FootballMatch(id: 17, competitionId: 'LIGA_1',
      competition: 'Liga 1', home: 'Universitario', away: 'Melgar',
      status: 'FIRST_HALF', homeScore: 1, awayScore: 0,
      elapsed: 34, dataState: 'LIVE_SNAPSHOT',
      snapshotAt: DateTime.now().toUtc());
    await tester.pumpWidget(surface(FootballFeaturedResult(
      featured: FootballFeatured(live: live))));
    await tester.pumpAndSettle();
    expect(find.text('1 - 0'), findsOneWidget);
    expect(find.text('En vivo'), findsOneWidget);
    expect(find.textContaining('Faltan'), findsNothing);

    const finished = FootballMatch(id: 18, competitionId: 'LIGA_1',
      competition: 'Liga 1', home: 'Universitario', away: 'Melgar',
      status: 'FINISHED', homeScore: 2, awayScore: 1);
    await tester.pumpWidget(surface(FootballFeaturedResult(
      featured: const FootballFeatured(last: finished))));
    await tester.pumpAndSettle();
    expect(find.text('2 - 1'), findsOneWidget);
    expect(find.text('Finalizado'), findsOneWidget);
    expect(find.textContaining('Faltan'), findsNothing);
  });

  testWidgets('postponed shows uncertainty rather than a kickoff',
      (tester) async {
    await tester.pumpWidget(surface(FootballFeaturedResult(featured:
      const FootballFeatured(next: FootballMatch(
        id: 19, competitionId: 'LIGA_1', competition: 'Liga 1',
        home: 'Universitario', away: 'Melgar', status: 'POSTPONED',
        kickoffConfirmed: false,
      )))));
    await tester.pumpAndSettle();
    expect(find.text('Postergado'), findsOneWidget);
    expect(find.text('Nueva fecha por confirmar'), findsOneWidget);
    expect(find.textContaining('Faltan'), findsNothing);
  });

  testWidgets('narrow screen and enlarged text do not overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(surface(
      FootballFeaturedResult(featured: FootballFeatured(
        next: const FootballMatch(
          id: 33, competitionId: 'LIGA_1',
          competition: 'Liga 1 Perú · Torneo Clausura · Jornada larga',
          home: 'Universitario de Deportes', away: 'Football Club Melgar',
          status: 'SCHEDULED', kickoffConfirmed: false,
        ),
      )),
      largeText: true,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('status never promotes suspended to confirmed live', () {
    const suspended = FootballMatch(id: 1, competitionId: 'LIGA_1',
      competition: 'Liga 1', home: 'U', away: 'R', status: 'SUSPENDED',
      dataState: 'LIVE_SNAPSHOT');
    expect(homeFeaturedStatus(suspended, stale: false), 'Suspendido');
  });
}
