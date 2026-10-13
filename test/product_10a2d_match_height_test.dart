// PRODUCT-10A.2D: comparable height measurement of the embedded featured
// match card (same fixture, same clock, textScale 1.0).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_featured_match_card.dart';

final _now = DateTime.utc(2026, 10, 13, 17); // 12:00 Lima
final _match = FootballMatch(
  id: 2811, competitionId: 'LIGA_1', competition: 'Liga 1 Perú',
  round: 'Clausura - 11', home: 'Universitario', away: 'FBC Melgar',
  status: 'SCHEDULED', kickoff: DateTime(2026, 10, 14, 19),
  kickoffConfirmed: true,
);

Future<Size> _measure(WidgetTester tester, Size surface) async {
  await tester.binding.setSurfaceSize(surface);
  await tester.pumpWidget(ProviderScope(child: MediaQuery(
    data: MediaQueryData(size: surface, textScaler: TextScaler.noScaling),
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: HomeFeaturedMatchCard(embedded: true, now: _now,
        result: AsyncValue.data(FootballFeaturedResult(
          featured: FootballFeatured(next: _match)))),
    ))),
  )));
  await tester.pump();
  expect(tester.takeException(), isNull);
  return tester.getSize(find.byKey(const ValueKey('home_featured_match')));
}

void main() {
  for (final surface in const [Size(360, 800), Size(411, 891)]) {
    testWidgets('MATCH_CARD_HEIGHT ${surface.width.toInt()}x${surface.height.toInt()}',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final size = await _measure(tester, surface);
      // ignore: avoid_print
      print('MATCH_CARD_HEIGHT ${surface.width.toInt()}x${surface.height.toInt()} = ${size.height}');
      expect(size.height, greaterThan(0));
    });
  }
}
