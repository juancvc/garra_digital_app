import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/core/widgets/garra_ui.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/locations/data/checkin_model.dart';
import 'package:garra_digital_app/features/locations/data/crema_point_model.dart';
import 'package:garra_digital_app/features/locations/data/create_checkin_request.dart';
import 'package:garra_digital_app/features/locations/presentation/widgets/garra_checkin_point_card.dart';
import 'package:garra_digital_app/features/locations/presentation/widgets/garra_checkin_success.dart';
import 'package:garra_digital_app/features/missions/data/mission_models.dart';
import 'package:garra_digital_app/features/missions/data/mission_service.dart';
import 'package:garra_digital_app/features/missions/presentation/missions_page.dart';
import 'package:garra_digital_app/features/missions/presentation/providers/missions_provider.dart';
import 'package:garra_digital_app/features/missions/presentation/widgets/garra_mission_card.dart';
import 'package:garra_digital_app/features/missions/presentation/widgets/garra_streak_card.dart';
import 'package:garra_digital_app/features/passport/data/passport_models.dart';
import 'package:garra_digital_app/features/passport/presentation/passport_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/providers/passport_provider.dart';
import 'package:go_router/go_router.dart';

/// API-shaped mission fixture (not a production seed).
MissionModel sampleMission({
  String id = 'mission-1',
  String title = 'Fecha crema completa',
  String? description = 'Predice, reacciona y haz check-in.',
  int completedSteps = 1,
  int totalSteps = 3,
  int rewardPoints = 25,
  bool completed = false,
  List<MissionStepModel>? steps,
}) {
  return MissionModel(
    id: id,
    title: title,
    description: description,
    scopeType: 'MATCH',
    scopeReferenceId: 'm1',
    status: 'ACTIVE',
    startsAt: DateTime.parse('2026-09-20T12:00:00Z'),
    endsAt: DateTime.parse('2026-09-21T04:00:00Z'),
    rewardPoints: rewardPoints,
    countsForStreak: true,
    completedSteps: completedSteps,
    totalSteps: totalSteps,
    completed: completed,
    completedAt: completed ? DateTime.parse('2026-09-20T20:00:00Z') : null,
    steps: steps ??
        [
          const MissionStepModel(
            stepId: 'step-1',
            actionType: 'PREDICTION_SUBMITTED',
            title: 'Envía tu predicción',
            requiredCount: 1,
            currentCount: 1,
            completed: true,
            sortOrder: 0,
          ),
          const MissionStepModel(
            stepId: 'step-2',
            actionType: 'POST_REACTION',
            title: 'Reacciona en el muro',
            requiredCount: 1,
            currentCount: 0,
            completed: false,
            sortOrder: 1,
          ),
          const MissionStepModel(
            stepId: 'step-3',
            actionType: 'CHECKIN_COMPLETED',
            title: 'Haz check-in en un punto crema',
            requiredCount: 1,
            currentCount: 0,
            completed: false,
            sortOrder: 2,
          ),
        ],
  );
}

CheckInModel sampleCheckIn({
  bool matchLinked = true,
  int awardedPoints = 10,
}) {
  return CheckInModel(
    id: 'checkin-1',
    cremaPointId: 'point-1',
    cremaPointName: 'Estadio Monumental',
    distanceMeters: 42,
    pointsEarned: awardedPoints,
    awardedPoints: awardedPoints,
    status: 'VALID',
    createdAt: '2026-09-20T18:00:00Z',
    valid: true,
    matchLinked: matchLinked,
    matchId: matchLinked ? 'm1' : null,
    newBalance: 1850,
    checkinRadiusMeters: 500,
  );
}

CremaPointModel samplePoint({int radius = 500}) {
  return CremaPointModel(
    id: 'point-1',
    name: 'Estadio Monumental',
    description: 'La casa crema',
    type: 'STADIUM',
    address: 'Av. Javier Prado Este 4200',
    latitude: -12.056,
    longitude: -76.936,
    verified: true,
    sponsor: false,
    status: 'ACTIVE',
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
    checkinRadiusMeters: radius,
  );
}

HomeModel sampleHomeWithMission({
  bool withMission = true,
  bool withStreak = true,
}) {
  return HomeModel(
    fan: const HomeFanSummary(
      displayName: 'Hincha Crema',
      username: 'cremafan',
      levelNumber: 2,
      levelName: 'Hincha Fiel',
      points: 1840,
      globalRank: 428,
    ),
    matchdayState: 'MATCHDAY',
    match: HomeMatch(
      id: 'm1',
      homeTeam: 'Universitario',
      awayTeam: 'Rival FC',
      matchDateTime: DateTime.now().add(const Duration(hours: 5)),
      stadium: 'Monumental',
      competition: 'Liga 1',
      status: 'OPEN_FOR_PREDICTION',
      matchdayState: 'MATCHDAY',
    ),
    prediction: const HomePrediction(
      state: 'NOT_PREDICTED',
      matchId: 'm1',
      predictionsOpen: true,
    ),
    checkIn: const HomeCheckIn(
      showCheckInCta: true,
      hasActiveStadiumPoint: true,
      recentlyCheckedIn: false,
      ctaLabel: 'Hacer check-in',
    ),
    community: const HomeCommunityPreview(matchId: 'm1', posts: []),
    notifications: const HomeNotifications(unreadCount: 0),
    mission: withMission
        ? const HomeMissionSummary(
            id: 'mission-1',
            title: 'Fecha crema completa',
            completedSteps: 1,
            totalSteps: 3,
            rewardPoints: 25,
            completed: false,
          )
        : null,
    streak: withStreak
        ? const HomeStreakSummary(current: 3, best: 7)
        : null,
  );
}

PassportModel samplePassportWithStreak({
  int streakCurrent = 3,
  int streakBest = 7,
}) {
  return PassportModel(
    identity: const PassportIdentity(
      username: 'cremafan',
      displayName: 'Hincha Crema',
      city: 'Lima',
      countryCode: 'PE',
      supporterSinceYear: 1998,
    ),
    level: const PassportLevel(
      number: 2,
      name: 'Hincha Fiel',
      points: 100,
      levelMinPoints: 50,
      nextLevelPoints: 150,
      progressPercent: 50,
      pointsToNextLevel: 50,
    ),
    stats: PassportStats(
      checkIns: 3,
      predictions: 5,
      predictionPoints: 21,
      posts: 2,
      streakCurrent: streakCurrent,
      streakBest: streakBest,
    ),
    globalRank: 12,
    profileVisibility: 'PUBLIC',
    viewerIsOwner: true,
  );
}

class FakeMissionService extends MissionService {
  FakeMissionService(this.missions);

  final List<MissionModel> missions;

  @override
  Future<List<MissionModel>> getMyMissions({
    String? matchId,
    bool active = true,
  }) async =>
      missions;

  @override
  Future<List<MissionModel>> getMyMissionsForMatch(
    String matchId, {
    bool active = true,
  }) async =>
      missions;
}

Widget pumpMissions(List<MissionModel> missions, {String? matchId}) {
  return ProviderScope(
    overrides: [
      missionServiceProvider.overrideWithValue(FakeMissionService(missions)),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: MissionsPage(matchId: matchId),
    ),
  );
}

Widget pumpHome(HomeModel home) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/missions',
        builder: (context, state) =>
            Scaffold(body: Text('MISSIONS:${state.uri.queryParameters['matchId'] ?? ''}')),
      ),
      GoRoute(
        path: '/mapa-crema',
        builder: (context, state) => Scaffold(
          body: Text('MAPA:${state.uri.queryParameters['matchId'] ?? ''}'),
        ),
      ),
      GoRoute(
        path: '/passport',
        builder: (context, state) =>
            const Scaffold(body: Text('PASSPORT_ROUTE')),
      ),
      GoRoute(
        path: '/polla/:matchId',
        builder: (context, state) => const Scaffold(body: Text('POLLA')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const Scaffold(body: Text('NOTIF')),
      ),
      GoRoute(
        path: '/muro-crema',
        builder: (context, state) => const Scaffold(body: Text('MURO')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      homeProvider.overrideWith((ref) async => home),
    ],
    child: MaterialApp.router(
      theme: AppTheme.darkTheme,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('MISSION_CARD_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraMissionCard(mission: sampleMission()),
        ),
      ),
    );
    expect(find.text('Fecha crema completa'), findsOneWidget);
    expect(find.textContaining('Puntos Garra'), findsOneWidget);
    expect(find.text('+25 pts'), findsOneWidget);
  });

  testWidgets('MISSION_PROGRESS_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraMissionCard(
            mission: sampleMission(completedSteps: 1, totalSteps: 3),
            showSteps: true,
          ),
        ),
      ),
    );
    expect(find.byType(GarraProgressBar), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('Envía tu predicción'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('MISSION_COMPLETED_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraMissionCard(
            mission: sampleMission(
              completedSteps: 3,
              totalSteps: 3,
              completed: true,
              rewardPoints: 25,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Completada'), findsOneWidget);
    expect(find.textContaining('+25 Puntos Garra'), findsOneWidget);
  });

  testWidgets('MISSION_EMPTY_STATE', (tester) async {
    await tester.pumpWidget(pumpMissions(const []));
    await tester.pumpAndSettle();
    expect(find.byType(GarraEmptyState), findsOneWidget);
    expect(find.text('Sin misiones activas'), findsOneWidget);
  });

  testWidgets('STREAK_ZERO_STATE', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: GarraStreakCard(
            streak: StreakSummary(current: 0, best: 0),
          ),
        ),
      ),
    );
    expect(find.text('Racha Garra'), findsOneWidget);
    expect(find.textContaining('Aún no tienes racha'), findsOneWidget);
    expect(find.textContaining('asistencia'), findsNothing);
  });

  testWidgets('STREAK_ACTIVE_STATE', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: GarraStreakCard(
            streak: StreakSummary(current: 3, best: 7),
          ),
        ),
      ),
    );
    expect(find.text('Racha Garra'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.textContaining('fechas'), findsWidgets);
    expect(find.textContaining('asistencia'), findsNothing);
  });

  testWidgets('CHECKIN_MATCH_CONTEXT', (tester) async {
    final request = CreateCheckInRequest(
      cremaPointId: 'point-1',
      latitude: -12.05,
      longitude: -76.93,
      matchId: 'm1',
      accuracyMeters: 12.5,
    );
    expect(request.toJson()['matchId'], 'm1');
    expect(request.toJson()['accuracyMeters'], 12.5);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraCheckInPointCard(
            point: samplePoint(),
            distanceMeters: 40,
            matchContext: true,
          ),
        ),
      ),
    );
    expect(find.text('Radio de check-in: 500 m'), findsOneWidget);
    expect(find.text('Estás a 40 m'), findsOneWidget);
    expect(find.text('Check-in de fecha activa'), findsOneWidget);
  });

  testWidgets('CHECKIN_SUCCESS_REWARD', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraCheckInSuccess(checkIn: sampleCheckIn()),
        ),
      ),
    );
    expect(find.text('CHECK-IN COMPLETADO'), findsOneWidget);
    expect(find.text('Estadio Monumental'), findsOneWidget);
    expect(find.text('+10 Puntos Garra'), findsOneWidget);
    expect(find.text('Cuenta para la fecha de hoy'), findsOneWidget);

    final parsed = CheckInModel.fromJson({
      'id': 'c1',
      'cremaPointId': 'p1',
      'cremaPointName': 'Bar Crema',
      'distanceMeters': 10,
      'awardedPoints': 10,
      'pointsEarned': 10,
      'status': 'VALID',
      'valid': true,
      'matchLinked': false,
      'createdAt': '2026-09-20T18:00:00Z',
      'checkinRadiusMeters': 300,
    });
    expect(parsed.displayPoints, 10);
    expect(parsed.matchLinked, isFalse);
    expect(parsed.checkinRadiusMeters, 300);
  });

  testWidgets('HOME_MISSION_SUMMARY', (tester) async {
    await tester.pumpWidget(pumpHome(sampleHomeWithMission()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Fecha crema completa'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fecha crema completa'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('Ver misión'), findsOneWidget);
    await tester.tap(find.text('Ver misión'));
    await tester.pumpAndSettle();
    expect(find.text('MISSIONS:m1'), findsOneWidget);
  });

  testWidgets('HOME_STREAK_SUMMARY', (tester) async {
    await tester.pumpWidget(pumpHome(sampleHomeWithMission()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Racha Garra'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Racha Garra'), findsOneWidget);
    expect(find.textContaining('asistencia'), findsNothing);
  });

  testWidgets('PASSPORT_STREAK_RENDER', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith(
            (ref) async => samplePassportWithStreak(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PassportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Racha Garra'), findsOneWidget);
    expect(find.text('Mejor racha'), findsOneWidget);
    expect(find.text('Participación en fechas'), findsOneWidget);
    expect(find.textContaining('asistencia'), findsNothing);
  });
}
