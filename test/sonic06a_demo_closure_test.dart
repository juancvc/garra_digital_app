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
import 'package:garra_digital_app/features/football/presentation/football_standings_view.dart';
import 'package:go_router/go_router.dart';

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

FootballMatch _m(int id, {String status = 'SECOND_HALF', String home = 'Local FC', String away = 'Visita FC',
    int? hs, int? awayScore, int? elapsed, String comp = 'Liga 1 Perú'}) => FootballMatch(
  id: id, competitionId: 'LIGA_1', competition: comp, home: home, away: away, status: status,
  kickoff: DateTime(2026, 10, 6, 15), homeScore: hs, awayScore: awayScore, round: 'Regular Season - 11',
  elapsed: elapsed);

Future<void> _settle(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  group('Obj1 event semantics — one normalizer', () {
    test('goal, red, VAR disallowed, penalty VAR, ambiguous, 45+2, 90+7, duplicates, same minute', () {
      expect(footballNormalizeEvent(type: 'GOAL', detail: 'Normal Goal').label, 'Gol');
      expect(footballNormalizeEvent(type: 'RED_CARD').label, 'Tarjeta roja');
      expect(footballNormalizeEvent(type: 'VAR', detail: 'Goal cancelled').label, 'Gol anulado por VAR');
      expect(footballNormalizeEvent(type: 'VAR', detail: 'Goal disallowed').label, 'Gol anulado por VAR');
      expect(footballNormalizeEvent(type: 'VAR', detail: 'Penalty confirmed').label, 'Penal concedido por VAR');
      expect(footballNormalizeEvent(type: 'VAR', detail: 'Penalty cancelled').label, 'Penal anulado por VAR');
      expect(footballNormalizeEvent(type: 'VAR', detail: 'Penalty revoked').label, 'Penal anulado por VAR');
      expect(footballNormalizeEvent(type: 'VAR', detail: 'Card upgrade').label, 'Decisión VAR');
      expect(footballNormalizeEvent(backendKind: 'VAR_GOAL_CANCELLED').label, 'Gol anulado por VAR');
      expect(footballNormalizeEvent(backendKind: 'VAR_PENALTY_CANCELLED').label, 'Penal anulado por VAR');
      // Physical bug: bare "cancelled" must NOT become a goal cancel when it is a penalty.
      expect(footballVarDecision('Penalty cancelled'), 'PENALTY_CANCELLED');
      expect(footballVarDecision('Goal cancelled'), 'GOAL_CANCELLED');
      expect(footballMinuteLabel(45, 2), '45+2′');
      expect(footballMinuteLabel(90, 7), '90+7′');
      final events = [
        {'elapsed': 90, 'extra': 4, 'type': 'VAR', 'detail': 'Penalty cancelled', 'player': 'X', 'team': 'Local FC'},
        {'elapsed': 90, 'extra': 4, 'type': 'VAR', 'detail': 'Penalty cancelled', 'player': 'X', 'team': 'Local FC'},
        {'elapsed': 90, 'extra': 4, 'type': 'GOAL', 'detail': 'Normal Goal', 'player': 'Y', 'team': 'Visita FC'},
      ];
      final moments = footballKeyMoments(events, _m(1));
      expect(moments.length, 2);
      expect(moments.map((m) => m.label).toList(), ['Penal anulado por VAR', 'Y']);
    });

    testWidgets('Momentos, Eventos and Chat agree on the same Penalty cancelled fact', (tester) async {
      const detail = 'Penalty cancelled';
      final event = {'elapsed': 90, 'extra': 4, 'type': 'VAR', 'detail': detail, 'player': 'A. Valera',
        'team': 'Local FC'};
      final match = _m(1, hs: 1, awayScore: 0);
      final moments = footballKeyMoments([event], match);
      expect(moments.single.label, 'Penal anulado por VAR');
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FootballEventTimeline(
          match: match, events: [event]))));
      expect(find.textContaining('Penal anulado por VAR'), findsOneWidget);
      expect(find.textContaining('Gol anulado'), findsNothing);
      final chatEvent = FootballChatEvent(key: 'k', kind: 'VAR_PENALTY_CANCELLED', minute: 90, extra: 4,
          player: 'A. Valera', team: 'Local FC', side: 'HOME');
      expect(FootballChatEventCard.label(chatEvent), '📺 Penal anulado por VAR');
    });
  });

  group('Obj3 Liga 2 stage/group', () {
    test('1 stage / 1 table; 1 stage / 2 groups; multi stages; never concatenate ranks', () {
      final one = FootballStandingStage.fromRows([
        {'group': 'Primera División: Apertura', 'rank': 1, 'team': 'A'},
        {'group': 'Primera División: Apertura', 'rank': 2, 'team': 'B'},
      ]);
      expect(one.length, 1);
      expect(one.first.groups.length, 1);
      expect(one.first.rowsFor(null).map((r) => r['rank']), [1, 2]);

      final liga2 = FootballStandingStage.fromRows([
        {'group': 'Group A', 'rank': 1, 'team': 'A1', 'teamId': 1},
        {'group': 'Group A', 'rank': 2, 'team': 'A2', 'teamId': 2},
        {'group': 'Group B', 'rank': 1, 'team': 'B1', 'teamId': 3},
        {'group': 'Group B', 'rank': 2, 'team': 'B2', 'teamId': 4},
      ]);
      expect(liga2.length, 1, reason: 'bare groups share one stage');
      expect(liga2.first.groups.map((g) => g.key).toList(), ['Group A', 'Group B']);
      expect(liga2.first.rowsFor('Group A').map((r) => r['rank']), [1, 2]);
      expect(liga2.first.rowsFor('Group B').map((r) => r['team']), ['B1', 'B2']);
      // Never both rank-1 in one visible list:
      expect(liga2.first.rowsFor('Group A').where((r) => r['rank'] == 1).length, 1);

      final multi = FootballStandingStage.fromRows([
        {'group': 'Clausura - Group A', 'rank': 1, 'team': 'X'},
        {'group': 'Clausura - Group B', 'rank': 1, 'team': 'Y'},
        {'group': 'Apertura - Group A', 'rank': 1, 'team': 'Z'},
      ]);
      expect(multi.map((s) => s.name).toList(), ['Clausura', 'Apertura']);
      expect(multi.first.groups.map((g) => g.key).toList(), ['Group A', 'Group B']);
    });

    testWidgets('UI shows group chips and never mixes Group A with Group B rows', (tester) async {
      String? stage = 'Tabla';
      String? group = 'Group A';
      final rows = [
        {'group': 'Group A', 'rank': 1, 'team': 'Alpha', 'teamId': 1, 'played': 3, 'goalDifference': 2, 'points': 7,
          'crestUrl': 'https://example.com/a.png'},
        {'group': 'Group A', 'rank': 2, 'team': 'Beta', 'teamId': 2, 'played': 3, 'goalDifference': 0, 'points': 4},
        {'group': 'Group B', 'rank': 1, 'team': 'Gamma', 'teamId': 3, 'played': 3, 'goalDifference': 1, 'points': 6},
        {'group': 'Group B', 'rank': 2, 'team': 'Delta', 'teamId': 4, 'played': 3, 'goalDifference': -1, 'points': 3},
      ];
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        return FootballStandingsView(
          rows: rows,
          competitionName: 'Liga 2 Perú',
          selectedStage: stage,
          selectedGroup: group,
          featuredTeamId: 1,
          onStageChanged: (s) => setState(() { stage = s; group = null; }),
          onGroupChanged: (g) => setState(() => group = g),
        );
      }))));
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Gamma'), findsNothing);
      expect(find.byKey(const ValueKey('group_Group A')), findsOneWidget);
      expect(find.byKey(const ValueKey('standing_featured_row')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group_Group B')));
      await tester.pump();
      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Obj2 Match Detail V6 collapse + sticky tabs', () {
    testWidgets('expanded on entry; scroll collapses; tab stays; Hablar CTA; 360px', (tester) async {
      final match = _m(9, hs: 2, awayScore: 1, elapsed: 70);
      final service = _Football()
        ..onDetail = (m, section) => FootballDetail(
              match: match,
              events: section == 'EVENTS'
                  ? [
                      {'elapsed': 10, 'type': 'GOAL', 'player': 'A', 'team': 'Local FC', 'detail': 'Normal Goal'},
                      {'elapsed': 90, 'extra': 4, 'type': 'VAR', 'detail': 'Penalty cancelled', 'player': 'B',
                        'team': 'Local FC'},
                    ]
                  : const [],
              lineups: const [],
              statistics: const [],
              partial: false, stale: false,
              moments: [
                footballMomentAsEvent({'kind': 'GOAL', 'minute': 10, 'player': 'A', 'team': 'Local FC'}),
                footballMomentAsEvent({'kind': 'VAR_PENALTY_CANCELLED', 'minute': 90, 'extra': 4, 'player': 'B',
                  'team': 'Local FC'}),
              ],
              eventCount: 2,
            );
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(initialLocation: '/d', routes: [
        GoRoute(path: '/d', builder: (_, _) => CentroGarraMatchDetailPage(match: match)),
        GoRoute(path: '/centro-garra/chat-futbolero', builder: (_, _) => const Scaffold(body: Text('CHAT'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        garraFootballServiceProvider.overrideWithValue(service),
        connectivityStatusProvider.overrideWith(_Net.new),
        communityServiceProvider.overrideWithValue(_Community()),
      ], child: MaterialApp.router(routerConfig: router)));
      await _settle(tester, 12);
      expect(find.byKey(const ValueKey('detail_header_expanded')), findsOneWidget);
      expect(find.byKey(const ValueKey('talk_match_cta')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail_tab_bar')), findsOneWidget);
      expect(find.textContaining('Penal anulado por VAR'), findsOneWidget);
      expect(find.byKey(const ValueKey('detail_tab_bar')), findsOneWidget);
      // Tab tap collapses the header and keeps the tab bar pinned.
      final before = List<String>.from(service.calls);
      await tester.tap(find.widgetWithText(Tab, 'Eventos'));
      await _settle(tester, 12);
      expect(find.byKey(const ValueKey('detail_header_compact')), findsOneWidget);
      expect(find.byKey(const ValueKey('talk_match_cta')), findsNothing);
      expect(find.byKey(const ValueKey('detail_tab_bar')), findsOneWidget);
      expect(service.calls.where((c) => c == 'detail:BASE').length,
          before.where((c) => c == 'detail:BASE').length);
      expect(service.calls, contains('detail:EVENTS'));
      expect(tester.takeException(), isNull);
    });
  });

  group('Obj4 Chat UX V2', () {
    testWidgets('MATCH header compact, system strip, empty note, no yank on silent poll', (tester) async {
      final chat = _Chat()
        ..pages = (c) => FootballChatPage(
              items: const [],
              hasMore: false,
              contextType: 'MATCH',
              contextId: '9',
              match: _m(9, hs: 1, awayScore: 0, elapsed: 55),
              events: [
                FootballChatEvent(key: 'g', kind: 'VAR_PENALTY_CANCELLED', minute: 90, extra: 4,
                    player: 'A. Valera', team: 'Local FC', side: 'HOME',
                    approxAt: DateTime.utc(2026, 10, 6, 21, 0)),
              ],
            );
      await tester.binding.setSurfaceSize(const Size(360, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(overrides: [
        footballChatServiceProvider.overrideWithValue(chat),
        connectivityStatusProvider.overrideWith(_Net.new),
      ], child: MaterialApp(home: ChatFutboleroPage(matchId: 9, match: _m(9, hs: 1, awayScore: 0, elapsed: 55)))));
      await _settle(tester);
      expect(find.text('Local FC vs Visita FC'), findsOneWidget);
      expect(find.textContaining('1-0'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_back_general')), findsOneWidget);
      expect(find.text('Abre la previa con la hinchada'), findsOneWidget);
      expect(find.text('Los mensajes de esta sala son solo de este partido.'), findsOneWidget);
      expect(find.text('EVENTO DEL PARTIDO'), findsOneWidget);
      expect(find.textContaining('Penal anulado por VAR'), findsOneWidget);
      final calls = chat.calls.length;
      await tester.pump(const Duration(seconds: 12));
      expect(chat.calls.length, calls + 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    });
  });
}

class _Chat extends FootballChatService {
  _Chat() : super(dio: Dio());
  final List<String> calls = [];
  FootballChatPage Function(FootballChatContext context)? pages;
  @override
  Future<FootballChatPage> page(FootballChatContext context, {DateTime? before, int size = 30}) async {
    calls.add(context.key);
    return pages?.call(context) ?? const FootballChatPage(items: [], hasMore: false);
  }
}

class _Football extends GarraFootballService {
  _Football() : super(dio: Dio());
  final List<String> calls = [];
  FootballDetail? Function(FootballMatch match, String? section)? onDetail;
  @override
  Future<List<FootballCompetition>> competitions() async => const [
        FootballCompetition(id: 'LIGA_1', name: 'Liga 1 Perú', available: true, region: 'PERU', group: 'peru'),
      ];
  @override
  Future<FootballPage<FootballMatch>> matches(FootballView view, {String? competition}) async =>
      const FootballPage(items: [], stale: false, unavailable: false, partial: false);
  @override
  Future<FootballFeatured?> featured() async => null;
  @override
  Future<FootballDetail?> detail(FootballMatch match, {String? section}) async {
    calls.add('detail:${section ?? 'BASE'}');
    return onDetail?.call(match, section) ??
        FootballDetail(match: match, events: const [], lineups: const [], statistics: const [],
            partial: false, stale: false);
  }
}
