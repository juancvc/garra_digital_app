import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/presentation/football_match_card.dart';
import 'package:garra_digital_app/features/football/presentation/football_team_crest.dart';

void main() {
  test('standings stages never concatenate ranks across groups', () {
    final stages = FootballStandingStage.fromRows([
      {'group': 'Apertura', 'rank': 1, 'team': 'A', 'points': 10, 'played': 5, 'goalDifference': 3},
      {'group': 'Apertura', 'rank': 2, 'team': 'B', 'points': 8, 'played': 5, 'goalDifference': 1},
      {'group': 'Clausura', 'rank': 1, 'team': 'C', 'points': 12, 'played': 5, 'goalDifference': 4},
      {'group': 'Acumulada', 'rank': 1, 'team': 'A', 'featured': true, 'points': 22, 'played': 10, 'goalDifference': 7},
    ]);
    expect(stages.map((s) => s.name), ['Apertura', 'Clausura', 'Acumulada']);
    expect(stages[0].rows.map((r) => r['rank']), [1, 2]);
    expect(stages[1].rows.single['rank'], 1);
    expect(stages[2].rows.single['featured'], true);
  });

  test('live minute uses provider elapsed/extra only', () {
    final live = FootballMatch(
      id: 1, competitionId: 'LIGA_1', competition: 'Liga 1',
      home: 'Home', away: 'Away', status: 'SECOND_HALF', elapsed: 67,
    );
    expect(live.statusLabel, 'EN VIVO · 67′');
    final injury = FootballMatch(
      id: 2, competitionId: 'LIGA_1', competition: 'Liga 1',
      home: 'Home', away: 'Away', status: 'FIRST_HALF', elapsed: 45, elapsedExtra: 2,
    );
    expect(injury.statusLabel, 'EN VIVO · 45+2′');
    expect(injury.liveMinuteLabel, '45+2′');
    final ht = FootballMatch(
      id: 3, competitionId: 'LIGA_1', competition: 'Liga 1',
      home: 'Home', away: 'Away', status: 'HALFTIME', elapsed: 45,
    );
    expect(ht.statusLabel, 'DESCANSO');
  });

  testWidgets('match card keeps long names up to 2 lines without forced single ellipsis', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FootballMatchCard(
          match: FootballMatch(
            id: 9,
            competitionId: 'LIGA_1',
            competition: 'Liga 1 Perú',
            round: 'Regular Season - 12',
            home: 'Club Deportivo Universidad Técnica de Cajamarca',
            away: 'Asociación Deportiva Tarma de la Sierra',
            status: 'SCHEDULED',
            kickoff: DateTime(2026, 10, 7, 20, 0),
          ),
          onTap: () {},
        ),
      ),
    ));
    expect(find.textContaining('Universidad Técnica'), findsOneWidget);
    expect(find.textContaining('Tarma'), findsOneWidget);
    // Names allow 2 lines; card should still show competition/round first.
    expect(find.textContaining('Liga 1'), findsOneWidget);
    expect(find.textContaining('Fecha 12'), findsOneWidget);
  });

  testWidgets('crest falls back to initials when logo url missing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FootballTeamCrest(name: 'Universitario', url: null)),
    ));
    expect(find.text('U'), findsOneWidget);
  });

  test('crest rejects non-http urls', () {
    final m = FootballMatch.fromJson({
      'id': 1,
      'competitionId': 'LIGA_1',
      'competition': 'Liga 1',
      'home': {'name': 'A', 'crestUrl': 'javascript:alert(1)'},
      'away': {'name': 'B', 'logoUrl': 'https://cdn.example/b.png'},
      'status': 'SCHEDULED',
    });
    expect(m.homeCrestUrl, isNull);
    expect(m.awayCrestUrl, 'https://cdn.example/b.png');
  });
}

// Lazy detail sections: CentroGarraMatchDetailPage loads EVENTS/LINEUPS/STATISTICS on tab body build (post-frame).
