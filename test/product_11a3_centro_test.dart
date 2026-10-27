import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/data/garra_football_service.dart';
import 'package:garra_digital_app/features/football/presentation/centro_garra_page.dart';
import 'package:go_router/go_router.dart';

/// PRODUCT-11A.3 — Centro Garra tabs on the 11A.2 contract (snapshotAt / ageSeconds / resultPending).
/// Synthetic data only, no network, fixed clock (2026-10-13 15:00 Lima = 20:00Z).

final _now = DateTime.utc(2026, 10, 13, 20);

class _Net extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

const _comps = [
  FootballCompetition(id: 'LIGA_1', name: 'Liga 1 Perú', available: true, region: 'PERU', group: 'peru'),
  FootballCompetition(id: 'UCL', name: 'Champions League', available: true, region: 'EUROPE', group: 'intl'),
];

Map<String, dynamic> _json(int id, {String comp = 'LIGA_1', String compName = 'Liga 1 Perú',
    String status = 'SCHEDULED', String kickoff = '2026-10-13T22:00:00Z', String home = 'Local',
    String away = 'Visita', bool featured = false, bool? resultPending, int? hs, int? as, int? elapsed,
    String? dataState}) => {
  'id': id, 'competitionId': comp, 'competition': compName, 'status': status, 'kickoff': kickoff,
  'home': {'name': '$home $id'}, 'away': {'name': '$away $id'}, 'featured': featured,
  'resultPending': ?resultPending, 'homeScore': ?hs, 'awayScore': ?as, 'elapsed': ?elapsed,
  'dataState': ?dataState,
};

FootballPage<FootballMatch> _page(List<Map<String, dynamic>> items, {int? ageSeconds, String? snapshotAt}) =>
    FootballPage.fromJson({'items': items, 'stale': false, 'unavailable': false, 'partial': false,
      'ageSeconds': ?ageSeconds, 'snapshotAt': ?snapshotAt}, FootballMatch.fromJson).withFetchedAt(_now);

class _Football extends GarraFootballService {
  _Football() : super(dio: Dio());
  final List<String> calls = [];
  Map<FootballView, FootballPage<FootballMatch>> pages = {};
  Map<String, FootballPage<FootballMatch>> byDate = {};
  FootballPage<Map<String, dynamic>>? table;
  Object? error;
  Completer<void>? gate;

  @override
  Future<List<FootballCompetition>> competitions() async => _comps;

  @override
  Future<FootballFeatured?> featured() async => null;

  @override
  Future<FootballPage<FootballMatch>> matches(FootballView view, {String? competition}) async {
    calls.add('matches:${view.wire}');
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return pages[view] ?? _page(const []);
  }

  @override
  Future<FootballPage<FootballMatch>> matchesOn(FootballView view, {String? competition, DateTime? date}) async {
    calls.add('matches:${view.wire}@${date == null ? 'today' : limaDateWire(date)}');
    return byDate[date == null ? '' : limaDateWire(date)] ?? _page(const []);
  }

  @override
  Future<FootballPage<Map<String, dynamic>>> standings(String competition) async {
    calls.add('standings:$competition');
    return table ?? const FootballPage(items: [], stale: false, unavailable: false, partial: false);
  }
}

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _pump(WidgetTester tester, _Football service) async {
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(initialLocation: '/centro-garra', routes: [
    GoRoute(path: '/centro-garra', builder: (_, _) => const CentroGarraPage()),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    garraFootballServiceProvider.overrideWithValue(service),
    connectivityStatusProvider.overrideWith(_Net.new),
  ], child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
}

Future<void> _section(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.byKey(ValueKey('section_$name')));
  await tester.pump();
  await tester.tap(find.byKey(ValueKey('section_$name')));
  await _settle(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  setUp(() => footballNow = () => _now);
  tearDown(() => footballNow = DateTime.now);

  group('models', () {
    test('Lima date: 23:30 Lima is still the same Lima day (04:30Z next UTC day)', () {
      expect(limaDateWire(limaDate(DateTime.utc(2026, 10, 14, 4, 30))), '2026-10-13');
      expect(limaDateWire(limaDate(DateTime.utc(2026, 10, 14, 5, 0))), '2026-10-14');
    });

    test('old backend response (no resultPending/snapshotAt/ageSeconds) parses with defaults', () {
      final page = FootballPage.fromJson({'items': [
        {'id': 1, 'competitionId': 'LIGA_1', 'status': 'FINISHED', 'home': {'name': 'A'}, 'away': {'name': 'B'}},
      ], 'stale': false}, FootballMatch.fromJson);
      expect(page.items.single.resultPending, isFalse);
      expect(page.snapshotAt, isNull);
      expect(page.ageSeconds, isNull);
      expect(footballFreshnessLabel(page), isNull, reason: 'nothing known → hidden');
      expect(footballFreshnessLabel(page.withFetchedAt(_now)), 'Consultado 15:00',
          reason: 'only receipt time → never "actualizado"');
    });

    test('freshness from ageSeconds and snapshotAt', () {
      expect(footballFreshnessLabel(_page(const [], ageSeconds: 30)), 'Actualizado hace menos de 1 min');
      expect(footballFreshnessLabel(_page(const [], ageSeconds: 600)), 'Actualizado hace 10 min');
      expect(footballFreshnessLabel(_page(const [], snapshotAt: '2026-10-13T17:00:00Z')), 'Actualizado hace 3 h');
    });

    test('UNKNOWN: pre-match only before kickoff; resultPending → por confirmar', () {
      final before = FootballMatch.fromJson(_json(1, status: 'UNKNOWN', kickoff: '2026-10-13T22:00:00Z'));
      final after = FootballMatch.fromJson(_json(2, status: 'UNKNOWN', kickoff: '2026-10-13T19:00:00Z'));
      final pending = FootballMatch.fromJson(_json(3, status: 'UNKNOWN', kickoff: '2026-10-13T22:00:00Z',
          resultPending: true, dataState: 'UNCONFIRMED'));
      expect(before.isPrematch, isTrue);
      expect(after.isPrematch, isFalse);
      expect(after.isLive, isFalse, reason: 'UNKNOWN is never LIVE');
      expect(after.statusLabel, 'POR CONFIRMAR');
      expect(pending.isPrematch, isFalse);
      expect(pending.statusLabel, 'RESULTADO POR CONFIRMAR');
      expect(pending.homeScore, isNull, reason: 'no invented score');
    });

    test('SUSPENDED stays SUSPENDED (live feed), never finished', () {
      final m = FootballMatch.fromJson(_json(4, status: 'SUSPENDED', hs: 1, as: 0));
      expect(m.isLive, isTrue);
      expect(m.isFinished, isFalse);
      expect(m.statusLabel, 'SUSPENDIDO');
    });

    test('service dedupes identical in-flight requests', () async {
      var hits = 0;
      final gate = Completer<void>();
      final dio = Dio()..interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
        hits++;
        await gate.future;
        h.resolve(Response(requestOptions: o, data: {'data': {'items': [], 'ageSeconds': 5}}));
      }));
      final service = GarraFootballService(dio: dio);
      final a = service.matches(FootballView.live);
      final b = service.matches(FootballView.live);
      gate.complete();
      final pages = await Future.wait([a, b]);
      expect(hits, 1);
      expect(pages[0].ageSeconds, 5);
      await service.matches(FootballView.live);
      expect(hits, 2, reason: 'a finished request is not cached forever');
    });
  });

  group('Hoy', () {
    testWidgets('groups by competition, Universitario/featured first, UCL multiple matches, no exclusion',
        (tester) async {
      final service = _Football()..pages[FootballView.today] = _page([
        for (var i = 1; i <= 9; i++) _json(100 + i, comp: 'UCL', compName: 'Champions League',
            kickoff: '2026-10-13T19:00:00Z', status: 'UNKNOWN', resultPending: true, dataState: 'UNCONFIRMED'),
        _json(1, featured: true, home: 'Universitario'),
        _json(2, home: 'Otro'),
      ], ageSeconds: 120);
      await _pump(tester, service);
      expect(find.byKey(const ValueKey('date_label')), findsOneWidget);
      expect(find.textContaining('Hoy · martes 13 de octubre'), findsOneWidget);
      final l1 = tester.getTopLeft(find.byKey(const ValueKey('comp_group_LIGA_1'))).dy;
      final ucl = tester.getTopLeft(find.byKey(const ValueKey('comp_group_UCL'))).dy;
      expect(l1, lessThan(ucl));
      expect(find.text('Ver todos (9)'), findsOneWidget, reason: 'all 9 UCL matches reachable, none dropped');
      await tester.tap(find.byKey(const ValueKey('ver_todos_UCL')));
      await _settle(tester);
      expect(find.text('Resultado por confirmar'), findsNWidgets(9));
      expect(find.text('Actualizado hace 2 min'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('date change requests that Lima day; back to today', (tester) async {
      final service = _Football()
        ..byDate['2026-10-14'] = _page([_json(7, comp: 'UCL', compName: 'Champions League',
            kickoff: '2026-10-14T19:00:00Z', home: 'Miércoles')]);
      await _pump(tester, service);
      await tester.tap(find.byKey(const ValueKey('date_next')));
      await _settle(tester);
      expect(service.calls, contains('matches:TODAY@2026-10-14'));
      expect(find.text('Miércoles 7'), findsOneWidget);
      expect(find.textContaining('miércoles 14 de octubre'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('date_prev')));
      await _settle(tester);
      expect(service.calls.last, 'matches:TODAY');
      await _unmount(tester);
    });

    testWidgets('empty and error states', (tester) async {
      final service = _Football();
      await _pump(tester, service);
      expect(find.text('Sin partidos hoy'), findsOneWidget);
      await _unmount(tester);
      final failing = _Football()..error = DioException(requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badResponse, response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: 500));
      await _pump(tester, failing);
      expect(find.text('Reintentar'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('En vivo', () {
    testWidgets('only live-feed statuses, SUSPENDED kept, UNKNOWN never live', (tester) async {
      final service = _Football()..pages[FootballView.live] = _page([
        _json(1, status: 'SECOND_HALF', elapsed: 60, hs: 1, as: 1, home: 'Juega'),
        _json(2, status: 'SUSPENDED', hs: 0, as: 0, home: 'Suspendido'),
        _json(3, status: 'UNKNOWN', kickoff: '2026-10-13T19:00:00Z', home: 'Desconocido'),
      ], ageSeconds: 90);
      await _pump(tester, service);
      await _section(tester, 'live');
      expect(find.text('Juega 1'), findsOneWidget);
      expect(find.text('Suspendido 2'), findsOneWidget);
      expect(find.text('Desconocido 3'), findsNothing);
      expect(find.text('Suspendido'), findsOneWidget, reason: 'SUSPENDED kept, not shown as EN VIVO');
      expect(find.text('Actualizado hace 1 min'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('refresh timer: only while tab visible + foreground; cancelled on tab change/pause/dispose',
        (tester) async {
      final service = _Football();
      await _pump(tester, service);
      await _section(tester, 'live');
      int live() => service.calls.where((c) => c == 'matches:LIVE').length;
      expect(live(), 1);
      await tester.pump(centroLiveRefreshInterval);
      await _settle(tester, 2);
      expect(live(), 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(centroLiveRefreshInterval * 3);
      expect(live(), 2, reason: 'no polling in background');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(centroLiveRefreshInterval);
      await _settle(tester, 2);
      expect(live(), 3);
      await _section(tester, 'today');
      await tester.pump(centroLiveRefreshInterval * 3);
      expect(live(), 3, reason: 'timer cancelled when leaving En vivo');
      await _section(tester, 'live');
      await _unmount(tester);
      await tester.pump(centroLiveRefreshInterval * 2);
      expect(live(), 4, reason: 'disposed: no further requests (one load on re-entering)');
    });

    testWidgets('fast tab switching does not duplicate an in-flight request', (tester) async {
      final service = _Football()..gate = Completer<void>();
      await _pump(tester, service);
      await _section(tester, 'live');
      await _section(tester, 'today');
      await _section(tester, 'live');
      expect(service.calls.where((c) => c == 'matches:LIVE').length, 1);
      service.gate!.complete();
      await _settle(tester);
      await _unmount(tester);
    });
  });

  group('Próximos', () {
    testWidgets('day navigation over backend window, POSTPONED/CANCELLED labels kept', (tester) async {
      final service = _Football()..pages[FootballView.upcoming] = _page([
        _json(1, kickoff: '2026-10-14T20:00:00Z', home: 'Mañana'),
        _json(2, kickoff: '2026-10-19T20:00:00Z', status: 'POSTPONED', home: 'Postergado'),
        _json(3, kickoff: '2026-10-19T19:00:00Z', status: 'CANCELLED', home: 'Cancelado'),
      ]);
      await _pump(tester, service);
      await _section(tester, 'upcoming');
      expect(find.byKey(const ValueKey('comp_group_LIGA_1')), findsOneWidget);
      expect(find.text('POST.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('upcoming_day_2026-10-19')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('upcoming_day_2026-10-19')));
      await _settle(tester);
      expect(find.text('Mañana 1'), findsNothing);
      expect(find.text('Postergado 2'), findsOneWidget);
      expect(find.text('Cancelado 3'), findsOneWidget);
      expect(find.text('CANC.'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('Resultados', () {
    testWidgets('recent by competition, newest first, resultPending + SUSPENDED + CANCELLED', (tester) async {
      final service = _Football()..pages[FootballView.results] = _page([
        _json(1, status: 'FINISHED', kickoff: '2026-10-11T20:00:00Z', hs: 2, as: 0, home: 'Primero'),
        _json(2, status: 'SUSPENDED', kickoff: '2026-10-12T20:00:00Z', hs: 1, as: 0, home: 'Segundo'),
        _json(3, status: 'UNKNOWN', kickoff: '2026-10-13T19:00:00Z', resultPending: true,
            dataState: 'UNCONFIRMED', home: 'Tercero'),
        _json(4, status: 'CANCELLED',
            kickoff: '2026-10-12T19:00:00Z', home: 'Anulado'),
      ], ageSeconds: 4000);
      await _pump(tester, service);
      await _section(tester, 'results');
      await tester.tap(find.byKey(const ValueKey('ver_todos_LIGA_1')));
      await _settle(tester);
      final y1 = tester.getTopLeft(find.text('Primero 1')).dy;
      final y2 = tester.getTopLeft(find.text('Segundo 2')).dy;
      final y3 = tester.getTopLeft(find.text('Tercero 3')).dy;
      expect(y3 < y2 && y2 < y1, isTrue, reason: 'real kickoff descending despite older API order');
      expect(find.text('Resultado por confirmar'), findsOneWidget);
      expect(find.text('Suspendido'), findsOneWidget);
      expect(find.text('CANC.'), findsOneWidget);
      expect(find.text('Actualizado hace 1 h'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('Tablas', () {
    testWidgets('Apertura/Clausura/Anual separated, phase shown, no "actualizada" without evidence',
        (tester) async {
      Map<String, dynamic> row(String g, int rank, String team) =>
          {'group': g, 'rank': rank, 'team': team, 'points': 10 - rank, 'played': 5};
      final service = _Football()..table = FootballPage.fromJson({'items': [
        row('Liga 1: Apertura', 1, 'Equipo Apertura'), row('Liga 1: Apertura', 2, 'Segundo Apertura'),
        row('Liga 1: Clausura', 1, 'Equipo Clausura'),
        row('Liga 1: Tabla Anual', 1, 'Equipo Anual'),
      ]}, (j) => j);
      await _pump(tester, service);
      await _section(tester, 'standings');
      expect(find.byKey(const ValueKey('stage_Liga 1: Apertura')), findsOneWidget);
      expect(find.byKey(const ValueKey('stage_Liga 1: Clausura')), findsOneWidget);
      expect(find.text('Equipo Clausura'), findsNothing, reason: 'phases are not concatenated');
      expect(find.text('Fase: Apertura'), findsOneWidget);
      expect(find.textContaining('Actualiza'), findsNothing, reason: 'old backend: no age → no claim');
      expect(find.byKey(const ValueKey('standings_freshness')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('stage_Liga 1: Clausura')));
      await _settle(tester);
      expect(find.text('Equipo Clausura'), findsOneWidget);
      expect(find.text('Fase: Clausura'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('standings snapshot age shown when provided', (tester) async {
      final service = _Football()..table = FootballPage.fromJson({'items': [
        {'group': 'UEFA Champions League', 'rank': 1, 'team': 'Club UCL', 'points': 6, 'played': 2},
      ], 'ageSeconds': 7200}, (j) => j).withFetchedAt(_now);
      await _pump(tester, service);
      await _section(tester, 'standings');
      expect(find.text('Actualizado hace 2 h'), findsOneWidget);
      await _unmount(tester);
    });
  });
}
