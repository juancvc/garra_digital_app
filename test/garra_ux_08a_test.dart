import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/engagement_utils.dart';
import 'package:garra_digital_app/features/community/data/reaction_result.dart';
import 'package:garra_digital_app/features/community/data/reaction_type.dart';
import 'package:garra_digital_app/features/community/data/reactor_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_comment_reactions.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reaction_burst.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reaction_picker.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reactors_sheet.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';
import 'package:go_router/go_router.dart';

// UX_08A: complete reaction catalog (LIKE, LOVE, FIRE, HAHA, CARE, ANGER,
// SAD, GARRA). HAHA and CARE are real backend types.

const _labels = {
  'LIKE': 'Me gusta',
  'LOVE': 'Me encanta',
  'FIRE': 'Est\u00e1 que arde',
  'HAHA': 'Me divierte',
  'CARE': 'Me importa',
  'ANGER': 'Me enoja',
  'SAD': 'Me entristece',
  'GARRA': 'Garra',
};

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
    reactionSummary: {
      for (final key in reactionSummaryKeys) key: reactionSummary[key] ?? 0,
    },
  );
}

class _ReactionService extends CommunityService {
  _ReactionService(this.post) : super(dio: Dio());

  WallPostModel post;
  final List<String> calls = [];

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
    post = applyOptimisticReaction(post, null);
    return ReactionResult.success(
      message: 'ok',
      myReaction: null,
      reactionSummary: post.reactionSummary,
      reactionCount: post.reactionCount,
    );
  }

  @override
  Future<ReactorsPage> getPostReactors(
    String postId, {
    String? cursor,
    int size = 30,
  }) async {
    ReactorItem item(String id, String type) => ReactorItem(
      fanId: id,
      username: 'user_$id',
      displayName: 'Hincha $id',
      avatarUrl: null,
      type: type,
    );
    return ReactorsPage(
      items: [item('a', 'HAHA'), item('b', 'CARE'), item('c', 'GARRA')],
    );
  }
}

class _NoFan extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

Future<void> _pumpFeed(WidgetTester tester, _ReactionService service) async {
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
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  required ThemeData theme,
  String? current,
  Size size = const Size(400, 900),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: GarraReactionPicker(currentReaction: current)),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _summary => find.byKey(const ValueKey('post_reaction_summary'));
Finder get _burst => find.byKey(const ValueKey('garra_reaction_burst'));
Finder _option(String api) => find.byKey(ValueKey('reaction_option_$api'));
Finder _summaryCount(String text) =>
    find.descendant(of: _summary, matching: find.text(text));

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUp(GarraReactionAnchor.reset);

  group('UX_08A catalog', () {
    testWidgets('selector contains the 8 reactions with Spanish labels', (
      tester,
    ) async {
      await _pumpPicker(tester, theme: AppTheme.lightTheme);
      expect(ReactionType.values, hasLength(8));
      expect(
        ReactionType.values.map((t) => t.apiValue).toList(),
        _labels.keys.toList(),
      );
      for (final entry in _labels.entries) {
        expect(_option(entry.key), findsOneWidget, reason: entry.key);
        expect(
          find.descendant(of: _option(entry.key), matching: find.text(entry.value)),
          findsOneWidget,
          reason: entry.key,
        );
        expect(ReactionType.labelFor(entry.key), entry.value);
      }
      // Compact 4x2 grid, not a tall vertical list.
      expect(find.byKey(const ValueKey('reaction_grid_4')), findsOneWidget);
      final like = tester.getRect(_option('LIKE'));
      final haha = tester.getRect(_option('HAHA'));
      final care = tester.getRect(_option('CARE'));
      expect(haha.top, like.top, reason: 'HAHA on the first row');
      expect(care.top, greaterThan(like.bottom - 1), reason: 'CARE row 2');
      expect(tester.takeException(), isNull);
    });

    testWidgets('HAHA = Me divierte with a laughing emoji', (tester) async {
      await _pumpPicker(tester, theme: AppTheme.lightTheme);
      expect(ReactionType.haha.labelEs, 'Me divierte');
      expect(ReactionType.tryParse('HAHA'), ReactionType.haha);
      expect(
        find.descendant(of: _option('HAHA'), matching: find.text('\u{1F602}')),
        findsOneWidget,
      );
    });

    testWidgets('CARE = Me importa, own vector, not LOVE and not GARRA', (
      tester,
    ) async {
      await _pumpPicker(tester, theme: AppTheme.lightTheme);
      expect(ReactionType.care.labelEs, 'Me importa');
      expect(ReactionType.tryParse('care'), ReactionType.care);

      final care = _option('CARE');
      final glyph = find.descendant(
        of: care,
        matching: find.byType(GarraCareReactionGlyph),
      );
      expect(glyph, findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.descendant(of: glyph, matching: find.byType(CustomPaint)),
      );
      expect(paint.painter, isA<GarraCareReactionPainter>());
      expect(GarraCareReactionPainter.armPaths(), hasLength(2));

      // CARE != LOVE: no plain heart icon inside CARE, and LOVE has no arms.
      expect(
        find.descendant(of: care, matching: find.byIcon(Icons.favorite_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _option('LOVE'),
          matching: find.byType(GarraCareReactionGlyph),
        ),
        findsNothing,
      );
      // CARE != GARRA: no brand mark inside CARE, and GARRA has no hug glyph.
      expect(
        find.descendant(of: care, matching: find.byType(GarraClawReactionGlyph)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _option('GARRA'),
          matching: find.byType(GarraCareReactionGlyph),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _option('GARRA'),
          matching: find.byType(GarraClawReactionGlyph),
        ),
        findsOneWidget,
      );
      // No emoji text for the vector reactions.
      final texts = tester.widgetList<Text>(
        find.descendant(of: care, matching: find.byType(Text)),
      );
      for (final text in texts) {
        expect((text.data ?? '').runes.every((r) => r < 0x2190), isTrue);
      }
    });
  });

  group('UX_08A toggle with HAHA and CARE (posts)', () {
    for (final api in ['HAHA', 'CARE']) {
      testWidgets('select $api from the picker (no burst)', (tester) async {
        final service = _ReactionService(_post());
        await _pumpFeed(tester, service);

        await tester.tap(_summary);
        await tester.pumpAndSettle();
        await tester.tap(_option(api));
        await tester.pump(const Duration(milliseconds: 120));
        expect(_burst, findsNothing);
        await tester.pumpAndSettle();

        expect(service.calls, ['upsert:$api']);
        expect(service.post.myReaction, api);
        expect(service.post.reactionSummary[api], 1);
        expect(find.byKey(const ValueKey('post_my_reaction')), findsOneWidget);
        expect(_summaryCount('1'), findsOneWidget);
      });

      testWidgets('tap on active $api removes it (DELETE, optimistic)', (
        tester,
      ) async {
        final service = _ReactionService(
          _post(myReaction: api, reactionCount: 2, reactionSummary: {api: 2}),
        );
        await _pumpFeed(tester, service);
        expect(_summaryCount('2'), findsOneWidget);

        await tester.tap(_summary);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('post_reaction_picker')), findsNothing);
        expect(service.calls, ['remove']);
        expect(find.byKey(const ValueKey('post_my_reaction')), findsNothing);
        expect(_summaryCount('1'), findsOneWidget);
      });
    }

    testWidgets('long press changes LOVE -> CARE -> HAHA', (tester) async {
      final service = _ReactionService(
        _post(myReaction: 'LOVE', reactionCount: 1, reactionSummary: {
          'LOVE': 1,
        }),
      );
      await _pumpFeed(tester, service);

      await tester.longPress(_summary);
      await tester.pumpAndSettle();
      await tester.tap(_option('CARE'));
      await tester.pumpAndSettle();
      expect(service.post.myReaction, 'CARE');
      expect(service.post.reactionSummary['LOVE'], 0);

      await tester.longPress(_summary);
      await tester.pumpAndSettle();
      await tester.tap(_option('HAHA'));
      await tester.pumpAndSettle();

      expect(service.calls, ['upsert:CARE', 'upsert:HAHA']);
      expect(service.post.myReaction, 'HAHA');
      expect(service.post.reactionSummary['CARE'], 0);
      expect(service.post.reactionSummary['HAHA'], 1);
      expect(_summaryCount('1'), findsOneWidget);
    });

    testWidgets('GARRA is still the only reaction with the burst', (
      tester,
    ) async {
      final service = _ReactionService(_post());
      await _pumpFeed(tester, service);

      for (final type in ReactionType.values) {
        if (type == ReactionType.garra) continue;
        await tester.tap(_summary);
        await tester.pumpAndSettle();
        await tester.tap(_option(type.apiValue));
        await tester.pump(const Duration(milliseconds: 120));
        expect(_burst, findsNothing, reason: type.apiValue);
        await tester.pumpAndSettle();
        await tester.tap(_summary); // remove
        await tester.pumpAndSettle();
      }

      await tester.tap(_summary);
      await tester.pumpAndSettle();
      await tester.tap(_option('GARRA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(_burst, findsOneWidget);
      await tester.pump(garraBurstDuration);
      await tester.pumpAndSettle();
      expect(service.calls.last, 'upsert:GARRA');
    });
  });

  testWidgets('reactors sheet renders HAHA and CARE', (tester) async {
    final semantics = tester.ensureSemantics();
    final service = _ReactionService(_post());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: GarraReactorsList(postId: 'post-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final haha = find.byKey(const ValueKey('reactor_type_a_HAHA'));
    final care = find.byKey(const ValueKey('reactor_type_b_CARE'));
    expect(haha, findsOneWidget);
    expect(care, findsOneWidget);
    expect(find.byKey(const ValueKey('reactor_type_c_GARRA')), findsOneWidget);
    expect(
      find.descendant(of: haha, matching: find.text('\u{1F602}')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: care, matching: find.byType(GarraCareReactionGlyph)),
      findsOneWidget,
    );
    // The reaction label is merged into each reactor row's semantics.
    expect(find.bySemanticsLabel(RegExp('Me divierte')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Me importa')), findsOneWidget);
    semantics.dispose();
  });

  group('UX_08A themes and accessibility', () {
    for (final (name, theme, tokens) in [
      ('Crema', () => AppTheme.lightTheme, GarraSemanticColors.crema),
      ('Noche', () => AppTheme.darkTheme, GarraSemanticColors.noche),
    ]) {
      testWidgets('$name: selector uses theme tokens and readable labels', (
        tester,
      ) async {
        await _pumpPicker(tester, theme: theme(), current: 'CARE');
        for (final entry in _labels.entries) {
          final label = tester.widget<Text>(
            find.descendant(
              of: _option(entry.key),
              matching: find.text(entry.value),
            ),
          );
          expect(label.style?.color, tokens.textPrimary, reason: entry.key);
        }
        final likeCell = tester.widget<Material>(
          find.ancestor(of: _option('LIKE'), matching: find.byType(Material)).first,
        );
        expect(likeCell.color, tokens.surfaceRaised);
        expect(
          _contrast(tokens.textPrimary, tokens.surfaceRaised),
          greaterThanOrEqualTo(4.5),
        );
        // Selected CARE is marked (check) and the hint explains removal.
        expect(
          find.descendant(
            of: _option('CARE'),
            matching: find.byIcon(Icons.check_circle_rounded),
          ),
          findsOneWidget,
        );
        expect(
          find.text('Toca tu reacci\u00f3n otra vez para quitarla'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('text scale 1.3 on a phone: no overflow, >= 48dp targets', (
      tester,
    ) async {
      await _pumpPicker(
        tester,
        theme: AppTheme.lightTheme,
        size: const Size(390, 844),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('reaction_grid_2')), findsOneWidget);
      for (final api in _labels.keys) {
        final size = tester.getSize(_option(api));
        expect(size.height, greaterThanOrEqualTo(48), reason: api);
        expect(size.width, greaterThanOrEqualTo(48), reason: api);
      }
    });

    testWidgets('phone at 1.0: 4x2 grid with >= 48dp targets', (tester) async {
      await _pumpPicker(
        tester,
        theme: AppTheme.darkTheme,
        size: const Size(360, 780),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('reaction_grid_4')), findsOneWidget);
      for (final api in _labels.keys) {
        final size = tester.getSize(_option(api));
        expect(size.height, greaterThanOrEqualTo(48), reason: api);
        expect(size.width, greaterThanOrEqualTo(48), reason: api);
      }
    });

    test('grid columns adapt to width and text scale', () {
      expect(GarraReactionGrid.columnsFor(368, 1), 4);
      expect(GarraReactionGrid.columnsFor(358, 1.3), 2);
      expect(GarraReactionGrid.columnsFor(380, 1.3), 4);
    });
  });
}