import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/data/garra_football_service.dart';
import 'package:garra_digital_app/features/football/presentation/centro_garra_page.dart';
import 'package:go_router/go_router.dart';

class _Network extends ConnectivityStatusController {
  @override NetworkConnectivity build() => NetworkConnectivity.online;
  void offline() => state = NetworkConnectivity.offline;
}

class _Football extends GarraFootballService {
  _Football() : super(dio: Dio());
  int calls = 0;
  final List<String?> detailSections = [];
  bool unavailable = false;

  @override
  Future<List<FootballCompetition>> competitions() async => const [
    FootballCompetition(id: 'LIGA_1', name: 'Liga 1 Perú', available: true),
    FootballCompetition(id: 'LIGA_2', name: 'Liga 2 Perú', available: false),
  ];

  @override
  Future<FootballPage<FootballMatch>> matches(FootballView view, {String? competition}) async {
    calls++;
    return FootballPage(items: unavailable ? const [] : [FootballMatch(
      id: 123, competitionId: 'LIGA_1', competition: 'Liga 1 Perú',
      home: 'Universitario', away: 'Rival', status: switch (view) {
        FootballView.live => 'LIVE',
        FootballView.results => 'FINISHED',
        _ => 'SCHEDULED',
      },
      kickoff: DateTime(2026, 10, 2, 20),
      homeScore: view == FootballView.results ? 2 : null,
      awayScore: view == FootballView.results ? 1 : null,
      garraMatchId: view == FootballView.live ? '11111111-1111-1111-1111-111111111111' : null,
    )], stale: false, unavailable: unavailable, partial: false);
  }

  @override
  Future<FootballPage<Map<String, dynamic>>> standings(String competition) async {
    calls++;
    return const FootballPage(items: [
      {'group': 'A', 'rank': 1, 'team': 'Universitario', 'points': 10},
    ], stale: false, unavailable: false, partial: false);
  }

  @override
  Future<FootballDetail?> detail(FootballMatch match, {String? section}) async {
    calls++;
    detailSections.add(section);
    return FootballDetail(match: match,
      events: section == 'EVENTS' ? const [{'type': 'GOAL', 'player': 'Jugador'}] : const [],
      lineups: const [], statistics: const [], partial: false, stale: false);
  }
}

class _UnconfiguredFootball extends _Football {
  @override
  Future<List<FootballCompetition>> competitions() async => const [
    FootballCompetition(id: 'LIGA_1', name: 'Liga 1 Perú', available: false),
    FootballCompetition(id: 'LIGA_2', name: 'Liga 2 Perú', available: false),
  ];
}

GoRouter _router(FootballMatch match) => GoRouter(initialLocation: '/centro-garra', routes: [
  GoRoute(path: '/centro-garra', builder: (_, _) => const CentroGarraPage(), routes: [
    GoRoute(path: 'partido/:fixtureId', builder: (_, _) => CentroGarraMatchDetailPage(match: match)),
  ]),
  GoRoute(path: '/matchday/:id/polls', builder: (_, _) => const Scaffold(body: Text('TRIBUNA'))),
]);

void main() {
  final match = FootballMatch(id: 123, competitionId: 'LIGA_1',
    competition: 'Liga 1 Perú', home: 'Universitario', away: 'Rival', status: 'LIVE',
    garraMatchId: '11111111-1111-1111-1111-111111111111');

  test('match model tolerates missing fields and normalizes kickoff to device time', () {
    final parsed = FootballMatch.fromJson({
      'id': 9, 'competitionId': 'LIGA_1', 'status': 'SCHEDULED',
      'kickoff': '2026-10-03T01:00:00Z',
    });
    expect(parsed.home, 'Por confirmar');
    expect(parsed.awayScore, isNull);
    expect(parsed.kickoff?.isUtc, isFalse);
    expect(parsed.statusLabel, 'PROGRAMADO');
  });

  testWidgets('Centro renders sections, scheduled/live/finished cards and table', (tester) async {
    final service = _Football();
    final router = _router(match);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      garraFootballServiceProvider.overrideWithValue(service),
      connectivityStatusProvider.overrideWith(_Network.new),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('Centro Garra'), findsOneWidget);
    expect(find.text('PROGRAMADO'), findsOneWidget);
    await tester.tap(find.text('En vivo'));
    await tester.pumpAndSettle();
    expect(find.text('EN VIVO'), findsOneWidget);
    await tester.tap(find.text('Resultados'));
    await tester.pumpAndSettle();
    expect(find.text('2 : 1'), findsOneWidget);
    await tester.tap(find.text('Próximos'));
    await tester.pumpAndSettle();
    expect(find.text('PROGRAMADO'), findsOneWidget);
    await tester.tap(find.text('Tabla'));
    await tester.pumpAndSettle();
    expect(find.text('10 pts'), findsOneWidget);
  });

  testWidgets('offline retains loaded content and starts no new request', (tester) async {
    final service = _Football();
    final container = ProviderContainer(overrides: [
      garraFootballServiceProvider.overrideWithValue(service),
      connectivityStatusProvider.overrideWith(_Network.new),
    ]);
    addTearDown(container.dispose);
    final router = _router(match);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    (container.read(connectivityStatusProvider.notifier) as _Network).offline();
    await tester.pump();
    expect(find.text('Universitario'), findsOneWidget);
    await tester.tap(find.text('En vivo'));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(find.text('Sin conexión'), findsWidgets);
  });

  testWidgets('unconfigured competitions show one compact notice and no futile retry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _UnconfiguredFootball();
    final router = _router(match);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      garraFootballServiceProvider.overrideWithValue(service),
      connectivityStatusProvider.overrideWith(_Network.new),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('Competiciones por activar'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(service.calls, 0);
    await tester.drag(find.byType(Scrollbar).first, const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(find.text('Resultados').hitTestable(), findsOneWidget);
  });

  testWidgets('detail stays useful without lineups or statistics and links Tribuna', (tester) async {
    final service = _Football();
    final router = _router(match);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      garraFootballServiceProvider.overrideWithValue(service),
      connectivityStatusProvider.overrideWith(_Network.new),
    ], child: MaterialApp.router(routerConfig: router)));
    router.go('/centro-garra/partido/123');
    await tester.pumpAndSettle();
    expect(find.text('Entrar a Tribuna Garra'), findsOneWidget);
    expect(service.detailSections, [null]);
    expect(find.text('Alineaciones'), findsOneWidget);
    expect(find.text('Estadísticas'), findsOneWidget);
    await tester.tap(find.text('Momentos del partido'));
    await tester.pumpAndSettle();
    expect(service.detailSections, [null, 'EVENTS']);
    expect(find.text('Jugador'), findsOneWidget);
    await tester.tap(find.text('Entrar a Tribuna Garra'));
    await tester.pumpAndSettle();
    expect(find.text('TRIBUNA'), findsOneWidget);
  });

  testWidgets('detail sections do not request provider data while offline', (tester) async {
    final service = _Football();
    final container = ProviderContainer(overrides: [
      garraFootballServiceProvider.overrideWithValue(service),
      connectivityStatusProvider.overrideWith(_Network.new),
    ]);
    addTearDown(container.dispose);
    final router = _router(match);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp.router(routerConfig: router)));
    router.go('/centro-garra/partido/123');
    await tester.pumpAndSettle();
    expect(service.detailSections, [null]);
    (container.read(connectivityStatusProvider.notifier) as _Network).offline();
    await tester.pump();
    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();
    expect(service.detailSections, [null]);
    expect(find.text('No pudimos cargar esta información'), findsOneWidget);
  });

  testWidgets('without mapping detail degrades CTA and unavailable list shows state', (tester) async {
    final service = _Football()..unavailable = true;
    final unlinked = FootballMatch(id: 123, competitionId: 'LIGA_1',
      competition: 'Liga 1 Perú', home: 'Home', away: 'Away', status: 'UNKNOWN');
    final router = _router(unlinked);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      garraFootballServiceProvider.overrideWithValue(service),
      connectivityStatusProvider.overrideWith(_Network.new),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('Fútbol temporalmente no disponible'), findsWidgets);
    router.go('/centro-garra/partido/123');
    await tester.pumpAndSettle();
    expect(find.text('Aún no está vinculada a este partido'), findsOneWidget);
  });
}
