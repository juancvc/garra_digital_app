import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/features/history/data/history_models.dart';
import 'package:garra_digital_app/features/history/data/history_service.dart';
import 'package:garra_digital_app/features/history/presentation/history_page.dart';
import 'package:garra_digital_app/features/history/presentation/providers/history_provider.dart';
import 'package:garra_digital_app/features/history/presentation/year_recap_page.dart';
import 'package:garra_digital_app/features/history/widgets/garra_history_card.dart';
import 'package:garra_digital_app/features/history/widgets/garra_year_share_card.dart';
import 'package:garra_digital_app/features/passport/data/passport_models.dart';
import 'package:garra_digital_app/features/passport/presentation/passport_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/providers/passport_provider.dart';
import 'package:go_router/go_router.dart';

FanHistoryEntry sampleEntry({
  String id = 'h1',
  FanHistoryEntryType type = FanHistoryEntryType.predictionScored,
  String title = 'Sumaste 9 puntos en La Polla',
  DateTime? occurredAt,
}) {
  return FanHistoryEntry(
    id: id,
    type: type,
    occurredAt: occurredAt ?? DateTime.utc(2026, 9, 20, 18),
    calendarYear: 2026,
    title: title,
    subtitle: 'Universitario vs Rival',
  );
}

YearRecapModel sampleRecap({
  int year = 2026,
  bool empty = false,
}) {
  if (empty) {
    return YearRecapModel(
      year: year,
      identity: const YearRecapIdentity(displayName: 'Hincha Crema'),
      headline: YearRecapHeadline(title: 'Este fue tu $year crema'),
      stats: const YearRecapStats(),
      prediction: const YearRecapPrediction(),
      matchday: const YearRecapMatchday(),
      community: const YearRecapCommunity(),
      streak: const YearRecapStreak(),
      clan: const YearRecapClan(),
      highlights: const [],
      share: FanYearShareDto(
        displayName: 'Hincha Crema',
        year: year,
      ),
    );
  }

  return YearRecapModel(
    year: year,
    identity: const YearRecapIdentity(
      displayName: 'Hincha Crema',
      username: 'cremafan',
      levelName: 'Hincha Fiel',
      levelNumber: 2,
    ),
    headline: YearRecapHeadline(
      title: 'Este fue tu $year crema',
      subtitle: 'Así viviste el año con la U.',
    ),
    stats: const YearRecapStats(
      pointsEarned: 420,
      matchdaysParticipated: 18,
      checkIns: 12,
      stadiumCheckIns: 4,
      missionsCompleted: 12,
    ),
    prediction: const YearRecapPrediction(
      submitted: 22,
      scored: 20,
      points: 243,
      exactScores: 4,
      correctOutcomes: 11,
    ),
    matchday: const YearRecapMatchday(
      participated: 18,
      checkIns: 12,
      stadiumCheckIns: 4,
    ),
    community: const YearRecapCommunity(
      posts: 8,
      comments: 14,
      reactions: 60,
    ),
    streak: const YearRecapStreak(best: 7),
    clan: const YearRecapClan(
      name: 'Garra Surco',
      slug: 'garra-surco',
      pollaPoints: 88,
      joinedCount: 1,
    ),
    highlights: const [
      YearRecapHighlight(text: 'Tu mejor racha fue de 7 fechas'),
      YearRecapHighlight(text: 'Acertaste 4 marcadores exactos'),
    ],
    share: FanYearShareDto(
      displayName: 'Hincha Crema',
      year: year,
      levelName: 'Hincha Fiel',
      bestStreak: 7,
      predictionPoints: 243,
      matchdaysParticipated: 18,
      missionsCompleted: 12,
      pointsEarned: 420,
      primaryClanName: 'Garra Surco',
      tagline: 'Más que hinchas.',
    ),
  );
}

PassportModel samplePassportWithHistory() {
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
    stats: const PassportStats(
      checkIns: 3,
      predictions: 5,
      predictionPoints: 21,
      posts: 2,
      streakCurrent: 2,
      streakBest: 5,
    ),
    globalRank: 12,
    profileVisibility: 'PUBLIC',
    viewerIsOwner: true,
    currentYearSummary: const PassportCurrentYearSummary(
      year: 2026,
      pointsEarned: 420,
      matchdaysParticipated: 18,
      predictionsSubmitted: 22,
      missionsCompleted: 12,
    ),
  );
}

class FakeHistoryService extends HistoryService {
  FakeHistoryService({
    this.pages = const [],
    this.years = const [2026, 2025],
    YearRecapModel? recap,
    this.throwOnHistory = false,
  }) : recap = recap ?? sampleRecap();

  final List<HistoryPageResult> pages;
  final List<int> years;
  final YearRecapModel recap;
  final bool throwOnHistory;
  int historyCalls = 0;

  @override
  Future<HistoryPageResult> getMyHistory({
    String? cursor,
    int size = 20,
    int? year,
    String? type,
  }) async {
    historyCalls++;
    if (throwOnHistory) {
      throw Exception('history_unavailable');
    }
    if (pages.isEmpty) {
      return const HistoryPageResult(items: []);
    }
    if (cursor == null || cursor.isEmpty) {
      return pages.first;
    }
    for (var i = 0; i < pages.length - 1; i++) {
      if (pages[i].nextCursor == cursor) {
        return pages[i + 1];
      }
    }
    return pages.last;
  }

  @override
  Future<List<int>> getAvailableYears() async => years;

  @override
  Future<YearRecapModel> getYearRecap(int year) async {
    if (recap.year != year) {
      return sampleRecap(year: year, empty: true);
    }
    return recap;
  }
}

void main() {
  testWidgets('HISTORY_LOADING', (tester) async {
    final service = FakeHistoryService(
      pages: [
        HistoryPageResult(
          items: [sampleEntry()],
          hasNext: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HistoryPage(),
        ),
      ),
    );

    expect(find.byType(GarraSkeleton), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('HISTORY_EMPTY', (tester) async {
    final service = FakeHistoryService(pages: const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu historia recién comienza.'), findsOneWidget);
  });

  testWidgets('HISTORY_TIMELINE_RENDER', (tester) async {
    final service = FakeHistoryService(
      pages: [
        HistoryPageResult(
          items: [
            sampleEntry(id: '1', title: 'Sumaste 9 puntos en La Polla'),
            sampleEntry(
              id: '2',
              type: FanHistoryEntryType.matchCheckin,
              title: 'Hiciste check-in en un punto crema',
            ),
            sampleEntry(
              id: '3',
              type: FanHistoryEntryType.streakUpdated,
              title: 'Alcanzaste una racha de 5 fechas',
            ),
          ],
          hasNext: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GarraHistoryCard), findsNWidgets(3));
    expect(find.text('Sumaste 9 puntos en La Polla'), findsOneWidget);
    expect(find.text('Hiciste check-in en un punto crema'), findsOneWidget);
  });

  testWidgets('HISTORY_PAGINATION', (tester) async {
    final service = FakeHistoryService(
      pages: [
        HistoryPageResult(
          items: [sampleEntry(id: 'page1-a')],
          nextCursor: 'c2',
          hasNext: true,
        ),
        HistoryPageResult(
          items: [sampleEntry(id: 'page2-a', title: 'Completaste una misión')],
          hasNext: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GarraHistoryCard), findsOneWidget);
    expect(find.text('Cargar más'), findsOneWidget);

    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();

    expect(service.historyCalls, greaterThanOrEqualTo(2));
    expect(find.text('Completaste una misión'), findsOneWidget);
  });

  testWidgets('HISTORY_NO_DUPLICATES', (tester) async {
    final service = FakeHistoryService(
      pages: [
        HistoryPageResult(
          items: [
            sampleEntry(id: 'dup'),
            sampleEntry(id: 'dup', title: 'Duplicado fantasma'),
            sampleEntry(id: 'unique', title: 'Momento único'),
          ],
          hasNext: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GarraHistoryCard), findsNWidgets(2));
    expect(find.text('Duplicado fantasma'), findsNothing);
    expect(find.text('Momento único'), findsOneWidget);
  });

  testWidgets('YEAR_AVAILABLE_LIST', (tester) async {
    final service = FakeHistoryService(
      years: const [2026, 2025],
      pages: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi Año Crema 2026'), findsOneWidget);
    expect(find.text('Mi Año Crema 2025'), findsOneWidget);
  });

  testWidgets('YEAR_RECAP_RENDER', (tester) async {
    final service = FakeHistoryService(recap: sampleRecap());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const YearRecapPage(year: 2026),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2026 crema'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('La Polla'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('La Polla'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Racha Garra'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Racha Garra'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Comunidad'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Comunidad'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(GarraYearShareCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(GarraYearShareCard), findsOneWidget);
  });

  testWidgets('YEAR_RECAP_EMPTY_REAL_DATA', (tester) async {
    final service = FakeHistoryService(recap: sampleRecap(empty: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const YearRecapPage(year: 2026),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu historia recién comienza.'), findsWidgets);
  });

  testWidgets('YEAR_PREDICTION_STATS', (tester) async {
    final service = FakeHistoryService(recap: sampleRecap());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const YearRecapPage(year: 2026),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Marcadores exactos'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Marcadores exactos'), findsOneWidget);
    expect(find.text('Puntos Polla'), findsOneWidget);
    expect(find.text('243'), findsWidgets);
    expect(find.text('4'), findsWidgets);
  });

  testWidgets('YEAR_STREAK_STATS', (tester) async {
    final service = FakeHistoryService(recap: sampleRecap());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const YearRecapPage(year: 2026),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Racha Garra'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Racha Garra'), findsOneWidget);
    expect(find.text('7'), findsWidgets);
  });

  testWidgets('YEAR_COMMUNITY_STATS', (tester) async {
    final service = FakeHistoryService(recap: sampleRecap());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const YearRecapPage(year: 2026),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Publicaciones'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Publicaciones'), findsOneWidget);
    expect(find.text('Comentarios'), findsOneWidget);
    expect(find.text('Reacciones'), findsOneWidget);
  });

  test('SHARE_CARD_SAFE_FIELDS', () {
    final share = sampleRecap().share;
    final safe = share.safeFieldNames;

    expect(safe.contains('displayName'), isTrue);
    expect(safe.contains('year'), isTrue);
    expect(safe.contains('email'), isFalse);
    expect(safe.contains('phone'), isFalse);
    expect(safe.contains('latitude'), isFalse);
    expect(safe.contains('coordinates'), isFalse);

    final jsonKeys = {
      'displayName': share.displayName,
      'year': share.year,
      'bestStreak': share.bestStreak,
      'predictionPoints': share.predictionPoints,
    };
    expect(jsonKeys.containsKey('email'), isFalse);
    expect(jsonKeys.containsKey('phone'), isFalse);
  });

  testWidgets('SHARE_CARD_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraYearShareCard(share: sampleRecap().share),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('MI AÑO CREMA 2026'), findsOneWidget);
    expect(find.text('Hincha Crema'), findsOneWidget);
    expect(find.textContaining('Racha Garra'), findsOneWidget);
    expect(find.text('Más que hinchas.'), findsOneWidget);
  });

  testWidgets('PASSPORT_HISTORY_ENTRY', (tester) async {
    final router = GoRouter(
      initialLocation: '/passport',
      routes: [
        GoRoute(
          path: '/passport',
          builder: (context, state) => const PassportScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryPage(),
        ),
        GoRoute(
          path: '/history/year/:year',
          builder: (context, state) {
            final year =
                int.tryParse(state.pathParameters['year'] ?? '') ?? 2026;
            return YearRecapPage(year: year);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith(
            (ref) async => samplePassportWithHistory(),
          ),
          historyServiceProvider.overrideWithValue(FakeHistoryService()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Mi Historia Crema'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mi Historia Crema'), findsOneWidget);
    expect(find.text('Mi Año Crema 2026'), findsOneWidget);
  });

  test('history models parse cursor page and year recap', () {
    final page = HistoryPageResult.fromJson({
      'items': [
        {
          'id': '1',
          'type': 'MISSION_COMPLETED',
          'occurredAt': '2026-09-20T12:00:00Z',
          'calendarYear': 2026,
          'title': 'Completaste una misión',
        },
      ],
      'page': {
        'size': 20,
        'hasNext': true,
        'nextCursor': 'abc',
      },
    });
    expect(page.items, hasLength(1));
    expect(page.hasNext, isTrue);
    expect(page.nextCursor, 'abc');
    expect(page.items.first.variant, HistoryCardVariant.mission);

    final recap = YearRecapModel.fromJson({
      'year': 2026,
      'identity': {'displayName': 'Luis'},
      'headline': {'title': 'Este fue tu 2026 crema'},
      'stats': {'pointsEarned': 10, 'missionsCompleted': 2},
      'prediction': {'predictionPoints': 5, 'exactScores': 1},
      'matchday': {'matchdaysParticipated': 3},
      'community': {'postsCreated': 1, 'commentsCreated': 2, 'reactionsGiven': 4},
      'streak': {'bestStreak': 3},
      'clan': {'name': 'Surco', 'clanPollaPoints': 9},
      'highlights': [
        {'text': 'Completaste 2 misiones'},
      ],
      'share': {
        'displayName': 'Luis',
        'year': 2026,
        'bestStreak': 3,
      },
    });
    expect(recap.prediction.points, 5);
    expect(recap.community.reactions, 4);
    expect(recap.share.bestStreak, 3);
    expect(recap.hasMeaningfulActivity, isTrue);
  });
}
