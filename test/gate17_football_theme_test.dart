import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:garra_digital_app/core/theme/garra_appearance.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';

void main() {
  test('24 October kickoff is shown once in Lima at 20:30', () {
    final match = FootballMatch.fromJson({
      'id': 1,
      'competitionId': 'LIGA_1',
      'home': {'name': 'Universitario'},
      'away': {'name': 'Juan Pablo II'},
      'status': 'FINISHED',
      'kickoff': '2026-10-25T01:30:00Z',
      'homeScore': 3,
      'awayScore': 0,
    });
    expect(match.kickoff!.year, 2026);
    expect(match.kickoff!.month, 10);
    expect(match.kickoff!.day, 24);
    expect(footballClock(match.kickoff!), '20:30');
    expect(match.homeScore, 3);
    expect(match.awayScore, 0);
  });

  test('new installation defaults to Crema without saving an artificial choice', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(await GarraThemeStore(preferences: prefs).read(), GarraAppearance.crema);
    expect(prefs.containsKey(GarraThemeStore.storageKey), isFalse);
  });

  test('explicit Noche choice survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GarraThemeStore(preferences: prefs);
    await store.write(GarraAppearance.nocheMonumental);
    expect(await GarraThemeStore(preferences: prefs).read(), GarraAppearance.nocheMonumental);
  });
}
