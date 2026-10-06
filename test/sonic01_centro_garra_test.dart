import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/data/wall_status_model.dart';
import 'package:garra_digital_app/features/community/presentation/muro_crema_page.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/data/garra_football_service.dart';
import 'package:garra_digital_app/features/football/presentation/centro_garra_page.dart';
import 'package:go_router/go_router.dart';

const _garraId = '11111111-1111-1111-1111-111111111111';

class _Network extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

/// Backend contract only: no test talks to the football data provider.
class _Football extends GarraFootballService {
  _Football({this.events = const [], this.stats = const []}) : super(dio: Dio());
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> stats;

  @override
  Future<FootballDetail?> detail(FootballMatch match, {String? section}) async =>
      FootballDetail(match: match,
          events: section == 'EVENTS' ? events : const [],
          lineups: const [],
          statistics: section == 'STATISTICS' ? stats : const [],
          partial: false, stale: false);
}

WallPostModel _post(int i, {String status = 'ACTIVE'}) => WallPostModel(
  id: 'post-$i', matchId: _garraId, username: 'crema$i', fullName: 'Hincha $i',
  content: 'Arenga $i', imageUrl: null, locationTag: 'STADIUM', status: status,
  reportCount: 0, createdAt: '2026-10-06T15:00:00Z', reactionCount: 2, commentCount: 1,
);

class _Community extends CommunityService {
  _Community({this.posts = const [], this.status, this.fail = false}) : super(dio: Dio());
  List<WallPostModel> posts;
  WallStatusModel? status;
  bool fail;
  final List<String> calls = [];

  @override
  Future<WallStatusModel?> getCurrentWallStatus() async => status;

  @override
  Future<List<WallPostModel>> getPosts({required String matchId, String? locationTag}) async {
    calls.add(matchId);
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/wall'));
    return posts;
  }

  @override
  Future<List<WallPostModel>> getMyPosts() async => const [];
}

WallStatusModel _wall(String matchId, String wallStatus) => WallStatusModel(
  matchId: matchId, matchName: 'Universitario vs Rival', matchDateTime: null,
  wallStatus: wallStatus, opensAt: null, closesAt: null, secondsToOpen: 0,
  secondsToClose: 3600,
);

FootballMatch _match(String status, {int? home, int? away, int? elapsed, String? garraId = _garraId}) =>
    FootballMatch(id: 77, competitionId: 'LIGA_1', competition: 'Liga 1 Perú',
      home: 'Universitario', away: 'Rival', status: status,
      kickoff: DateTime(2026, 10, 10, 20), homeScore: home, awayScore: away,
      elapsed: elapsed, garraMatchId: garraId, round: 'Regular Season - 12');

Future<GoRouter> _pumpDetail(WidgetTester tester, FootballMatch match,
    _Community community, {_Football? football, List<String>? visited}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(initialLocation: '/partido', routes: [
    GoRoute(path: '/partido', builder: (_, _) => CentroGarraMatchDetailPage(match: match)),
    GoRoute(path: '/muro-crema', builder: (_, state) {
      visited?.add('muro:${state.uri.queryParameters['matchId']}');
      return const Scaffold(body: Text('MURO'));
    }),
    GoRoute(path: '/muro-crema/compose', builder: (context, state) {
      visited?.add('compose:${state.uri.queryParameters['matchId']}');
      return Scaffold(body: TextButton(onPressed: () => context.pop(true),
          child: const Text('PUBLICAR')));
    }),
    GoRoute(path: '/muro-crema/posts/:id', builder: (_, state) {
      visited?.add('post:${state.pathParameters['id']}');
      return const Scaffold(body: Text('POST'));
    }),
    GoRoute(path: '/matchday/:id/polls', builder: (_, _) => const Scaffold(body: Text('ENCUESTAS'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    garraFootballServiceProvider.overrideWithValue(football ?? _Football()),
    connectivityStatusProvider.overrideWith(_Network.new),
    communityServiceProvider.overrideWithValue(community),
  ], child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
  return router;
}

/// SONIC_04: no pumpAndSettle (skeleton/progress animate); Tribuna is a detail tab.
/// Route transitions (fade-forwards) last ~800 ms, so settle a bit longer than that.
Future<void> _settle(WidgetTester tester, [int frames = 18]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Riverpod 3 auto-retries failed providers (exponential backoff) and only surfaces the
/// error once retries are exhausted; step fake time (up to 60 s) until [finder] shows.
Future<void> _until(WidgetTester tester, Finder finder, {int steps = 240}) async {
  for (var i = 0; i < steps && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _tribuna(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(Tab, 'Tribuna'));
  await _settle(tester);
}

String _allText(WidgetTester tester) => tester.widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '').join('\n');

void main() {
  test('Lima wall clock, round and event/stat labels never expose raw codes', () {
    expect(limaWallClock(DateTime.utc(2026, 1, 1, 3, 30)), DateTime(2025, 12, 31, 22, 30));
    expect(limaWallClock(DateTime.utc(2026, 7, 1, 1)), DateTime(2026, 6, 30, 20));
    expect(_match('SCHEDULED').roundLabel, 'Fecha 12');
    expect(FootballMatch(id: 1, competitionId: 'L', competition: 'L', home: 'a',
        away: 'b', status: 'SCHEDULED', round: 'Apertura - 3').roundLabel, 'Apertura · Fecha 3');
    expect(footballEventLabel('GOAL', detail: 'Penalty'), 'Gol de penal');
    expect(footballEventLabel('GOAL', detail: 'Own Goal'), 'Autogol');
    expect(footballEventLabel('OTHER'), 'Incidencia');
    expect(footballEventLabel(null), 'Incidencia');
    expect(footballStatLabel('Ball Possession'), 'Posesión');
    expect(footballStatLabel('expected_goals'), 'Goles esperados (xG)');
  });

  testWidgets('pre-match detail shows Lima kickoff and the open Tribuna with publish',
      (tester) async {
    final community = _Community(
      posts: [_post(1), _post(2), _post(3), _post(4)],
      status: _wall(_garraId, 'PRE_MATCH'),
    );
    final visited = <String>[];
    await _pumpDetail(tester, _match('SCHEDULED'), community, visited: visited);

    expect(find.byKey(const ValueKey('match_state_line')), findsOneWidget);
    expect(find.textContaining('20:00 (hora de Lima)'), findsOneWidget);
    expect(find.text('Liga 1 Perú · Fecha 12'), findsWidgets);
    await _tribuna(tester);
    expect(find.text('Tribuna del partido'), findsOneWidget);
    expect(find.text('Calienta la previa con la hinchada.'), findsOneWidget);
    // Preview reuses the match wall: at most three posts, newest first.
    expect(find.byKey(const ValueKey('tribuna_post_post-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tribuna_post_post-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('tribuna_post_post-4')), findsNothing);
    expect(community.calls, [_garraId]);

    await tester.tap(find.text('Publicar en la Tribuna'));
    await _settle(tester);
    expect(visited, ['compose:$_garraId']);
    await tester.tap(find.text('PUBLICAR'));
    await _settle(tester);
    // A successful compose reloads the Tribuna preview.
    expect(community.calls.length, 2);

    await tester.tap(find.byKey(const ValueKey('tribuna_post_post-2')));
    await _settle(tester);
    expect(visited.last, 'post:post-2');
  });

  testWidgets('live detail prioritises score/minute and hides publish when the wall is closed',
      (tester) async {
    final community = _Community(posts: [_post(1)], status: _wall(_garraId, 'CLOSED'));
    await _pumpDetail(tester, _match('LIVE', home: 1, away: 0, elapsed: 67), community);
    expect(find.textContaining('67′'), findsWidgets);
    expect(tester.widget<Text>(find.byKey(const ValueKey('detail_score_home'))).data, '1');
    expect(tester.widget<Text>(find.byKey(const ValueKey('detail_score_away'))).data, '0');
    expect(find.textContaining('EN VIVO'), findsWidgets);
    expect(find.byKey(const ValueKey('talk_match_cta')), findsOneWidget);
    await _tribuna(tester);
    expect(find.text('Publicar en la Tribuna'), findsNothing);
    expect(find.textContaining('Arenga 1'), findsOneWidget);
  });

  testWidgets('finished detail shows the result and the Tribuna history read-only',
      (tester) async {
    final community = _Community(posts: [_post(1), _post(2, status: 'HIDDEN')],
        status: _wall('another-match', 'LIVE'));
    final visited = <String>[];
    await _pumpDetail(tester, _match('FINISHED', home: 2, away: 1), community, visited: visited);
    expect(find.text('Final · Universitario 2 - 1 Rival'), findsOneWidget);
    await _tribuna(tester);
    expect(find.text('La conversación del partido.'), findsOneWidget);
    expect(find.text('Publicar en la Tribuna'), findsNothing);
    expect(find.byKey(const ValueKey('tribuna_post_post-2')), findsNothing);
    await tester.tap(find.text('Ver Tribuna completa'));
    await _settle(tester);
    expect(visited, ['muro:$_garraId']);
  });

  testWidgets('Tribuna error offers retry; unlinked fixture explains it', (tester) async {
    final community = _Community(fail: true);
    await _pumpDetail(tester, _match('SCHEDULED'), community);
    await _tribuna(tester);
    await _until(tester, find.text('No pudimos cargar la Tribuna'));
    expect(find.text('No pudimos cargar la Tribuna'), findsOneWidget);
    expect(_allText(tester).contains('DioException'), isFalse);
    community.fail = false;
    final before = community.calls.length;
    await tester.tap(find.text('Reintentar'));
    await _settle(tester);
    // Riverpod 3 also auto-retries failed providers; the tap must add a call.
    expect(community.calls.length, greaterThan(before));
    await _until(tester, find.text('Todavía no hay arengas en esta Tribuna.'));
    expect(find.text('Todavía no hay arengas en esta Tribuna.'), findsOneWidget);
  });

  testWidgets('unlinked fixture has no Tribuna requests', (tester) async {
    final community = _Community();
    await _pumpDetail(tester, _match('SCHEDULED', garraId: null), community);
    await _tribuna(tester);
    expect(find.text('Aún no está vinculada a este partido'), findsOneWidget);
    expect(community.calls, isEmpty);
  });

  testWidgets('events and statistics use Spanish labels and no raw codes', (tester) async {
    final football = _Football(events: const [
      {'type': 'GOAL', 'player': 'Valera', 'detail': 'Penalty', 'team': 'Universitario', 'elapsed': 10},
      {'type': 'OTHER', 'team': 'Rival', 'elapsed': 45, 'extra': 2},
    ], stats: const [
      {'team': 'Universitario', 'type': 'Ball Possession', 'value': '61%'},
      {'team': 'Rival', 'type': 'Ball Possession', 'value': '39%'},
    ]);
    await _pumpDetail(tester, _match('FINISHED', home: 1, away: 0), _Community(), football: football);
    await tester.tap(find.text('Eventos'));
    await _settle(tester);
    expect(find.text('Valera'), findsOneWidget);
    expect(find.text('Gol de penal · Universitario'), findsOneWidget);
    expect(find.text('Incidencia'), findsOneWidget);
    expect(find.text('45+2′'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Stats'));
    await _settle(tester);
    expect(find.text('Posesión'), findsOneWidget);
    expect(find.text('61%'), findsOneWidget);
    expect(find.text('39%'), findsOneWidget);
    final text = _allText(tester);
    expect(RegExp(r'\b(GOAL|OTHER|SCHEDULED|FINISHED|LIVE|UNKNOWN_PROVIDER_ERROR)\b').hasMatch(text),
        isFalse, reason: text);
  });

  testWidgets('Muro Crema opened for another match is read-only history', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final community = _Community(posts: [_post(1)], status: _wall('current-match', 'LIVE'));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const MuroCremaPage(matchId: _garraId)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [communityServiceProvider.overrideWithValue(community)],
      child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
    ));
    await _settle(tester);
    expect(find.text('Tribuna del partido'), findsOneWidget);
    expect(community.calls, contains(_garraId));
    expect(find.textContaining('Arenga 1'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Muro cerrado'), findsOneWidget);
  });
}
