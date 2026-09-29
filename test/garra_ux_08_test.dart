import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/engagement_utils.dart';
import 'package:garra_digital_app/features/community/data/reaction_result.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_comment_reactions.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reaction_burst.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';
import 'package:go_router/go_router.dart';

WallPostModel _post({
  String? myReaction,
  int reactionCount = 0,
  Map<String, int> reactionSummary = const {},
}) {
  return WallPostModel(
    id: 'post-1',
    username: 'crema',
    fullName: 'Hincha Crema',
    content: 'Vamos la U',
    imageUrl: null,
    locationTag: 'HOME',
    status: 'ACTIVE',
    reportCount: 0,
    createdAt: DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 8))
        .toIso8601String(),
    myReaction: myReaction,
    reactionCount: reactionCount,
    // Backend always sends every key (zeros included).
    reactionSummary: {
      for (final key in ['LIKE', 'LOVE', 'FIRE', 'ANGER', 'SAD', 'GARRA'])
        key: reactionSummary[key] ?? 0,
    },
  );
}

class _ReactionService extends CommunityService {
  _ReactionService(this.post) : super(dio: Dio());

  WallPostModel post;
  final List<String> calls = [];
  bool failRemove = false;
  Completer<void>? hold;

  @override
  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async {
    return [post];
  }

  @override
  Future<ReactionResult> upsertReaction({
    required String postId,
    required String type,
  }) async {
    calls.add('upsert:$type');
    if (hold != null) await hold!.future;
    post = applyOptimisticReaction(post, type);
    return ReactionResult.success(
      message: 'ok',
      myReaction: post.myReaction,
      reactionSummary: post.reactionSummary,
      reactionCount: post.reactionCount,
    );
  }

  @override
  Future<ReactionResult> removeReaction(String postId) async {
    calls.add('remove');
    if (hold != null) await hold!.future;
    if (failRemove) return ReactionResult.failure('boom');
    post = applyOptimisticReaction(post, null);
    return ReactionResult.success(
      message: 'ok',
      myReaction: null,
      reactionSummary: post.reactionSummary,
      reactionCount: post.reactionCount,
    );
  }
}

class _NoFan extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

Future<void> _pumpFeed(
  WidgetTester tester,
  _ReactionService service, {
  bool disableAnimations = false,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: SocialFeedTab(mode: 'FOR_YOU')),
      ),
      GoRoute(
        path: '/muro-crema/posts/:id',
        builder: (_, _) => const Scaffold(body: Text('DETAIL')),
      ),
    ],
  );
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityServiceProvider.overrideWithValue(service),
        currentFanProvider.overrideWith(_NoFan.new),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _summary => find.byKey(const ValueKey('post_reaction_summary'));
Finder get _action => find.byKey(const ValueKey('reaction_cta'));
Finder get _burst => find.byKey(const ValueKey('garra_reaction_burst'));
Finder get _picker => find.byKey(const ValueKey('post_reaction_picker'));

Finder _summaryCount(String text) =>
    find.descendant(of: _summary, matching: find.text(text));

void main() {
  setUp(GarraReactionAnchor.reset);

  group('UX_08 reaction toggle', () {
    testWidgets('1. tap on the active reaction sends DELETE (no picker)', (
      tester,
    ) async {
      final service = _ReactionService(
        _post(myReaction: 'FIRE', reactionCount: 3, reactionSummary: {
          'FIRE': 3,
        }),
      );
      await _pumpFeed(tester, service);

      await tester.tap(_action);
      await tester.pumpAndSettle();

      expect(_picker, findsNothing);
      expect(service.calls, ['remove']);
      expect(find.byKey(const ValueKey('post_my_reaction')), findsNothing);
    });

    testWidgets('2. counter and summary drop immediately (optimistic)', (
      tester,
    ) async {
      final service = _ReactionService(
        _post(myReaction: 'LOVE', reactionCount: 4, reactionSummary: {
          'LOVE': 3,
          'FIRE': 1,
        }),
      )..hold = Completer<void>();
      await _pumpFeed(tester, service);
      expect(_summaryCount('4'), findsOneWidget);

      await tester.tap(_action);
      await tester.pump();

      // Request still in flight: UI already updated.
      expect(service.calls, ['remove']);
      expect(find.byKey(const ValueKey('post_my_reaction')), findsNothing);
      expect(_summaryCount('3'), findsOneWidget);
      expect(_summaryCount('4'), findsNothing);

      service.hold!.complete();
      await tester.pumpAndSettle();
      expect(_summaryCount('3'), findsOneWidget);
    });

    testWidgets('3. DELETE error rolls back and shows a friendly message', (
      tester,
    ) async {
      final service = _ReactionService(
        _post(myReaction: 'FIRE', reactionCount: 2, reactionSummary: {
          'FIRE': 2,
        }),
      )..failRemove = true;
      await _pumpFeed(tester, service);

      await tester.tap(_action);
      await tester.pumpAndSettle();

      expect(service.calls, ['remove']);
      expect(find.byKey(const ValueKey('post_my_reaction')), findsOneWidget);
      expect(_summaryCount('2'), findsOneWidget);
      expect(
        find.text('No se pudo quitar la reacci\u00f3n. Int\u00e9ntalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('4. long-press changes the reaction (PUT, not DELETE)', (
      tester,
    ) async {
      final service = _ReactionService(
        _post(myReaction: 'LOVE', reactionCount: 1, reactionSummary: {
          'LOVE': 1,
        }),
      );
      await _pumpFeed(tester, service);

      await tester.longPress(_action);
      await tester.pumpAndSettle();
      expect(_picker, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reaction_option_FIRE')));
      await tester.pumpAndSettle();

      expect(service.calls, ['upsert:FIRE']);
      expect(service.post.myReaction, 'FIRE');
      expect(_summaryCount('1'), findsOneWidget);
    });

    testWidgets('no reaction: tap opens the picker and adds', (tester) async {
      final service = _ReactionService(_post());
      await _pumpFeed(tester, service);

      await tester.tap(_action);
      await tester.pumpAndSettle();
      expect(_picker, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reaction_option_LOVE')));
      await tester.pumpAndSettle();

      expect(service.calls, ['upsert:LOVE']);
      expect(find.byKey(const ValueKey('post_my_reaction')), findsOneWidget);
    });
  });

  group('UX_08 GARRA micro-animation', () {
    testWidgets('5. plays only when GARRA is explicitly selected', (
      tester,
    ) async {
      final service = _ReactionService(_post());
      await _pumpFeed(tester, service);

      await tester.tap(_action);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reaction_option_GARRA')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(_burst, findsOneWidget);
      expect(
        tester.widget<IgnorePointer>(_burst).ignoring,
        isTrue,
        reason: 'overlay must never block taps',
      );
      expect(
        find.descendant(of: _burst, matching: find.byType(GarraClawReactionGlyph)),
        findsOneWidget,
      );

      await tester.pump(garraBurstDuration);
      await tester.pumpAndSettle();
      expect(_burst, findsNothing, reason: 'overlay removes itself');
      expect(service.calls, ['upsert:GARRA']);
    });

    testWidgets('5b. no burst for other reactions or when removing GARRA', (
      tester,
    ) async {
      final service = _ReactionService(_post());
      await _pumpFeed(tester, service);

      await tester.tap(_action);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reaction_option_FIRE')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_burst, findsNothing);
      await tester.pumpAndSettle();

      // Change to GARRA then remove it: only the selection animates.
      await tester.longPress(_action);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reaction_option_GARRA')));
      await tester.pumpAndSettle();
      await tester.tap(_action);
      await tester.pump(const Duration(milliseconds: 120));
      expect(_burst, findsNothing);
      await tester.pumpAndSettle();
      expect(service.calls, ['upsert:FIRE', 'upsert:GARRA', 'remove']);
    });

    testWidgets('5c. respects reduce motion (disableAnimations)', (
      tester,
    ) async {
      final service = _ReactionService(_post());
      await _pumpFeed(tester, service, disableAnimations: true);

      await tester.tap(_action);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reaction_option_GARRA')));
      await tester.pump(const Duration(milliseconds: 120));

      expect(_burst, findsNothing);
      await tester.pumpAndSettle();
      expect(service.calls, ['upsert:GARRA']);
    });

    testWidgets('6. no burst on load or refresh of a GARRA-reacted post', (
      tester,
    ) async {
      final service = _ReactionService(
        _post(myReaction: 'GARRA', reactionCount: 5, reactionSummary: {
          'GARRA': 5,
        }),
      );
      await _pumpFeed(tester, service);
      expect(_burst, findsNothing);
      expect(
        find.descendant(
          of: _summary,
          matching: find.byType(GarraClawReactionGlyph),
        ),
        findsWidgets,
      );
    });
  });
}
