import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/data/wall_status_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/data/garra_football_service.dart';
import 'package:garra_digital_app/features/football/presentation/centro_garra_page.dart';
import 'package:garra_digital_app/features/football/presentation/chat_futbolero_page.dart';
import 'package:garra_digital_app/features/football/presentation/football_event_timeline.dart';
import 'package:garra_digital_app/features/football/presentation/football_match_card.dart';
import 'package:go_router/go_router.dart';

/// SONIC_04 — Centro Garra Match Center UX. Backend contract only, no provider.

class _Net extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

class _Community extends CommunityService {
  _Community() : super(dio: Dio());
  @override
  Future<WallStatusModel?> getCurrentWallStatus() async => null;
  @override
  Future<List<WallPostModel>> getPosts({required String matchId, String? locationTag}) async => const [];
}

class _Chat extends FootballChatService {
  _Chat() : super(dio: Dio());
  @override
  Future<FootballChatPage> page(FootballChatContext context, {DateTime? before, int size = 30}) async =>
      const FootballChatPage(items: [], hasMore: false);
}

const _comps = [
  FootballCompetition(id: 'LIGA_1', name: 'Liga 1 Perú', available: true, region: 'PERU', group: 'peru'),
  FootballCompetition(id: 'LIGA_2', name: 'Liga 2 Perú', available: true, region: 'PERU', group: 'peru'),
  FootballCompetition(id: 'UCL', name: 'Champions League', available: true, region: 'EUROPE', group: 'europe'),
];

class _Football extends GarraFootballService {
  _Football({this.list = const [], this.featuredValue, this.table = const [], this.partial = false})
      : super(dio: Dio());
  List<FootballMatch> list;
  FootballFeatured? featuredValue;
  List<Map<String, dynamic>> table;
  bool partial;
  final List<String> calls = [];
  FootballDetail? Function(FootballMatch match, String? section)? onDetail;

  @override
  Future<List<FootballCompetition>> competitions() async => _comps;

  @override
  Future<FootballPage<FootballMatch>> matches(FootballView view, {String? competition}) async {
    calls.add('matches:${view.wire}:${competition ?? 'ALL'}');
    final items = competition == null ? list : list.where((m) => m.competitionId == competition).toList();
    return FootballPage(items: items, stale: false, unavailable: false, partial: partial);
  }

  @override
  Future<FootballFeatured?> featured() async {
    calls.add('featured');
    return featuredValue;
  }

  @override
  Future<FootballPage<Map<String, dynamic>>> standings(String competition) async {
    calls.add('standings:$competition');
    return FootballPage(items: table, stale: false, unavailable: false, partial: false);
  }

  @override
  Future<FootballDetail?> detail(FootballMatch match, {String? section}) async {
    calls.add('detail:${section ?? 'BASE'}');
    final custom = onDetail?.call(match, section);
    if (custom != null) return custom;
    return FootballDetail(match: match, events: const [], lineups: const [], statistics: const [],
        partial: false, stale: false);
  }
}

FootballMatch _m(int id, {String comp = 'LIGA_1', String compName = 'Liga 1 Perú', String status = 'SCHEDULED',
    bool featured = false, String home = 'Local', String away = 'Visita', int? elapsed, int? hs, int? as,
    DateTime? snapshot, String? dataState, DateTime? kickoff}) => FootballMatch(
  id: id, competitionId: comp, competition: compName, home: home, away: away, status: status,
  kickoff: kickoff ?? DateTime(2026, 10, 6, 20), featured: featured, elapsed: elapsed,
  homeScore: hs, awayScore: as, snapshotAt: snapshot, dataState: dataState, round: 'Regular Season - 9');

Future<void> _settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
}

/// The detail header state line is the single temporal truth on screen.
String? _stateLine(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('match_state_line'))).data;

Future<void> _tapTab(WidgetTester tester, String label, [int frames = 12]) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.pump();
  await tester.tap(tab);
  await _settle(tester, frames);
}

Future<GoRouter> _pumpHub(WidgetTester tester, _Football service,
    {ProviderContainer? container, Size size = const Size(390, 1200)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(initialLocation: '/centro-garra', routes: [
    GoRoute(path: '/centro-garra', builder: (_, _) => const CentroGarraPage(), routes: [
      GoRoute(path: 'chat-futbolero', builder: (_, state) =>
          Scaffold(body: Text('CHAT ${state.uri.queryParameters['tema'] ?? ''}'))),
      GoRoute(path: 'partido/:id', builder: (_, state) =>
          CentroGarraMatchDetailPage(match: state.extra as FootballMatch)),
    ]),
  ]);
  addTearDown(router.dispose);
  final overrides = [
    garraFootballServiceProvider.overrideWithValue(service),
    connectivityStatusProvider.overrideWith(_Net.new),
    communityServiceProvider.overrideWithValue(_Community()),
  ];
  if (container != null) {
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
        child: MaterialApp.router(routerConfig: router)));
  } else {
    await tester.pumpWidget(ProviderScope(overrides: overrides,
        child: MaterialApp.router(routerConfig: router)));
  }
  await _settle(tester);
  return router;
}

Future<void> _pumpDetail(WidgetTester tester, _Football service, FootballMatch match,
    {Size size = const Size(360, 1000), List<String>? visited}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(initialLocation: '/d', routes: [
    GoRoute(path: '/d', builder: (_, _) => CentroGarraMatchDetailPage(match: match)),
    GoRoute(path: '/centro-garra/chat-futbolero', builder: (_, state) {
      visited?.add(state.uri.queryParameters['tema'] ?? '');
      return const Scaffold(body: Text('CHAT'));
    }),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    garraFootballServiceProvider.overrideWithValue(service),
    connectivityStatusProvider.overrideWith(_Net.new),
    communityServiceProvider.overrideWithValue(_Community()),
  ], child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
}

void main() {
  group('contract and pure helpers', () {
    test('snapshot / dataState parse; unconfirmed never shows a minute', () {
      final m = FootballMatch.fromJson({'id': 1, 'competitionId': 'LIGA_2', 'status': 'LIVE',
        'elapsed': 2, 'dataState': 'UNCONFIRMED', 'snapshotAt': '2026-10-06T21:00:00Z',
        'home': {'name': 'Minas'}, 'away': {'name': 'Unión Comercio'}});
      expect(m.isUnconfirmed, isTrue);
      expect(m.liveMinuteLabel, isNull);
      expect(m.statusLabel, 'EN JUEGO · ACTUALIZANDO');
      expect(m.snapshotAt, DateTime.utc(2026, 10, 6, 21));
      final unknown = FootballMatch.fromJson({'id': 2, 'status': 'UNKNOWN', 'dataState': 'UNCONFIRMED'});
      expect(unknown.statusLabel, 'POR CONFIRMAR');
    });

    test('freshest snapshot wins; without timestamps the latest answer wins', () {
      final old = _m(1, status: 'FIRST_HALF', elapsed: 2, snapshot: DateTime.utc(2026, 10, 6, 21));
      final fresh = _m(1, status: 'SECOND_HALF', elapsed: 84, snapshot: DateTime.utc(2026, 10, 6, 22, 30));
      expect(FootballMatch.fresher(old, fresh).elapsed, 84);
      expect(FootballMatch.fresher(fresh, old).elapsed, 84);
      expect(FootballMatch.fresher(_m(1, elapsed: 2), _m(1, elapsed: 50)).elapsed, 50);
      final degraded = fresh.degraded();
      expect(degraded.elapsed, isNull);
      expect(degraded.isUnconfirmed, isTrue);
      expect(degraded.homeScore, fresh.homeScore);
    });

    test('stage labels are normalized for presentation only', () {
      expect(footballStageLabel('Primera División: Tabla Anual'), 'Tabla anual');
      expect(footballStageLabel('Liga 1: Apertura'), 'Apertura');
      expect(footballStageLabel('Clausura'), 'Clausura');
      expect(footballStageLabel('Group A'), 'Grupo A');
      expect(footballStageLabel(''), 'Tabla');
      expect(footballStageLabel(null), 'Tabla');
      final stages = FootballStandingStage.fromRows([
        {'group': 'Primera División: Apertura', 'rank': 1},
        {'group': 'Primera División: Tabla Anual', 'rank': 1},
      ]);
      expect(stages.map((s) => s.name), ['Primera División: Apertura', 'Primera División: Tabla Anual']);
    });

    test('events: minute order with extra time, semantic kinds, latest minute', () {
      final sorted = sortFootballEvents([
        {'elapsed': 86, 'player': 'B'},
        {'elapsed': 45, 'extra': 2, 'player': 'E'},
        {'elapsed': 84, 'player': 'A1'},
        {'elapsed': 45, 'player': 'F'},
        {'elapsed': 84, 'player': 'A2'},
      ]);
      expect(sorted.map((e) => e['player']), ['F', 'E', 'A1', 'A2', 'B']);
      expect(latestEventMinute(sorted), (86, 0));
      expect(footballEventKind('GOAL', detail: 'Own Goal'), FootballEventKind.ownGoal);
      expect(footballEventKind('GOAL', detail: 'Missed Penalty'), FootballEventKind.missedPenalty);
      expect(footballEventKind('YELLOW_CARD', detail: 'Second Yellow card'), FootballEventKind.secondYellow);
      expect(footballEventKind('OTHER', detail: 'Goal cancelled'), FootballEventKind.videoReview);
      expect(footballEventKind('SUBSTITUTION'), FootballEventKind.substitution);
    });

    test('featured hero name comes from config label or provider name, never code', () {
      final f = FootballFeatured.fromJson({'teamId': 2540, 'teamName': 'Equipo Proveedor', 'label': '',
        'competitionIds': ['LIGA_1'], 'next': {'id': 5, 'status': 'SCHEDULED', 'home': {}, 'away': {}}});
      expect(f.displayName, 'Equipo Proveedor');
      expect(f.next?.id, 5);
      expect(FootballFeatured.fromJson({'teamId': 1, 'teamName': 'X', 'label': 'La Crema'}).displayName, 'La Crema');
    });
  });

  testWidgets('PARA TI: featured LIVE hero first, then OTROS PARTIDOS without all competitions', (tester) async {
    final hero = _m(10, status: 'SECOND_HALF', elapsed: 70, featured: true, home: 'Equipo Destacado',
        hs: 1, as: 0);
    final service = _Football(
      featuredValue: FootballFeatured(teamId: 2540, teamName: 'Equipo Destacado', label: 'Crema',
          competitionIds: const ['LIGA_1'], live: hero,
          next: _m(11, featured: true, home: 'Equipo Destacado', kickoff: DateTime(2026, 10, 12, 18))),
      list: [
        hero,
        _m(20, home: 'Liga Uno A', away: 'Liga Uno B'),
        _m(30, comp: 'UCL', compName: 'Champions League', status: 'FIRST_HALF', elapsed: 12,
            home: 'Europa Live', away: 'Rival E', hs: 0, as: 0),
        _m(31, comp: 'UCL', compName: 'Champions League', home: 'Europa Programado', away: 'Rival P'),
        _m(40, comp: 'LIGA_2', compName: 'Liga 2 Perú', home: 'Segunda A', away: 'Segunda B'),
      ],
    );
    await _pumpHub(tester, service);
    expect(find.byKey(const ValueKey('featured_hero')), findsOneWidget);
    expect(find.text('CREMA EN VIVO'), findsOneWidget);
    expect(find.byKey(const ValueKey('featured_secondary_Próximo')), findsOneWidget);
    expect(find.byKey(const ValueKey('others_header')), findsOneWidget);
    expect(find.text('Equipo Destacado'), findsOneWidget, reason: 'hero is not repeated in others');
    expect(find.text('Liga Uno A'), findsOneWidget);
    expect(find.text('Europa Live'), findsOneWidget);
    expect(find.text('Europa Programado'), findsNothing, reason: 'Para ti is not all competitions');
    expect(find.text('Segunda A'), findsNothing);
    // Featured competition group comes before the live-only group.
    final liga1 = tester.getTopLeft(find.byKey(const ValueKey('comp_group_LIGA_1'))).dy;
    final ucl = tester.getTopLeft(find.byKey(const ValueKey('comp_group_UCL'))).dy;
    expect(liga1, lessThan(ucl));
    expect(service.calls.where((c) => c == 'featured').length, 1);
  });

  testWidgets('PARA TI hero falls back to next, then last, named from provider team', (tester) async {
    final service = _Football(featuredValue: FootballFeatured(teamId: 2540, teamName: 'Club Proveedor',
        competitionIds: const ['LIGA_1'],
        next: _m(11, featured: true, home: 'Club Proveedor'),
        last: _m(9, featured: true, status: 'FINISHED', home: 'Club Proveedor', hs: 2, as: 1)));
    await _pumpHub(tester, service);
    expect(find.text('PRÓXIMO PARTIDO DE CLUB PROVEEDOR'), findsOneWidget);
    expect(find.byKey(const ValueKey('featured_secondary_Último')), findsOneWidget);
    await _pumpHub(tester, _Football(featuredValue: FootballFeatured(teamId: 2540, teamName: 'Club Proveedor',
        last: _m(9, featured: true, status: 'FINISHED', home: 'Club Proveedor', hs: 2, as: 1))));
    expect(find.text('ÚLTIMO PARTIDO'), findsOneWidget);
    expect(find.text('FINAL'), findsOneWidget);
  });

  testWidgets('grouping: ~3 per competition, Ver todos, collapsible header', (tester) async {
    final service = _Football(list: [for (var i = 1; i <= 5; i++) _m(i, home: 'Local $i', away: 'Visita $i')]);
    await _pumpHub(tester, service);
    await _tapKey(tester, 'hub_peru');
    await _settle(tester);
    expect(find.byType(FootballMatchCard), findsNWidgets(3));
    expect(find.text('Ver todos (5)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ver_todos_LIGA_1')));
    await _settle(tester);
    expect(find.byType(FootballMatchCard), findsNWidgets(5));
    await tester.tap(find.byKey(const ValueKey('comp_toggle_LIGA_1')));
    await _settle(tester);
    expect(find.byType(FootballMatchCard), findsNothing);
  });

  testWidgets('navigation V4: competition bottom sheet; selection persists across detail', (tester) async {
    final service = _Football(list: [
      _m(1, home: 'Primera A'),
      _m(2, comp: 'LIGA_2', compName: 'Liga 2 Perú', home: 'Segunda A'),
      _m(3, comp: 'UCL', compName: 'Champions League', home: 'Europa A'),
    ]);
    final container = ProviderContainer(overrides: [
      garraFootballServiceProvider.overrideWithValue(service),
      connectivityStatusProvider.overrideWith(_Net.new),
      communityServiceProvider.overrideWithValue(_Community()),
    ]);
    addTearDown(container.dispose);
    final router = await _pumpHub(tester, service, container: container);
    expect(find.byKey(const ValueKey('competition_filter')), findsNothing, reason: 'Para ti has no filter');
    await _tapKey(tester, 'hub_peru');
    await _settle(tester);
    expect(find.text('Europa A'), findsNothing, reason: 'Perú keeps its region');
    expect(find.text('Primera A'), findsOneWidget);
    expect(find.text('Segunda A'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('competition_filter')));
    await _settle(tester, 10);
    expect(find.byKey(const ValueKey('competition_option_LIGA_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('competition_option_UCL')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('competition_option_LIGA_2')));
    await _settle(tester, 10);
    expect(service.calls.last, 'matches:TODAY:LIGA_2');
    expect(find.text('Primera A'), findsNothing);
    expect(container.read(centroGarraNavProvider).competition, 'LIGA_2');
    await tester.tap(find.text('Segunda A'));
    await _settle(tester, 10);
    expect(find.byType(CentroGarraMatchDetailPage), findsOneWidget);
    router.pop();
    await _settle(tester, 10);
    final filter = tester.widget<OutlinedButton>(find.byKey(const ValueKey('competition_filter')));
    expect(filter, isNotNull);
    expect(find.descendant(of: find.byKey(const ValueKey('competition_filter')),
        matching: find.text('Liga 2 Perú')), findsOneWidget);
    expect(container.read(centroGarraNavProvider).hub, CentroHub.peru);
  });

  testWidgets('standings V3: competition name, compact stage pills, featured row by team id', (tester) async {
    final service = _Football(
      featuredValue: const FootballFeatured(teamId: 2540, teamName: 'Crema', competitionIds: ['LIGA_1']),
      table: [
        {'group': 'Primera División: Apertura', 'rank': 1, 'team': 'Otro', 'teamId': 7, 'played': 9,
          'goalDifference': 5, 'points': 20},
        {'group': 'Primera División: Apertura', 'rank': 2, 'team': 'Crema', 'teamId': 2540, 'played': 9,
          'goalDifference': 4, 'points': 18, 'featured': false},
        {'group': 'Primera División: Tabla Anual', 'rank': 1, 'team': 'Crema', 'teamId': 2540, 'played': 27,
          'goalDifference': 21, 'points': 60},
      ]);
    await _pumpHub(tester, service);
    await _tapKey(tester, 'section_standings');
    await _settle(tester, 10);
    expect(service.calls, contains('standings:LIGA_1'));
    expect(find.byKey(const ValueKey('standings_competition')), findsOneWidget);
    expect(find.text('Liga 1 Perú'), findsOneWidget);
    for (final h in ['POS', 'EQUIPO', 'PJ', 'DG', 'PTS']) {
      expect(find.text(h), findsOneWidget);
    }
    expect(find.text('Apertura'), findsOneWidget);
    expect(find.text('Tabla anual'), findsOneWidget);
    expect(find.text('Primera División: Tabla Anual'), findsNothing);
    expect(find.byKey(const ValueKey('standing_featured_row')), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    await tester.tap(find.text('Tabla anual'));
    await _settle(tester);
    expect(find.text('+21'), findsOneWidget);
    expect(find.text('+4'), findsNothing);
  });

  testWidgets('standings with many groups use a compact sheet selector', (tester) async {
    final service = _Football(table: [
      for (final g in ['A', 'B', 'C', 'D', 'E', 'F'])
        {'group': 'Group $g', 'rank': 1, 'team': 'Lider $g', 'played': 3, 'goalDifference': 2, 'points': 7},
    ]);
    await _pumpHub(tester, service);
    await _tapKey(tester, 'hub_international');
    await _settle(tester);
    await _tapKey(tester, 'section_standings');
    await _settle(tester, 10);
    // SONIC_06A: bare "Group A..F" share one stage and use a group sheet selector.
    expect(find.byKey(const ValueKey('group_selector')), findsOneWidget);
    expect(find.text('Lider A'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('group_selector')));
    await _settle(tester, 10);
    await tester.tap(find.byKey(const ValueKey('group_option_Group C')));
    await _settle(tester, 10);
    expect(find.text('Lider C'), findsOneWidget);
    expect(find.text('Lider A'), findsNothing);
    expect(find.text('Grupo C'), findsOneWidget);
  });

  testWidgets('partial availability is a soft note, not a global outage', (tester) async {
    final service = _Football(partial: true, list: [_m(1, home: 'Primera A')]);
    await _pumpHub(tester, service);
    expect(find.byKey(const ValueKey('partial_notice')), findsOneWidget);
    expect(find.text('Primera A'), findsOneWidget);
    expect(find.text('Fútbol temporalmente no disponible'), findsNothing);
    service.list = const [];
    await _tapKey(tester, 'section_live');
    await _settle(tester);
    expect(find.text('Ningún partido en vivo ahora'), findsOneWidget);
    expect(find.byKey(const ValueKey('partial_notice')), findsOneWidget);
    expect(find.text('Fútbol temporalmente no disponible'), findsNothing);
  });

  testWidgets('match card V3: live minute first, prematch time, finished FINAL, long names 2 lines', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [
      FootballMatchCard(match: _m(1, status: 'SECOND_HALF', elapsed: 67, hs: 2, as: 1, featured: true), onTap: () {}),
      FootballMatchCard(match: _m(2, kickoff: DateTime(2026, 10, 7, 20, 30)), onTap: () {}),
      FootballMatchCard(match: _m(3, status: 'FINISHED', hs: 0, as: 3), onTap: () {}),
      FootballMatchCard(match: _m(4, status: 'LIVE', dataState: 'UNCONFIRMED', hs: 0, as: 0), onTap: () {}),
      FootballMatchCard(match: _m(5, home: 'Club Deportivo Universidad Técnica de Cajamarca de la Sierra',
          away: 'Asociación Deportiva Tarma'), onTap: () {}),
    ]))));
    expect(find.text('67′'), findsOneWidget);
    expect(find.text('EN VIVO'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('score_home_1'))).data, '2');
    expect(find.text('20:30'), findsOneWidget);
    expect(find.text('FINAL'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('score_away_3'))).data, '3');
    expect(find.text('Actualizando'), findsOneWidget);
    final long = tester.widget<Text>(find.textContaining('Universidad Técnica'));
    expect(long.maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P0: header follows the freshest snapshot and never contradicts events', (tester) async {
    final t0 = DateTime.utc(2026, 10, 6, 21, 2);
    final listMatch = _m(9, comp: 'LIGA_2', compName: 'Liga 2 Perú', status: 'FIRST_HALF', elapsed: 2,
        home: 'Minas', away: 'Unión Comercio', hs: 0, as: 0, snapshot: t0);
    final service = _Football()
      ..onDetail = (match, section) {
        if (section == null) {
          return FootballDetail(match: _m(9, comp: 'LIGA_2', compName: 'Liga 2 Perú', status: 'SECOND_HALF',
              elapsed: 80, home: 'Minas', away: 'Unión Comercio', hs: 0, as: 0,
              snapshot: t0.add(const Duration(minutes: 88)), dataState: 'LIVE_SNAPSHOT'),
              events: const [], lineups: const [], statistics: const [], partial: false, stale: false);
        }
        if (section == 'EVENTS') {
          // An older header in the section answer must not win; its events prove minute 86.
          return FootballDetail(match: listMatch, events: const [
            {'elapsed': 86, 'type': 'SUBSTITUTION', 'player': 'S2', 'team': 'Minas'},
            {'elapsed': 81, 'type': 'YELLOW_CARD', 'player': 'Y1', 'team': 'Unión Comercio'},
            {'elapsed': 84, 'type': 'SUBSTITUTION', 'player': 'S1a', 'team': 'Minas'},
            {'elapsed': 84, 'type': 'SUBSTITUTION', 'player': 'S1b', 'team': 'Minas'},
            {'elapsed': 86, 'type': 'SUBSTITUTION', 'player': 'S3', 'team': 'Unión Comercio'},
          ], lineups: const [], statistics: const [], partial: false, stale: false);
        }
        return null;
      };
    await _pumpDetail(tester, service, listMatch);
    expect(_stateLine(tester), 'EN VIVO · 80′');
    expect(find.textContaining('2′'), findsNothing);
    await _tapTab(tester, 'Eventos', 10);
    expect(service.calls, ['detail:BASE', 'detail:EVENTS']);
    // Five rows (two real subs at 84' and two at 86' are kept), in minute order.
    expect(find.byType(FootballEventIcon), findsNWidgets(5));
    final minutes = [for (var i = 0; i < 5; i++)
      tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('event_$i')), matching: find.textContaining('′'))).data];
    expect(minutes, ['81′', '84′', '84′', '86′', '86′']);
    // Header (80') is behind provider events (86'): minute withheld, no contradiction.
    expect(_stateLine(tester), 'En juego · datos en actualización');
    expect(find.text('EN VIVO · 80′'), findsNothing);
    expect(find.byKey(const ValueKey('match_unconfirmed_note')), findsOneWidget);
  });

  testWidgets('P0: events answer with a reconciled newer header updates the minute', (tester) async {
    final t0 = DateTime.utc(2026, 10, 6, 21, 2);
    final service = _Football()
      ..onDetail = (match, section) => FootballDetail(
          match: _m(9, status: 'SECOND_HALF', elapsed: section == 'EVENTS' ? 86 : 80, hs: 1, as: 0,
              snapshot: t0.add(Duration(minutes: section == 'EVENTS' ? 95 : 88)), dataState: 'LIVE_SNAPSHOT'),
          events: section == 'EVENTS' ? const [{'elapsed': 86, 'type': 'GOAL', 'player': 'G', 'team': 'Local'}] : const [],
          lineups: const [], statistics: const [], partial: false, stale: false);
    await _pumpDetail(tester, service, _m(9, status: 'FIRST_HALF', elapsed: 2, snapshot: t0));
    expect(_stateLine(tester), 'EN VIVO · 80′');
    await _tapTab(tester, 'Eventos', 10);
    expect(_stateLine(tester), 'EN VIVO · 86′');
    expect(find.text('EN VIVO · 80′'), findsNothing);
    expect(find.byKey(const ValueKey('match_unconfirmed_note')), findsNothing);
  });

  testWidgets('P0: backend UNCONFIRMED shows a degraded state and no minute', (tester) async {
    final service = _Football()
      ..onDetail = (match, section) => FootballDetail(
          match: _m(9, status: 'LIVE', hs: 0, as: 0, dataState: 'UNCONFIRMED',
              snapshot: DateTime.utc(2026, 10, 6, 21, 2)),
          events: const [], lineups: const [], statistics: const [], partial: false, stale: false);
    await _pumpDetail(tester, service, _m(9, status: 'FIRST_HALF', elapsed: 2));
    expect(_stateLine(tester), 'En juego · datos en actualización');
    expect(find.byKey(const ValueKey('match_unconfirmed_note')), findsOneWidget);
    expect(find.textContaining('2′'), findsNothing);
  });

  testWidgets('detail V4: scrollable compact tabs, no overflow, empty data tab hides after leaving it, CTA to chat', (tester) async {
    final visited = <String>[];
    final service = _Football()
      ..onDetail = (match, section) => FootballDetail(match: match,
          events: section == 'EVENTS' ? const [{'elapsed': 12, 'type': 'GOAL', 'player': 'G', 'team': 'Local'}] : const [],
          lineups: const [], statistics: const [], partial: false, stale: false);
    final live = _m(9, status: 'SECOND_HALF', elapsed: 60, hs: 1, as: 0, home: 'Equipo Con Nombre Muy Largo FC',
        away: 'Otro Equipo Con Nombre Largo');
    await _pumpDetail(tester, service, live, visited: visited);
    for (final label in ['Resumen', 'Eventos', 'Alineación', 'Stats', 'Tribuna']) {
      expect(find.widgetWithText(Tab, label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await _tapTab(tester, 'Stats');
    expect(find.text('Sin datos disponibles'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Stats'), findsOneWidget, reason: 'kept while open');
    await _tapTab(tester, 'Eventos');
    expect(find.widgetWithText(Tab, 'Stats'), findsNothing, reason: 'empty tab hidden after leaving');
    expect(find.widgetWithText(Tab, 'Eventos'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(service.calls.where((c) => c == 'detail:STATISTICS').length, 1);
    // SONIC_06A: tap compact header to expand and reveal the Hablar CTA again.
    await tester.tap(find.byKey(const ValueKey('detail_compact_bar')));
    await _settle(tester, 8);
    await tester.tap(find.byKey(const ValueKey('talk_match_cta')));
    await _settle(tester, 10);
    expect(visited, ['Equipo Con Nombre Muy Largo FC vs Otro Equipo Con Nombre Largo']);
  });

  testWidgets('detail V4 prematch and postponed tabs show only what can have data', (tester) async {
    await _pumpDetail(tester, _Football(), _m(9));
    expect(find.widgetWithText(Tab, 'Alineación'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Eventos'), findsNothing);
    expect(find.widgetWithText(Tab, 'Stats'), findsNothing);
    // SONIC_06: the match room opens before kickoff too ("Abre la previa con la hinchada").
    expect(find.byKey(const ValueKey('talk_match_cta')), findsOneWidget);
    await _pumpDetail(tester, _Football(), _m(10, status: 'POSTPONED'));
    expect(find.widgetWithText(Tab, 'Alineación'), findsNothing);
    expect(find.widgetWithText(Tab, 'Tribuna'), findsOneWidget);
  });

  testWidgets('event timeline: semantic icons, VAR and second yellow labels', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: FootballEventTimeline(match: _m(1, home: 'Local', away: 'Visita'), events: const [
        {'elapsed': 90, 'extra': 3, 'type': 'RED_CARD', 'player': 'Roja', 'team': 'Visita', 'detail': 'Red Card'},
        {'elapsed': 70, 'type': 'YELLOW_CARD', 'player': 'Doble', 'team': 'Local', 'detail': 'Second Yellow card'},
        {'elapsed': 55, 'type': 'OTHER', 'team': 'Local', 'detail': 'Goal cancelled'},
        {'elapsed': 30, 'type': 'SUBSTITUTION', 'player': 'Entra', 'assist': 'Sale', 'team': 'Visita'},
        {'elapsed': 10, 'type': 'GOAL', 'player': 'Goleador', 'assist': 'Asistente', 'team': 'Local', 'detail': 'Normal Goal'},
      ]),
    ))));
    expect(find.byType(FootballEventIcon), findsNWidgets(5));
    expect(find.text('Gol · Asist. Asistente · Local'), findsOneWidget);
    expect(find.text('Cambio · ⇄ Sale · Visita'), findsOneWidget);
    expect(find.text('Gol anulado por VAR'), findsOneWidget);
    expect(find.text('Tarjeta roja · Local'), findsOneWidget);
    expect(find.text('90+3′'), findsOneWidget);
    final first = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('event_0')),
        matching: find.textContaining('′')));
    expect(first.data, '10′');
  });

  testWidgets('Chat Futbolero shows the match topic from "Hablar del partido"', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      footballChatServiceProvider.overrideWithValue(_Chat()),
      connectivityStatusProvider.overrideWith(_Net.new),
    ], child: const MaterialApp(home: ChatFutboleroPage(topic: 'Local vs Visita'))));
    await _settle(tester);
    expect(find.byKey(const ValueKey('chat_topic_banner')), findsOneWidget);
    expect(find.text('Hablando de: Local vs Visita'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Centro Garra has a clear Chat Futbolero entry', (tester) async {
    final service = _Football();
    await _pumpHub(tester, service);
    expect(find.byKey(const ValueKey('chat_futbolero_entry')), findsOneWidget);
    expect(find.text('Chat Futbolero'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat_futbolero_entry')));
    await _settle(tester, 10);
    expect(find.text('CHAT '), findsOneWidget);
  });
}
