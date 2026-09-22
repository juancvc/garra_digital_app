import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/polla/data/matchday_poll_models.dart';
import 'package:garra_digital_app/features/polla/data/polla_models.dart';
import 'package:garra_digital_app/features/polla/data/polla_service.dart';
import 'package:garra_digital_app/features/polla/presentation/polla_page.dart';
import 'package:garra_digital_app/features/polla/presentation/providers/polla_provider.dart';
import 'package:garra_digital_app/features/polla/presentation/widgets/garra_mvp_poll.dart';
import 'package:garra_digital_app/features/polla/presentation/widgets/garra_poll_card.dart';
import 'package:garra_digital_app/features/predictions/data/create_prediction_request.dart';
import 'package:garra_digital_app/features/predictions/data/prediction_service.dart';
import 'package:go_router/go_router.dart';

PollaResponse samplePolla({
  String state = 'OPEN',
  int home = 0,
  int away = 0,
  bool withPrediction = false,
  PollaBreakdown? breakdown,
  int participants = 42,
}) {
  return PollaResponse(
    match: PollaMatchInfo(
      id: 'm1',
      homeTeam: 'Universitario',
      awayTeam: 'Rival FC',
      matchDateTime: DateTime.now().add(const Duration(hours: 6)),
      stadium: 'Monumental',
      competition: 'Liga 1',
      status: 'OPEN_FOR_PREDICTION',
      homeScore: state == 'SCORED' ? 2 : null,
      awayScore: state == 'SCORED' ? 0 : null,
      predictionClosesAt: DateTime.now().add(const Duration(hours: 4)),
    ),
    state: state,
    closesAt: DateTime.now().add(const Duration(hours: 4)),
    participants: participants,
    myPrediction: withPrediction
        ? PollaMyPrediction(
            homeScore: home,
            awayScore: away,
            firstScorer: 'Calcaterra',
            status: state == 'SCORED' ? 'SCORED' : 'SUBMITTED',
            pointsEarned: breakdown?.totalPoints,
            breakdown: breakdown,
          )
        : null,
    rules: const PollaRulesInfo(
      exactScorePoints: 5,
      outcomePoints: 3,
      firstScorerPoints: 4,
      note: 'Marcador exacto reemplaza resultado; primer goleador se suma.',
    ),
    sentiment: const PollaSentiment(
      homeWinPercent: 60,
      drawPercent: 20,
      awayWinPercent: 20,
      totalPredictions: 42,
    ),
  );
}

MatchPoll samplePoll({
  String id = 'poll-1',
  String type = 'GENERAL',
  String status = 'OPEN',
}) {
  return MatchPoll(
    id: id,
    matchId: 'm1',
    question: type == 'MVP' ? '¿Quién fue el MVP?' : '¿Cómo viste el partido?',
    type: type,
    status: status,
    voteCount: 10,
    options: const [
      MatchPollOption(
        id: 'opt-a',
        displayName: 'Opción A',
        shirtNumber: 10,
        sortOrder: 0,
        voteCount: 6,
      ),
      MatchPollOption(
        id: 'opt-b',
        displayName: 'Opción B',
        shirtNumber: 9,
        sortOrder: 1,
        voteCount: 4,
      ),
    ],
  );
}

MatchPollResults sampleResults({String? myVote = 'opt-a'}) {
  return MatchPollResults(
    pollId: 'poll-1',
    totalVotes: 10,
    myVoteOptionId: myVote,
    options: const [
      MatchPollOptionResult(
        optionId: 'opt-a',
        displayName: 'Opción A',
        shirtNumber: 10,
        sortOrder: 0,
        voteCount: 6,
        percentage: 60,
      ),
      MatchPollOptionResult(
        optionId: 'opt-b',
        displayName: 'Opción B',
        shirtNumber: 9,
        sortOrder: 1,
        voteCount: 4,
        percentage: 40,
      ),
    ],
  );
}

class FakePollaService extends PollaService {
  FakePollaService({required this.polla, this.submitResult, this.voteResults});

  PollaResponse polla;
  CreatePredictionResult? submitResult;
  MatchPollResults? voteResults;
  CreatePredictionRequest? lastRequest;
  String? lastVoteOptionId;
  int submitCount = 0;

  @override
  Future<PollaResponse> getPolla(String matchId) async => polla;

  @override
  Future<CreatePredictionResult> upsertPrediction(
    CreatePredictionRequest request,
  ) async {
    submitCount++;
    lastRequest = request;
    final result =
        submitResult ?? CreatePredictionResult.success('Predicción registrada');
    if (result.success) {
      polla = samplePolla(
        state: 'SUBMITTED',
        home: request.predictedHomeScore,
        away: request.predictedAwayScore,
        withPrediction: true,
        participants: polla.participants,
      );
    }
    return result;
  }

  @override
  Future<MatchPollResults> vote({
    required String pollId,
    required String optionId,
  }) async {
    lastVoteOptionId = optionId;
    return voteResults ??
        MatchPollResults(
          pollId: pollId,
          totalVotes: 11,
          myVoteOptionId: optionId,
          options: [
            MatchPollOptionResult(
              optionId: 'opt-a',
              displayName: 'Opción A',
              sortOrder: 0,
              voteCount: optionId == 'opt-a' ? 7 : 6,
              percentage: optionId == 'opt-a' ? 64 : 55,
            ),
            MatchPollOptionResult(
              optionId: 'opt-b',
              displayName: 'Opción B',
              sortOrder: 1,
              voteCount: optionId == 'opt-b' ? 5 : 4,
              percentage: optionId == 'opt-b' ? 45 : 36,
            ),
          ],
        );
  }
}

HomeModel sampleHome({
  String predictionState = 'NOT_PREDICTED',
  bool mvpOpen = false,
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
    matchdayState: 'UPCOMING',
    match: HomeMatch(
      id: 'm1',
      homeTeam: 'Universitario',
      awayTeam: 'Rival FC',
      matchDateTime: DateTime.now().add(const Duration(hours: 5)),
      stadium: 'Monumental',
      competition: 'Liga 1',
      status: 'OPEN_FOR_PREDICTION',
      matchdayState: 'UPCOMING',
    ),
    prediction: HomePrediction(
      state: predictionState,
      matchId: 'm1',
      predictedHomeScore: predictionState == 'NOT_PREDICTED' ? null : 2,
      predictedAwayScore: predictionState == 'NOT_PREDICTED' ? null : 1,
      firstScorer: predictionState == 'NOT_PREDICTED' ? null : 'Calcaterra',
      pointsEarned: predictionState == 'SCORED' ? 9 : null,
      predictionsOpen:
          predictionState == 'NOT_PREDICTED' || predictionState == 'PREDICTED',
    ),
    checkIn: const HomeCheckIn(
      showCheckInCta: false,
      hasActiveStadiumPoint: true,
      recentlyCheckedIn: false,
    ),
    community: const HomeCommunityPreview(matchId: 'm1', posts: []),
    notifications: const HomeNotifications(unreadCount: 0),
    mvpOpen: mvpOpen,
    mvpPollId: mvpOpen ? 'mvp-1' : null,
  );
}

Widget pumpPolla({required FakePollaService service, String matchId = 'm1'}) {
  return ProviderScope(
    overrides: [
      pollaServiceProvider.overrideWithValue(service),
      pollaProvider.overrideWith((ref, id) async => service.polla),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: PollaPage(matchId: matchId),
    ),
  );
}

Widget pumpHome(HomeModel home) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      GoRoute(
        path: '/polla/:matchId',
        builder: (_, __) => const Scaffold(body: Text('POLLA_ROUTE')),
      ),
      GoRoute(
        path: '/matchday/:matchId/polls',
        builder: (_, __) => const Scaffold(body: Text('MATCHDAY_POLLS')),
      ),
      GoRoute(
        path: '/passport',
        builder: (_, __) => const Scaffold(body: Text('PASSPORT')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const Scaffold(body: Text('NOTIF')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [homeProvider.overrideWith((ref) async => home)],
    child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  );
}

void main() {
  test('POLLA_MODEL_PARSES_RESPONSE', () {
    final parsed = PollaResponse.fromJson({
      'match': {
        'id': 'm1',
        'homeTeam': 'U',
        'awayTeam': 'R',
        'matchDateTime': '2026-09-20T20:00:00',
        'stadium': 'Monumental',
        'competition': 'Liga 1',
        'status': 'OPEN_FOR_PREDICTION',
      },
      'state': 'OPEN',
      'closesAt': '2026-09-20T19:00:00',
      'participants': 100,
      'myPrediction': null,
      'rules': {
        'exactScorePoints': 5,
        'outcomePoints': 3,
        'firstScorerPoints': 4,
      },
      'sentiment': {
        'homeWinPercent': 50,
        'drawPercent': 25,
        'awayWinPercent': 25,
        'totalPredictions': 100,
      },
    });
    expect(parsed.state, 'OPEN');
    expect(parsed.participants, 100);
    expect(parsed.rules.exactScorePoints, 5);
  });

  testWidgets('POLLA_V2_OPEN_RENDER', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = FakePollaService(polla: samplePolla());
    await tester.pumpWidget(pumpPolla(service: service));
    await tester.pumpAndSettle();
    expect(find.text('La Polla'), findsOneWidget);
    expect(find.text('Abierta'), findsOneWidget);
    expect(find.textContaining('Haz tu predic'), findsOneWidget);
    expect(find.textContaining('Registrar predic'), findsOneWidget);
    expect(find.textContaining('cremas ya jugaron'), findsOneWidget);
    expect(find.textContaining('vota la hinchada'), findsOneWidget);
    expect(find.text('Reglas'), findsOneWidget);
  });

  testWidgets('POLLA_SCORE_CHANGE', (tester) async {
    final service = FakePollaService(polla: samplePolla());
    await tester.pumpWidget(pumpPolla(service: service));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Subir').first);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('POLLA_SUBMIT', (tester) async {
    final service = FakePollaService(polla: samplePolla());
    await tester.pumpWidget(pumpPolla(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Subir').first);
    await tester.pump();
    await tester.tap(find.textContaining('Registrar predic'));
    await tester.pumpAndSettle();
    expect(service.submitCount, 1);
    expect(service.lastRequest?.predictedHomeScore, 1);
    expect(find.textContaining('Predicción registrada'), findsOneWidget);
  });

  testWidgets('POLLA_SUBMITTED_RENDER', (tester) async {
    final service = FakePollaService(
      polla: samplePolla(
        state: 'SUBMITTED',
        home: 2,
        away: 1,
        withPrediction: true,
      ),
    );
    await tester.pumpWidget(pumpPolla(service: service));
    await tester.pumpAndSettle();
    expect(find.text('Ya jugaste'), findsOneWidget);
    expect(find.textContaining('Actualiza tu predic'), findsOneWidget);
    expect(find.textContaining('Actualizar predic'), findsOneWidget);
  });

  testWidgets('POLLA_LOCKED_RENDER', (tester) async {
    final service = FakePollaService(
      polla: samplePolla(
        state: 'LOCKED',
        home: 2,
        away: 0,
        withPrediction: true,
      ),
    );
    await tester.pumpWidget(pumpPolla(service: service));
    await tester.pumpAndSettle();
    expect(find.text('Cerrada'), findsOneWidget);
    expect(find.textContaining('La Polla cerr'), findsOneWidget);
    expect(find.text('2 - 0'), findsOneWidget);
  });

  testWidgets('POLLA_SCORED_BREAKDOWN', (tester) async {
    final service = FakePollaService(
      polla: samplePolla(
        state: 'SCORED',
        home: 2,
        away: 0,
        withPrediction: true,
        breakdown: const PollaBreakdown(
          exactScorePoints: 5,
          outcomePoints: 0,
          firstScorerPoints: 4,
          totalPoints: 9,
          exactScoreHit: true,
          outcomeHit: false,
          firstScorerHit: true,
        ),
      ),
    );
    await tester.pumpWidget(pumpPolla(service: service));
    await tester.pumpAndSettle();
    expect(find.text('Puntuada'), findsOneWidget);
    expect(find.textContaining('Sumaste 9 Puntos Garra'), findsOneWidget);
    expect(find.text('Resultado'), findsOneWidget);
  });

  testWidgets('POLL_CARD_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraPollCard.fromPoll(
            poll: samplePoll(),
            results: sampleResults(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo viste el partido?'), findsOneWidget);
    expect(find.text('Opción A'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
  });

  testWidgets('POLL_VOTE', (tester) async {
    String? voted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraPollCard.fromPoll(
            poll: samplePoll(),
            results: sampleResults(myVote: null),
            onVote: (id) => voted = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opción B'));
    await tester.pump();
    expect(voted, 'opt-b');
  });

  testWidgets('POLL_CHANGE_VOTE', (tester) async {
    String? voted = 'opt-a';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return GarraPollCard.fromPoll(
                poll: samplePoll(),
                results: sampleResults(myVote: voted),
                onVote: (id) => setState(() => voted = id),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opción B'));
    await tester.pumpAndSettle();
    expect(voted, 'opt-b');
  });

  testWidgets('MVP_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraMvpPoll(
            poll: samplePoll(type: 'MVP'),
            results: sampleResults(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Quién fue el MVP?'), findsOneWidget);
    expect(find.text('N° 10'), findsOneWidget);
  });

  testWidgets('MVP_VOTE', (tester) async {
    String? voted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraMvpPoll(
            poll: samplePoll(type: 'MVP'),
            results: sampleResults(myVote: null),
            onVote: (id) => voted = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opción A'));
    await tester.pump();
    expect(voted, 'opt-a');
  });

  testWidgets('MVP_NO_CANDIDATES', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraMvpPoll(
            poll: MatchPoll(
              id: 'mvp',
              matchId: 'm1',
              question: 'MVP',
              type: 'MVP',
              status: 'OPEN',
              voteCount: 0,
              options: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no hay candidatos'), findsOneWidget);
  });

  testWidgets('HOME_POLLA_STATE', (tester) async {
    await tester.pumpWidget(pumpHome(sampleHome(predictionState: 'PREDICTED')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partido'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ya jugaste'), findsOneWidget);
    expect(find.text('Ver mi predicción'), findsOneWidget);
  });

  testWidgets('HOME_MVP_ENTRY', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(pumpHome(sampleHome(mvpOpen: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partido'));
    await tester.pumpAndSettle();
    final mvp = find.text('Vota por el MVP');
    expect(mvp, findsOneWidget);
    await tester.ensureVisible(mvp);
    await tester.pumpAndSettle();
    await tester.tap(mvp);
    await tester.pumpAndSettle();
    expect(find.text('MATCHDAY_POLLS'), findsOneWidget);
  });

  testWidgets('HOME_POLLA_CTA_ROUTE', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(pumpHome(sampleHome()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partido'));
    await tester.pumpAndSettle();
    expect(find.text('Haz tu predicción'), findsOneWidget);
    final cta = find.text('Hacer predicción');
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('POLLA_ROUTE'), findsOneWidget);
  });
}
