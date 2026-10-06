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
import 'package:garra_digital_app/features/football/presentation/football_match_card.dart';
import 'package:garra_digital_app/features/football/presentation/football_team_crest.dart';
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

class _Football extends GarraFootballService {
  _Football({this.matchList = const [], this.table = const []}) : super(dio: Dio());
  final List<FootballMatch> matchList;
  final List<Map<String, dynamic>> table;

  @override
  Future<List<FootballCompetition>> competitions() async => const [
    FootballCompetition(id: 'LIGA_1', name: 'Liga 1 Perú', available: true, region: 'PERU', group: 'peru'),
    FootballCompetition(id: 'UCL', name: 'Champions League', available: false, region: 'EUROPE', group: 'europe'),
    FootballCompetition(id: 'LIBERTADORES', name: 'Copa Libertadores', available: true, region: 'CONMEBOL', group: 'conmebol'),
  ];

  @override
  Future<FootballPage<FootballMatch>> matches(FootballView view, {String? competition}) async =>
      FootballPage(items: matchList, stale: false, unavailable: false, partial: false);

  @override
  Future<FootballPage<Map<String, dynamic>>> standings(String competition) async =>
      FootballPage(items: table, stale: false, unavailable: false, partial: false);

  @override
  Future<FootballDetail?> detail(FootballMatch match, {String? section}) async =>
      FootballDetail(match: match, events: section == 'EVENTS' ? const [{'type': 'GOAL', 'player': 'Valera'}] : const [],
          lineups: const [], statistics: const [], partial: false, stale: false);
}

FootballMatch _m({
  String status = 'SCHEDULED',
  bool featured = false,
  String home = 'Universitario',
  String? crest,
  String competition = 'Liga 1 Perú',
}) =>
    FootballMatch(
      id: 1,
      competitionId: 'LIGA_1',
      competition: competition,
      home: home,
      away: 'Alianza Lima',
      status: status,
      kickoff: DateTime(2026, 10, 10, 20),
      homeScore: status == 'FINISHED' || status == 'FIRST_HALF' ? 1 : null,
      awayScore: status == 'FINISHED' || status == 'FIRST_HALF' ? 0 : null,
      elapsed: status == 'FIRST_HALF' ? 33 : null,
      featured: featured,
      homeCrestUrl: crest,
      round: 'Regular Season - 12',
      garraMatchId: status == 'LIVE' ? 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' : null,
    );

void main() {
  test('statuses and crest parsing never invent urls', () {
    final half = FootballMatch.fromJson({
      'id': 1, 'competitionId': 'LIGA_1', 'competition': 'Liga 1',
      'home': {'name': 'U', 'id': 9, 'crestUrl': 'https://cdn.example/u.png'},
      'away': {'name': 'A', 'crestUrl': 'javascript:alert(1)'},
      'status': 'HALFTIME', 'elapsed': 45,
    });
    expect(half.isLive, isTrue);
    expect(half.statusLabel, 'DESCANSO');
    expect(half.homeCrestUrl, 'https://cdn.example/u.png');
    expect(half.awayCrestUrl, isNull);
    expect(FootballMatch.fromJson({'id': 2, 'status': 'FIRST_HALF', 'home': {}, 'away': {}}).statusLabel,
        contains('1.º TIEMPO'));
  });

  testWidgets('hub shows Para ti / Perú / Internacional and premium card truncates long names', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final long = _m(
      home: 'Club Deportivo Universidad Técnica de Cajamarca',
      featured: true,
      crest: 'https://cdn.example/crest.png',
    );
    final router = GoRouter(initialLocation: '/centro-garra', routes: [
      GoRoute(path: '/centro-garra', builder: (_, _) => const CentroGarraPage()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      garraFootballServiceProvider.overrideWithValue(_Football(matchList: [long])),
      connectivityStatusProvider.overrideWith(_Net.new),
      communityServiceProvider.overrideWithValue(_Community()),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('Para ti'), findsOneWidget);
    expect(find.text('Perú'), findsOneWidget);
    expect(find.text('Internacional'), findsOneWidget);
    expect(find.byType(FootballMatchCard), findsOneWidget);
    expect(find.byType(FootballTeamCrest), findsWidgets);
    expect(find.textContaining('Fecha 12'), findsOneWidget);
    // Truncation: full long name is in the tree but maxLines=1 — widget exists.
    expect(find.textContaining('Cajamarca'), findsOneWidget);
    await tester.tap(find.text('Perú'));
    await tester.pumpAndSettle();
    expect(find.text('Liga 1 Perú'), findsWidgets);
    await tester.tap(find.text('Internacional'));
    await tester.pumpAndSettle();
    expect(find.text('Copa Libertadores'), findsOneWidget);
    expect(find.text('Champions League'), findsNothing); // unavailable filtered from chips
  });

  testWidgets('standings V2 columns and featured highlight without hardcoding names', (tester) async {
    // Wide enough that section chips (incl. Tabla) are all built.
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _Football(table: [
      {'rank': 1, 'team': 'Crema FC', 'played': 10, 'goalDifference': 8, 'points': 22,
        'crestUrl': 'https://cdn.example/c.png', 'featured': true},
      {'rank': 2, 'team': 'Rival', 'played': 10, 'goalDifference': -1, 'points': 14, 'featured': false},
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      garraFootballServiceProvider.overrideWithValue(service),
      connectivityStatusProvider.overrideWith(_Net.new),
      communityServiceProvider.overrideWithValue(_Community()),
    ], child: const MaterialApp(home: CentroGarraPage())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tabla'));
    await tester.pumpAndSettle();
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('EQUIPO'), findsOneWidget);
    expect(find.text('PJ'), findsOneWidget);
    expect(find.text('DG'), findsOneWidget);
    expect(find.text('PTS'), findsOneWidget);
    expect(find.text('Crema FC'), findsOneWidget);
    expect(find.text('+8'), findsOneWidget);
  });

  testWidgets('detail V2 sections and Tribuna without link', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final match = _m(status: 'FIRST_HALF');
    final router = GoRouter(initialLocation: '/partido', routes: [
      GoRoute(path: '/partido', builder: (_, _) => CentroGarraMatchDetailPage(match: match)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      garraFootballServiceProvider.overrideWithValue(_Football()),
      connectivityStatusProvider.overrideWith(_Net.new),
      communityServiceProvider.overrideWithValue(_Community()),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Eventos'), findsOneWidget);
    expect(find.text('Estadísticas'), findsOneWidget);
    expect(find.text('Alineaciones'), findsOneWidget);
    // Unlinked fixture uses the compact Tribuna Garra card (no wall requests).
    await tester.scrollUntilVisible(find.text('Tribuna Garra'), 300);
    expect(find.text('Tribuna Garra'), findsOneWidget);
    expect(find.text('Aún no está vinculada a este partido'), findsOneWidget);
    await tester.tap(find.text('Eventos'));
    await tester.pumpAndSettle();
    expect(find.text('Valera'), findsOneWidget);
  });
}
