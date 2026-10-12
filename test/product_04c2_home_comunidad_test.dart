import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/widgets/garra_puma_crest.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/community/presentation/community_social_page.dart';
import 'package:garra_digital_app/features/community/presentation/crema_chat_ambient_background.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/presentation/football_chat_room_view.dart';
import 'package:garra_digital_app/features/home/data/home_matchday_poll_service.dart';
import 'package:garra_digital_app/features/home/presentation/home_feed_featured_block.dart';
import 'package:garra_digital_app/features/home/presentation/home_matchday_poll_card.dart';

class _Net extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

class _Chat extends FootballChatService {
  _Chat() : super(dio: Dio());
  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    return const FootballChatPage(items: [], hasMore: false);
  }
}

class _NoPollService extends HomeMatchdayPollService {
  _NoPollService() : super(dio: Dio());
  @override
  Future<HomeMatchdayPoll?> get(int fixtureId, String competition) async => null;
}

void main() {
  testWidgets('ultracompact featured block fits small Android width without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
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
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Column(
              children: [
                HomeFeedFeaturedBlock(featured: featured),
                const Text('Feed social'),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Detalles del partido'), findsOneWidget);
    expect(find.textContaining('19:00 (hora de Lima)'), findsOneWidget);
    expect(find.text('Feed social'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambient layer uses official puma crest asset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CremaChatAmbientBackground(
          active: false,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsWidgets);
    expect(find.image(const AssetImage(GarraIntroAssets.puma)), findsWidgets);
  });

  testWidgets('Comunidad Crema title visible on narrow toolbar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          footballChatServiceProvider.overrideWithValue(_Chat()),
          connectivityStatusProvider.overrideWith(_Net.new),
        ],
        child: const MaterialApp(
          home: MainShellBranchScope(
            activeBranch: 0,
            child: CommunitySocialPage(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byKey(const ValueKey('comunidad_crema_title')), findsOneWidget);
    expect(find.text('Comunidad Crema'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
