import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/data/wall_status_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/data/garra_football_service.dart';
import 'package:garra_digital_app/features/football/presentation/centro_garra_page.dart';
import 'package:garra_digital_app/features/football/presentation/football_event_timeline.dart';
import 'package:garra_digital_app/features/football/presentation/football_lineup_view.dart';
import 'package:garra_digital_app/features/football/presentation/football_match_card.dart';
import 'package:garra_digital_app/features/football/presentation/football_team_center.dart';
import 'package:go_router/go_router.dart';

/// SONIC_05 — Centro Garra integrity + Team Center. Backend contract only, synthetic data, no provider.

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

const _comps = [
  FootballCompetition(id: 'LIGA_1', name: 'Liga 1 Perú', available: true, region: 'PERU', group: 'peru'),
  FootballCompetition(id: 'LIGA_2', name: 'Liga 2 Perú', available: true, region: 'PERU', group: 'peru'),
];

class _Football extends GarraFootballService {
  _Football({this.list = const [], this.featuredValue, this.table = const [], this.partial = false,
    this.teamResult}) : super(dio: Dio());
  List<FootballMatch> list;
  FootballFeatured? featuredValue;
  List<Map<String, dynamic>> table;
  bool partial;
  FootballTeamCenterResult? teamResult;
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
  Future<FootballTeamCenterResult> team(int teamId) async {
    calls.add('team:$teamId');
    return teamResult ?? const FootballTeamCenterResult(unavailable: true, reason: 'CACHE');
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

FootballMatch _m(int id, {String comp = 'LIGA_1', String status = 'SCHEDULED', bool featured = false,
    String home = 'Local', String away = 'Visita', int? homeId, int? awayId, int? hs, int? as,
    DateTime? kickoff, int round = 11, String? venue, bool? confirmed}) => FootballMatch(
  id: id, competitionId: comp, competition: comp == 'LIGA_1' ? 'Liga 1 Perú' : 'Liga 2 Perú',
  home: home, away: away, status: status, kickoff: kickoff ?? DateTime(2030, 10, 18, 15, 30),
  featured: featured, homeScore: hs, awayScore: as, round: 'Regular Season - $round',
  homeId: homeId, awayId: awayId, venue: venue, kickoffConfirmed: confirmed);

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Route transitions (~800 ms) and sheet animations need real pumped time, never pumpAndSettle.
Future<void> _transition(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.pump();
  await tester.tap(tab);
  await _settle(tester, 14);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
}

class _Nav extends CentroGarraNavController {
  _Nav(this.initial);
  final CentroGarraNav initial;
  @override
  CentroGarraNav build() => initial;
}

Future<GoRouter> _pumpHub(WidgetTester tester, _Football service, {Size size = const Size(390, 1400),
    CentroGarraNav? nav}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(initialLocation: '/centro-garra', routes: [
    GoRoute(path: '/centro-garra', builder: (_, _) => const CentroGarraPage(), routes: [
      GoRoute(path: 'chat-futbolero', builder: (_, _) => const Scaffold(body: Text('CHAT'))),
      GoRoute(path: 'partido/:id', builder: (_, state) =>
          CentroGarraMatchDetailPage(match: state.extra as FootballMatch)),
    ]),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    garraFootballServiceProvider.overrideWithValue(service),
    connectivityStatusProvider.overrideWith(_Net.new),
    communityServiceProvider.overrideWithValue(_Community()),
    if (nav != null) centroGarraNavProvider.overrideWith(() => _Nav(nav)),
  ], child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
  return router;
}

Future<void> _pumpDetail(WidgetTester tester, _Football service, FootballMatch match,
    {Size size = const Size(390, 1200)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(initialLocation: '/d', routes: [
    GoRoute(path: '/d', builder: (_, _) => CentroGarraMatchDetailPage(match: match)),
    GoRoute(path: '/centro-garra/partido/:id', builder: (_, state) =>
        Scaffold(body: Text('DETAIL ${state.pathParameters['id']}'))),
    GoRoute(path: '/centro-garra/chat-futbolero', builder: (_, _) => const Scaffold(body: Text('CHAT'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    garraFootballServiceProvider.overrideWithValue(service),
    connectivityStatusProvider.overrideWith(_Net.new),
    communityServiceProvider.overrideWithValue(_Community()),
  ], child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
}

FootballTeamCenterResult _center({int teamId = 911, String name = 'Club Generico'}) => FootballTeamCenterResult(
  center: FootballTeamCenter(
    teamId: teamId, name: name, crestUrl: 'https://media.example/teams/$teamId.png', competition: 'Liga 1 Perú',
    next: _m(111, home: name, homeId: teamId, away: 'Rival Once', round: 11, kickoff: DateTime(2030, 10, 18, 15, 30)),
    last: _m(101, home: 'Rival Diez', away: name, awayId: teamId, status: 'FINISHED', hs: 0, as: 2, round: 10,
        kickoff: DateTime(2020, 10, 11, 15)),
    matches: [
      _m(112, home: name, homeId: teamId, away: 'Rival Doce', round: 12, kickoff: DateTime(2030, 10, 25, 15)),
      _m(101, home: 'Rival Diez', away: name, awayId: teamId, status: 'FINISHED', hs: 0, as: 2, round: 10,
          kickoff: DateTime(2020, 10, 11, 15)),
      _m(111, home: name, homeId: teamId, away: 'Rival Once', round: 11, kickoff: DateTime(2030, 10, 18, 15, 30)),
    ],
  ),
);

void main() {
  group('contract and pure helpers', () {
    test('match carries venue / kickoffConfirmed; full Lima date line, honest TBD / postponed', () {
      final m = FootballMatch.fromJson({'id': 1, 'competitionId': 'LIGA_1', 'status': 'SCHEDULED',
        'kickoff': '2026-10-18T20:30:00Z', 'venue': 'Estadio Monumental', 'kickoffConfirmed': true,
        'home': {'name': 'A'}, 'away': {'name': 'B'}});
      expect(m.venue, 'Estadio Monumental');
      expect(m.kickoffConfirmed, isTrue);
      expect(footballKickoffLine(m), 'Domingo 18 de octubre · 15:30 (hora de Lima)');
      final tbd = FootballMatch.fromJson({'id': 2, 'status': 'SCHEDULED', 'kickoff': '2026-10-18T20:30:00Z',
        'kickoffConfirmed': false});
      expect(footballKickoffLine(tbd), 'Domingo 18 de octubre · hora por confirmar');
      final pst = FootballMatch.fromJson({'id': 3, 'status': 'POSTPONED', 'kickoff': '2026-10-18T20:30:00Z'});
      expect(footballKickoffLine(pst), contains('postergado'));
      expect(pst.isPending, isTrue);
      expect(FootballMatch.fromJson({'id': 4, 'status': 'SCHEDULED'}).isKickoffTentative, isTrue);
    });

    test('every provider statistic label is Spanish (Free Kicks → Tiros libres)', () {
      expect(footballStatLabel('Free Kicks'), 'Tiros libres');
      expect(footballStatLabel('free_kicks'), 'Tiros libres');
      expect(footballStatLabel('Goal Kicks'), 'Saques de arco');
      expect(footballStatLabel('Throw-ins'), 'Saques de banda');
      expect(footballStatLabel('Throw In'), 'Saques de banda');
      const provider = ['Shots on Goal', 'Shots off Goal', 'Total Shots', 'Blocked Shots', 'Shots insidebox',
        'Shots outsidebox', 'Fouls', 'Corner Kicks', 'Offsides', 'Ball Possession', 'Yellow Cards', 'Red Cards',
        'Goalkeeper Saves', 'Total passes', 'Passes accurate', 'Passes %', 'expected_goals', 'goals_prevented',
        'Free Kicks', 'Goal Kicks', 'Throw-ins', 'Substitutions', 'Attacks', 'Dangerous Attacks', 'Penalties',
        'Hit Woodwork', 'Counter Attacks', 'Crosses', 'Tackles', 'Interceptions'];
      for (final label in provider) {
        expect(footballStatLabel(label), isNot(label), reason: '$label must be translated');
      }
    });

    test('rounds ordered by start, active round = next relevant (Fecha 11 before 12, not array order)', () {
      final items = [
        _m(121, round: 12, kickoff: DateTime(2030, 10, 25, 15)),
        _m(122, round: 12, kickoff: DateTime(2030, 10, 26, 15)),
        _m(111, round: 11, kickoff: DateTime(2030, 10, 18, 15)),
        _m(112, round: 11, status: 'FINISHED', hs: 1, as: 0, kickoff: DateTime(2030, 10, 17, 20)),
        _m(101, round: 10, status: 'FINISHED', hs: 1, as: 1, kickoff: DateTime(2030, 10, 11, 15)),
      ];
      final rounds = footballRounds(items);
      expect(rounds.map((r) => r.label), ['Fecha 10', 'Fecha 11', 'Fecha 12']);
      final now = DateTime(2030, 10, 18, 9);
      expect(footballActiveRound(rounds, limaNow: now), 'Regular Season - 11');
      // Fecha 11 postponed fixture (date in the past) is still the team's next round.
      expect(footballActiveRound(rounds, limaNow: DateTime(2030, 10, 20), featuredNextId: 111),
          'Regular Season - 11');
      expect(footballActiveRound(rounds, limaNow: DateTime(2030, 10, 20)), 'Regular Season - 12');
      expect(footballActiveRound(rounds, limaNow: DateTime(2031)), 'Regular Season - 11',
          reason: 'nothing upcoming: first round with something pending');
      expect(footballRoundNumber('Apertura - 11'), 11);
    });

    test('lineup and team center parse (numbers, positions, names-only fallback)', () {
      final lineup = FootballLineup.fromJson({'team': 'Club', 'teamId': 5, 'crestUrl': 'ftp://bad',
        'formation': '4-3-3', 'coach': 'DT Uno', 'starting': ['A'],
        'startXI': [{'name': 'Arquero', 'number': 1, 'position': 'G'}],
        'bench': [{'name': 'Suplente', 'number': 21, 'position': 'M'}]});
      expect(lineup.crestUrl, isNull);
      expect(lineup.starting.single.number, 1);
      expect(lineup.starting.single.positionLabel, 'ARQ');
      expect(lineup.bench.single.name, 'Suplente');
      final legacy = FootballLineup.fromJson({'team': 'Viejo', 'starting': ['Uno', 'Dos'], 'substitutes': ['Tres']});
      expect(legacy.starting.map((p) => p.name), ['Uno', 'Dos']);
      expect(legacy.bench.single.number, isNull);
      final center = FootballTeamCenter.fromJson({'teamId': 9, 'name': 'Nueve', 'competition': 'Liga 1 Perú',
        'matches': [{'id': 1, 'status': 'SCHEDULED', 'home': {'name': 'Nueve', 'id': 9}, 'away': {'name': 'X'}}],
        'partial': true});
      expect(center.matches.single.homeId, 9);
      expect(center.partial, isTrue);
    });
  });

  testWidgets('standings crest: https → image, absent / invalid → initials; tap opens Team Center', (tester) async {
    final service = _Football(
      featuredValue: const FootballFeatured(teamId: 2540, teamName: 'Destacado', competitionIds: ['LIGA_1']),
      teamResult: _center(teamId: 7, name: 'Con Escudo'),
      table: [
        {'group': 'Apertura', 'rank': 1, 'team': 'Con Escudo', 'teamId': 7, 'played': 9, 'points': 20,
          'goalDifference': 5, 'crestUrl': 'https://media.example/teams/7.png'},
        {'group': 'Apertura', 'rank': 2, 'team': 'Sin Escudo', 'teamId': 8, 'played': 9, 'points': 18,
          'goalDifference': 3},
        {'group': 'Apertura', 'rank': 3, 'team': 'Url Rota', 'teamId': 9, 'played': 9, 'points': 15,
          'goalDifference': 1, 'crestUrl': 'not-a-url'},
      ]);
    await _pumpHub(tester, service);
    await _tapKey(tester, 'section_standings');
    await _settle(tester, 10);
    expect(find.descendant(of: find.byKey(const ValueKey('standing_crest_7')), matching: find.byType(Image)),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('standing_crest_8')), matching: find.text('SE')),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('standing_crest_9')), matching: find.byType(Image)),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('standing_team_7')));
    await _transition(tester);
    expect(service.calls, contains('team:7'));
    expect(find.byKey(const ValueKey('team_center')), findsOneWidget);
    expect(find.byKey(const ValueKey('team_center_name')), findsOneWidget);
    expect(find.byKey(const ValueKey('team_center_next')), findsOneWidget);
    expect(find.byKey(const ValueKey('team_center_last')), findsOneWidget);
  });

  testWidgets('Team Center: Todos / Próximos / Resultados chronological, match opens detail', (tester) async {
    final service = _Football(teamResult: _center(),
        list: [_m(111, home: 'Club Generico', homeId: 911, away: 'Rival Once', awayId: 77)]);
    await _pumpHub(tester, service);
    await _tapKey(tester, 'hub_peru');
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('team_tap_111_home')));
    await _transition(tester);
    expect(service.calls.last, 'team:911');
    expect(find.text('Liga 1 Perú'), findsWidgets);
    double y(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
    // SONIC_06: the calendar lives under PARTIDOS; "Todos" = PRÓXIMOS (ascending) then RESULTADOS (newest first).
    await tester.tap(find.byKey(const ValueKey('team_center_tab_partidos')));
    await _settle(tester);
    expect(y('team_center_match_111'), lessThan(y('team_center_match_112')));
    expect(y('team_center_match_112'), lessThan(y('team_center_match_101')));
    await tester.tap(find.byKey(const ValueKey('team_center_filter_upcoming')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('team_center_match_101')), findsNothing);
    expect(find.byKey(const ValueKey('team_center_match_112')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('team_center_filter_results')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('team_center_match_101')), findsOneWidget);
    expect(find.byKey(const ValueKey('team_center_match_112')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('team_center_match_101')));
    await _transition(tester);
    expect(find.byType(CentroGarraMatchDetailPage), findsOneWidget);
    expect(find.byKey(const ValueKey('team_center')), findsNothing);
  });

  testWidgets('card body opens the match, not the club', (tester) async {
    final service = _Football(list: [_m(1, home: 'Club Nuevo', homeId: 55, away: 'Otro', awayId: 56)]);
    await _pumpHub(tester, service);
    await _tapKey(tester, 'hub_peru');
    await _settle(tester);
    await tester.tap(find.text('Fecha 11').first);
    await _transition(tester);
    expect(find.byType(CentroGarraMatchDetailPage), findsOneWidget);
    expect(service.calls.where((c) => c.startsWith('team:')), isEmpty);
  });

  testWidgets('Team Center unavailable state', (tester) async {
    final service = _Football(list: [_m(1, home: 'Club Nuevo', homeId: 55, away: 'Otro', awayId: 56)]);
    await _pumpHub(tester, service);
    await _tapKey(tester, 'hub_peru');
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('team_tap_1_away')));
    await _transition(tester);
    expect(find.byKey(const ValueKey('team_center_unavailable')), findsOneWidget);
    expect(find.text('Calendario aún no disponible'), findsOneWidget);
    expect(find.byKey(const ValueKey('team_center_next')), findsNothing);
  });

  testWidgets('PRÓXIMOS by competition: round selector, Fecha 11 active before 12, full round, in place',
      (tester) async {
    final service = _Football(list: [
      _m(121, round: 12, home: 'Doce A', away: 'Doce B', kickoff: DateTime(2030, 10, 25, 15)),
      _m(122, round: 12, home: 'Doce C', away: 'Doce D', kickoff: DateTime(2030, 10, 26, 15)),
      _m(113, round: 11, home: 'Once E', away: 'Once F', kickoff: DateTime(2030, 10, 18, 20)),
      _m(111, round: 11, home: 'Once A', away: 'Once B', kickoff: DateTime(2030, 10, 18, 15)),
      _m(112, round: 11, home: 'Destacado', away: 'Once D', featured: true, kickoff: DateTime(2030, 10, 19, 18)),
      _m(114, round: 11, home: 'Once G', away: 'Once H', kickoff: DateTime(2030, 10, 19, 20)),
    ]);
    await _pumpHub(tester, service);
    await _tapKey(tester, 'hub_peru');
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('competition_filter')));
    await _settle(tester, 10);
    await tester.tap(find.byKey(const ValueKey('competition_option_LIGA_1')));
    await _settle(tester, 10);
    await _tapKey(tester, 'section_upcoming');
    await _settle(tester, 10);
    expect(service.calls.last, 'matches:UPCOMING:LIGA_1');
    expect(find.byKey(const ValueKey('rounds_competition')), findsOneWidget);
    expect(find.byKey(const ValueKey('round_Regular Season - 11')), findsOneWidget);
    expect(find.text('Fecha 11 · 4 partidos'), findsOneWidget);
    for (final name in ['Once A', 'Once E', 'Destacado', 'Once G']) {
      expect(find.text(name), findsOneWidget, reason: 'all fixtures of the round');
    }
    expect(find.text('Doce A'), findsNothing);
    // Featured team first (presentation order only).
    expect(tester.getTopLeft(find.text('Destacado')).dy, lessThan(tester.getTopLeft(find.text('Once A')).dy));
    await tester.tap(find.byKey(const ValueKey('round_Regular Season - 12')));
    await _settle(tester);
    expect(find.text('Doce A'), findsOneWidget);
    expect(find.text('Once A'), findsNothing);
    expect(service.calls.last, 'matches:UPCOMING:LIGA_1', reason: 'round change is in place, no reload');
  });

  testWidgets('PARA TI hero: full date, stadium, CTA, side; no truncated secondary line', (tester) async {
    const longRival = 'Club Deportivo Universidad Técnica de Cajamarca de la Sierra Norte';
    final next = _m(11, featured: true, home: 'Destacado FC', homeId: 2540, away: 'Rival Once', awayId: 77,
        round: 11, venue: 'Estadio Monumental', kickoff: DateTime(2030, 10, 20, 15, 30), confirmed: true);
    final last = _m(10, featured: true, status: 'FINISHED', home: longRival, homeId: 88, away: 'Destacado FC',
        awayId: 2540, hs: 4, as: 0, round: 10, kickoff: DateTime(2030, 10, 13, 15));
    final service = _Football(featuredValue: FootballFeatured(teamId: 2540, teamName: 'Destacado FC',
        competitionIds: const ['LIGA_1'], next: next, last: last), list: [next]);
    await _pumpHub(tester, service, size: const Size(360, 1400));
    expect(find.text('PRÓXIMO PARTIDO DE DESTACADO FC'), findsOneWidget);
    expect(find.text('Liga 1 Perú · Fecha 11'), findsOneWidget);
    expect(find.text('Domingo 20 de octubre · 15:30 (hora de Lima)'), findsOneWidget);
    expect(find.text('Estadio Monumental'), findsOneWidget);
    expect(find.text('Juega de local'), findsOneWidget);
    final secondary = tester.widget<Text>(find.byKey(const ValueKey('featured_secondary_text_Último')));
    expect(secondary.maxLines, isNull);
    expect(secondary.overflow, isNull);
    expect(secondary.data, contains(longRival));
    expect(secondary.data, contains('4 - 0'));
    await tester.tap(find.byKey(const ValueKey('featured_hero_cta')));
    await _transition(tester);
    expect(find.byType(CentroGarraMatchDetailPage), findsOneWidget);
  });

  testWidgets('detail V5: Resumen rows, lineup cards, Spanish stats, VAR distinct', (tester) async {
    final match = _m(41, status: 'FINISHED', home: 'Local', homeId: 1, away: 'Visita', awayId: 2, hs: 1, as: 0,
        venue: 'Estadio Nacional', kickoff: DateTime(2026, 10, 4, 20));
    final service = _Football(teamResult: _center(teamId: 1, name: 'Local'))
      ..onDetail = (m, section) => FootballDetail(match: match, partial: false, stale: false,
        events: section == 'EVENTS' ? const [
          {'elapsed': 30, 'type': 'GOAL', 'detail': 'Normal Goal', 'player': 'Goleador', 'team': 'Local'},
          {'elapsed': 50, 'type': 'OTHER', 'detail': 'Goal cancelled', 'player': 'Anulado', 'team': 'Visita'},
          {'elapsed': 60, 'type': 'SUBSTITUTION', 'detail': 'Substitution 1', 'player': 'Sale', 'assist': 'Entra',
            'team': 'Local'},
        ] : const [],
        lineups: section == 'LINEUPS' ? const [
          {'team': 'Local', 'teamId': 1, 'formation': '4-3-3', 'coach': 'DT Local', 'starting': ['Arquero'],
            'startXI': [{'name': 'Arquero', 'number': 1, 'position': 'G'}],
            'bench': [{'name': 'Suplente', 'number': 21, 'position': 'M'}]},
        ] : const [],
        statistics: section == 'STATISTICS' ? const [
          {'team': 'Local', 'type': 'Free Kicks', 'value': '12'},
          {'team': 'Visita', 'type': 'Free Kicks', 'value': '9'},
          {'team': 'Local', 'type': 'Throw-ins', 'value': '20'},
        ] : const []);
    await _pumpDetail(tester, service, match);
    expect(find.byKey(const ValueKey('resumen_venue')), findsOneWidget);
    expect(find.text('Estadio Nacional'), findsOneWidget);
    expect(find.text('Liga 1 Perú · Fecha 11'), findsWidgets);
    expect(find.byKey(const ValueKey('resumen_kickoff')), findsOneWidget);
    await _tapTab(tester, 'Alineación');
    expect(find.byType(FootballLineupCard), findsOneWidget);
    expect(find.text('TITULARES'), findsOneWidget);
    expect(find.text('SUPLENTES'), findsOneWidget);
    expect(find.text('DT · DT Local'), findsOneWidget);
    expect(find.text('4-3-3'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    await _tapTab(tester, 'Stats');
    expect(find.text('Tiros libres'), findsOneWidget);
    expect(find.text('Saques de banda'), findsOneWidget);
    expect(find.text('Free Kicks'), findsNothing);
    await _tapTab(tester, 'Eventos');
    expect(find.byType(FootballEventTimeline), findsOneWidget);
    expect(find.byKey(const ValueKey('event_icon_goal')), findsOneWidget);
    expect(find.byKey(const ValueKey('event_icon_videoReview')), findsOneWidget);
    expect(find.byKey(const ValueKey('event_icon_substitution')), findsOneWidget);
    await _tapTab(tester, 'Resumen');
    await tester.tap(find.byKey(const ValueKey('detail_team_home')));
    await _transition(tester);
    expect(service.calls, contains('team:1'));
    expect(find.byType(FootballTeamCenterSheet), findsOneWidget);
  });

  testWidgets('navigation: Hoy fully visible on entry at narrow width', (tester) async {
    await _pumpHub(tester, _Football(list: [_m(1)]), size: const Size(320, 900));
    final today = tester.getRect(find.byKey(const ValueKey('section_today')));
    expect(today.left, greaterThanOrEqualTo(0));
    expect(today.right, lessThanOrEqualTo(320));
  });

  testWidgets('navigation: active tab (Tabla) is scrolled into view when coming back', (tester) async {
    await _pumpHub(tester, _Football(list: [_m(1)]), size: const Size(320, 900),
        nav: const CentroGarraNav(hub: CentroHub.peru, section: CentroSection.standings));
    await _settle(tester, 6);
    final standings = tester.getRect(find.byKey(const ValueKey('section_standings')));
    expect(standings.left, greaterThanOrEqualTo(0));
    expect(standings.right, lessThanOrEqualTo(320.5));
  });

  testWidgets('partial availability is one compact banner line', (tester) async {
    final service = _Football(partial: true, list: [_m(1, home: 'Primera A')]);
    await _pumpHub(tester, service);
    final banner = find.byKey(const ValueKey('partial_notice'));
    expect(banner, findsOneWidget);
    expect(tester.getSize(banner).height, lessThan(32));
    expect(find.text('Primera A'), findsOneWidget);
  });

  testWidgets('match card: team tap is separate from card tap', (tester) async {
    int? tappedTeam;
    var opened = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [
      FootballMatchCard(match: _m(5, home: 'Local Largo', homeId: 10, away: 'Visita', awayId: 20),
          onTap: () => opened++, onTeamTap: (id, name, crest) => tappedTeam = id),
    ]))));
    await tester.tap(find.byKey(const ValueKey('team_tap_5_away')));
    await tester.pump();
    expect(tappedTeam, 20);
    expect(opened, 0);
    await tester.tap(find.text('Liga 1 Perú · Fecha 11'));
    await tester.pump();
    expect(opened, 1);
  });
}
