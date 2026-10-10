import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/features/community/presentation/crema_chat_ambient_background.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/home/data/home_matchday_poll_service.dart';
import 'package:garra_digital_app/features/home/presentation/home_feed_featured_block.dart';
import 'package:garra_digital_app/features/home/presentation/home_matchday_poll_card.dart';

class _NoPollService extends HomeMatchdayPollService {
  _NoPollService() : super(dio: Dio());
  @override
  Future<HomeMatchdayPoll?> get(int fixtureId, String competition) async => null;
}

Future<void> pumpAmbient(WidgetTester tester, {required bool active, bool reduceMotion = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: CremaChatAmbientBackground(
        active: active,
        child: const SizedBox(key: ValueKey('ambient_child')),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('HomeFeedFeaturedBlock keeps feed header compact and unified', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final featured = AsyncValue.data(FootballFeaturedResult(
      featured: FootballFeatured(
        next: FootballMatch(
          id: 123,
          competitionId: 'LIGA_1',
          competition: 'Liga 1',
          home: 'Universitario',
          away: 'Melgar',
          status: 'SCHEDULED',
          kickoff: DateTime(2026, 10, 10, 19),
          kickoffConfirmed: true,
        ),
      ),
    ));
    await tester.pumpWidget(ProviderScope(
      overrides: [homeMatchdayPollServiceProvider.overrideWithValue(_NoPollService())],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HomeFeedFeaturedBlock(featured: featured),
              const Text('Feed social'),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('home_featured_match')), findsOneWidget);
    expect(find.text('Feed social'), findsOneWidget);
    expect(find.textContaining('19:00 (hora de Lima)'), findsOneWidget);
  });

  testWidgets('ambient animation pauses when inactive or reduce motion', (tester) async {
    await pumpAmbient(tester, active: true);
    expect(find.byKey(const ValueKey('crema_ambient_motion')), findsOneWidget);
    await pumpAmbient(tester, active: false);
    expect(find.byKey(const ValueKey('crema_ambient_static')), findsOneWidget);
    expect(find.image(const AssetImage('assets/brand/intro/garra_puma.png')), findsWidgets);
    expect(find.byKey(const ValueKey('crema_ambient_motion')), findsNothing);
    await pumpAmbient(tester, active: true, reduceMotion: true);
    expect(find.byKey(const ValueKey('crema_ambient_static')), findsOneWidget);
    expect(find.image(const AssetImage('assets/brand/intro/garra_puma.png')), findsWidgets);
    expect(find.byKey(const ValueKey('crema_ambient_motion')), findsNothing);
  });

  testWidgets('Comunidad Crema title string is used in community page app bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainShellBranchScope(
          activeBranch: 1,
          child: Scaffold(
            appBar: AppBar(title: const Text('Comunidad Crema')),
          ),
        ),
      ),
    );
    expect(find.text('Comunidad Crema'), findsOneWidget);
  });
}
