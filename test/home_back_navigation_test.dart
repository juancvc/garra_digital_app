import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/navigation/main_shell.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';
import 'package:go_router/go_router.dart';

import 'home_screen_test.dart' show sampleHome;

class _Fan extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _Feed extends CommunityService {
  _Feed() : super(dio: Dio());
  int calls = 0;

  @override
  Future<FeedPage> getFeedPage({required String mode, String? cursor, int size = 20}) async => FeedPage(posts: await getGlobalFeed(mode: mode));

  @override
  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async {
    calls++;
    return List.generate(20, (i) => WallPostModel(
      id: 'post-$i',
      username: 'crema',
      fullName: 'Hincha Crema',
      content: 'Publicación $i',
      imageUrl: null,
      locationTag: 'HOME',
      status: 'ACTIVE',
      reportCount: 0,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ));
  }
}

GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomePage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/comunidad', builder: (_, _) => const Scaffold(body: Text('COMUNIDAD')))]),
        StatefulShellBranch(routes: [GoRoute(path: '/centro-garra', builder: (_, _) => const Scaffold(body: Text('CENTRO')))]),
        StatefulShellBranch(routes: [GoRoute(path: '/explorar', builder: (_, _) => const Scaffold(body: Text('EXPLORAR')))]),
        StatefulShellBranch(routes: [GoRoute(path: '/passport', builder: (_, _) => const Scaffold(body: Text('PERFIL')))]),
      ],
    ),
  ],
);

void main() {
  for (final view in ['Para ti', 'Siguiendo', 'Partido']) {
    testWidgets('Back scrolls visible Home $view to top without refresh', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final feed = _Feed();
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          homeProvider.overrideWith((ref) async => sampleHome(matchdayState: 'MATCHDAY')),
          communityServiceProvider.overrideWithValue(feed),
          currentFanProvider.overrideWith(_Fan.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      if (view != 'Para ti') {
        await tester.tap(find.text(view));
        await tester.pumpAndSettle();
      }
      final lists = view == 'Partido'
          ? find.descendant(of: find.byType(HomePage), matching: find.byType(ListView))
          : find.descendant(of: find.byType(SocialFeedTab), matching: find.byType(ListView));
      final list = lists.evaluate().map((element) => element.widget).whereType<ListView>().firstWhere((view) => view.controller != null);
      final controller = list.controller!;
      final listFinder = find.byWidget(list);
      await tester.drag(listFinder, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(96));
      final callsBeforeBack = feed.calls;
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(0, 0.1));
      expect(feed.calls, callsBeforeBack);
      expect(router.routeInformationProvider.value.uri.path, '/home');
    });
  }
}
