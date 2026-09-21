import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/retention/data/retention_models.dart';
import 'package:garra_digital_app/features/retention/presentation/season_progress_page.dart';

void main() {
  test('SeasonProgressModel parses metrics', () {
    final model = SeasonProgressModel.fromJson({
      'seasonId': 's1',
      'seasonName': 'Temporada 2026',
      'pointsEarned': 120,
      'missionsCompleted': 2,
      'checkIns': 3,
      'globalPosts': 4,
      'comments': 1,
      'reactionsReceived': 0,
      'communitiesJoined': 1,
      'businessesFollowed': 2,
      'solidarityParticipations': 0,
      'matchdayParticipations': 1,
      'streakBest': 5,
      'referralsCompleted': 0,
      'achievementsUnlocked': 2,
      'eventCheckins': 1,
    });
    expect(model.seasonName, 'Temporada 2026');
    expect(model.pointsEarned, 120);
    expect(model.achievementsUnlocked, 2);
  });

  test('Achievement secret state hides criteria fields when locked', () {
    final locked = AchievementModel.fromJson({
      'id': 'a1',
      'code': 'TEMPORADA_VOZ',
      'name': 'Logro oculto',
      'description': 'Sigue participando para descubrirlo.',
      'category': 'HISTORIA',
      'iconKey': 'season',
      'rarity': 'RARE',
      'secret': true,
      'unlocked': false,
      'progress': null,
      'target': null,
      'nearUnlock': false,
    });
    expect(locked.secret, isTrue);
    expect(locked.unlocked, isFalse);
    expect(locked.name, 'Logro oculto');
    expect(locked.progress, isNull);
  });

  test('Event check-in label truth semantics', () {
    final event = GarraEventModel.fromJson({
      'id': 'e1',
      'title': 'Watch party',
      'type': 'WATCH_PARTY',
      'status': 'PUBLISHED',
      'verificationStatus': 'VERIFIED',
      'verifiedByGarra': true,
      'checkedIn': true,
      'checkInLabel': 'Check-in registrado en el evento',
      'myParticipation': 'GOING',
    });
    expect(event.checkInLabel, 'Check-in registrado en el evento');
    expect(event.checkInLabel!.toLowerCase().contains('asistencia oficial'), isFalse);
    expect(event.verifiedByGarra, isTrue);
  });

  test('Collection filters and truth copy for matchday', () {
    final item = CollectionItemModel.fromJson({
      'id': 'c1',
      'kind': 'MATCHDAY',
      'name': 'Matchday',
      'category': 'MATCHDAY',
      'at': '2026-09-21T00:00:00Z',
      'detail': 'Participaste en Matchday',
      'status': 'UNLOCKED',
    });
    expect(item.detail, 'Participaste en Matchday');
    expect(item.detail!.toLowerCase().contains('asististe al estadio'), isFalse);
  });

  test('Interest preferences skip completes onboarding', () {
    final prefs = InterestPreferencesModel.fromJson({
      'city': null,
      'region': null,
      'interests': <String>[],
      'onboardingCompleted': true,
    });
    expect(prefs.onboardingCompleted, isTrue);
    expect(prefs.interests, isEmpty);
  });

  test('DailyGarraModel destination routing keys', () {
    final daily = DailyGarraModel.fromJson({
      'type': 'NEAR_ACHIEVEMENT',
      'title': 'Casi lo tienes',
      'message': 'Te falta poco',
      'ctaLabel': 'Ver logros',
      'destination': '/logros',
    });
    expect(daily.destination, '/logros');
  });

  testWidgets('SeasonHeroCard renders calmer season surface', (tester) async {
    final progress = SeasonProgressModel.fromJson({
      'seasonId': 's1',
      'seasonName': 'Temporada 2026',
      'pointsEarned': 10,
      'missionsCompleted': 0,
      'checkIns': 1,
      'globalPosts': 0,
      'comments': 0,
      'reactionsReceived': 0,
      'communitiesJoined': 0,
      'businessesFollowed': 0,
      'solidarityParticipations': 0,
      'matchdayParticipations': 0,
      'streakBest': 2,
      'referralsCompleted': 0,
      'achievementsUnlocked': 1,
      'eventCheckins': 0,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeasonHeroCard(progress: progress),
        ),
      ),
    );
    expect(find.text('Temporada 2026'), findsOneWidget);
    expect(find.text('Ver progreso completo'), findsOneWidget);
    expect(find.textContaining('Hoy en Garra'), findsNothing);
  });

  test('Business rating label is community opinion', () {
    final summary = BusinessRatingSummary.fromJson({
      'averageRating': 4.5,
      'reviewCount': 2,
      'label': 'Nueva comunidad · 2 opiniones',
      'reviews': [],
    });
    expect(summary.label.toLowerCase().contains('compra verificada'), isFalse);
    expect(summary.reviewCount, 2);
  });
}
