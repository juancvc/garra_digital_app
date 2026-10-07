import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/presentation/football_standings_view.dart';

List<Map<String, dynamic>> _ladder(String group, int from, int to, {int idBase = 1}) => [
      for (var r = from; r <= to; r++)
        {
          'group': group,
          'rank': r,
          'team': group.isEmpty ? 'Equipo $idBase$r' : '$group-$r',
          'teamId': idBase * 100 + r,
          'played': 10,
          'goalDifference': 5 - r,
          'points': 30 - r,
          'crestUrl': 'https://example.com/$r.png',
        },
    ];

void main() {
  group('SONIC_06B Liga 2 standings boundaries', () {
    test('two blank-group ladders are never concatenated (rank-reset split)', () {
      final rows = [
        ..._ladder('', 1, 9, idBase: 1),
        ...[
          for (var r = 1; r <= 9; r++)
            {
              'group': '',
              'rank': r,
              'team': r == 1 ? 'Bentín' : 'B$r',
              'teamId': 200 + r,
              'played': 10,
              'goalDifference': 0,
              'points': 20 - r,
            },
        ],
      ];
      final stages = FootballStandingStage.fromRows(rows);
      expect(stages.length, 1);
      expect(stages.first.groups.length, 2);
      expect(stages.first.groups.map((g) => g.key).toList(), ['Tabla 1', 'Tabla 2']);
      expect(stages.first.rowsFor('Tabla 1').last['rank'], 9);
      expect(stages.first.rowsFor('Tabla 2').first['team'], 'Bentín');
      expect(stages.first.rowsFor('Tabla 1').where((r) => r['rank'] == 1).length, 1);
      expect(stages.first.rowsFor('Tabla 2').where((r) => r['rank'] == 1).length, 1);
      // .rows never concatenates:
      expect(stages.first.rows.where((r) => r['rank'] == 1).length, 1);
    });

    test('backend Tabla 1 / Tabla 2 labels become group chips under one stage', () {
      final stages = FootballStandingStage.fromRows([
        ..._ladder('Tabla 1', 1, 9, idBase: 1),
        ..._ladder('Tabla 2', 1, 9, idBase: 2),
      ]);
      expect(stages.single.name, 'Tabla');
      expect(stages.single.groups.map((g) => g.key), ['Tabla 1', 'Tabla 2']);
    });

    test('distinct Group A / Group B stay separate without inventing names', () {
      final stages = FootballStandingStage.fromRows([
        ..._ladder('Group A', 1, 4, idBase: 1),
        ..._ladder('Group B', 1, 4, idBase: 2),
      ]);
      expect(stages.single.groups.map((g) => g.key), ['Group A', 'Group B']);
    });

    test('footballStandingBlocksByRankReset', () {
      final blocks = footballStandingBlocksByRankReset([
        {'rank': 8},
        {'rank': 9},
        {'rank': 1, 'team': 'Bentín'},
        {'rank': 2},
      ]);
      expect(blocks.length, 2);
      expect(blocks[1].first['team'], 'Bentín');
    });

    testWidgets('UI selector switches tables; only one rank 1 visible; 360 ok', (tester) async {
      String? stage = 'Tabla';
      String? group = 'Tabla 1';
      final rows = [
        ..._ladder('Tabla 1', 1, 9, idBase: 1),
        ...[
          for (var r = 1; r <= 9; r++)
            {
              'group': 'Tabla 2',
              'rank': r,
              'team': r == 1 ? 'Bentín' : 'Rival $r',
              'teamId': 300 + r,
              'played': 8,
              'goalDifference': 1,
              'points': 18 - r,
              'crestUrl': 'https://example.com/b$r.png',
            },
        ],
      ];
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            return FootballStandingsView(
              rows: rows,
              competitionName: 'Liga 2 Perú',
              selectedStage: stage,
              selectedGroup: group,
              featuredTeamId: 301,
              onStageChanged: (s) => setState(() {
                    stage = s;
                    group = null;
                  }),
              onGroupChanged: (g) => setState(() => group = g),
            );
          }),
        ),
      ));
      expect(find.byKey(const ValueKey('group_Tabla 1')), findsOneWidget);
      expect(find.byKey(const ValueKey('group_Tabla 2')), findsOneWidget);
      expect(find.text('Bentín'), findsNothing);
      expect(find.text('Tabla 1-1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group_Tabla 2')));
      await tester.pump();
      expect(find.text('Bentín'), findsOneWidget);
      expect(find.byKey(const ValueKey('standing_featured_row')), findsOneWidget);
      expect(find.text('Tabla 1-1'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
