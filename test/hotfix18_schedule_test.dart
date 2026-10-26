import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';

void main() {
  Map<String, dynamic> payload({required bool verified, required String kickoff}) => {
        'id': 1549535,
        'competitionId': 'LIGA_1',
        'competition': 'Liga 1 Perú',
        'home': {'id': 2540, 'name': 'Universitario'},
        'away': {'id': 2544, 'name': 'Sport Boys'},
        'status': 'SCHEDULED',
        'kickoff': kickoff,
        'kickoffConfirmed': true,
        'scheduleVerified': verified,
        'snapshotAt': '2026-10-25T16:08:03Z',
      };

  test('verified schedule survives an older unverified snapshot', () {
    final official = FootballMatch.fromJson(payload(
      verified: true,
      kickoff: '2026-11-05T01:30:00Z',
    ));
    final old = FootballMatch.fromJson(payload(
      verified: false,
      kickoff: '2026-10-28T21:00:00Z',
    ));
    expect(official.scheduleVerified, isTrue);
    expect(FootballMatch.fresher(official, old).kickoff, official.kickoff);
    expect(FootballMatch.fresher(old, official).kickoff, official.kickoff);
  });
}
