import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_assets.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_preloader.dart';
import 'package:garra_digital_app/core/widgets/garra_cached_network_image.dart';
import 'package:garra_digital_app/core/widgets/garra_stickers.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/presentation/football_chat_room_view.dart';
import 'package:garra_digital_app/features/football/presentation/football_chat_sticker_panel.dart';

class _Net extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

class _FanNotifier extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    userId: 'fan-me',
    email: 'me@test.local',
    username: 'me',
    fullName: 'Yo',
    status: 'ACTIVE',
  );
}

Future<void> _settle(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

List<FootballChatSticker> _catalog() => [
  for (final s in GarraSticker.all)
    FootballChatSticker(
      id: s.stableId,
      name: s.label,
      category: s.category,
      glyph: s.glyph,
      assetKey: s.assetKey,
    ),
];

/// Answers GET /stickers/config once (memoized) without real network.
Future<void> _stubConfig(WidgetTester tester, String base) async {
  final stub = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.resolve(
          Response(
            requestOptions: o,
            statusCode: 200,
            data: {
              'data': {'assetBaseUrl': base},
            },
          ),
        ),
      ),
    );
  await tester.runAsync(() => GarraStickerAssets.ensureRemoteConfig(dio: stub));
}

class _Chat extends FootballChatService {
  _Chat() : super(dio: Dio());
  int catalogCalls = 0;

  @override
  Future<FootballChatPage> page(
    FootballChatContext context, {
    DateTime? before,
    String? beforeId,
    int size = 30,
  }) async {
    if (before != null) {
      return const FootballChatPage(items: [], hasMore: false);
    }
    return FootballChatPage(
      items: [
        FootballChatMessage(
          id: 'other-1',
          authorId: 'fan-other',
          authorName: 'Hincha',
          authorUsername: 'h',
          body: 'texto de otro',
          createdAt: DateTime.utc(2026, 10, 10, 20),
        ),
        FootballChatMessage(
          id: 'mine-1',
          authorId: 'fan-me',
          authorName: 'Yo',
          authorUsername: 'me',
          body: 'texto mio',
          createdAt: DateTime.utc(2026, 10, 10, 20, 1),
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<FootballChatStickerCatalog> stickerCatalog() async {
    catalogCalls++;
    return FootballChatStickerCatalog(items: _catalog());
  }

  @override
  Future<List<FootballChatSticker>> stickerFavorites() async => const [];
}

Future<void> _pumpRoom(
  WidgetTester tester,
  _Chat chat, {
  required Brightness brightness,
  bool match = false,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectivityStatusProvider.overrideWith(_Net.new),
        currentFanProvider.overrideWith(_FanNotifier.new),
        footballChatServiceProvider.overrideWithValue(chat),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness, useMaterial3: true),
        home: Scaffold(
          body: MainShellBranchScope(
            activeBranch: 1,
            child: match
                ? const FootballChatRoomView(
                    surface: FootballChatSurface.futbolero,
                    matchId: 1406077,
                  )
                : const FootballChatRoomView(
                    surface: FootballChatSurface.community,
                  ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester, 20);
}

Color? _bubbleColor(WidgetTester tester, String id) {
  final c = tester.widgetList<Container>(
    find.descendant(
      of: find.byKey(ValueKey('chat_msg_bubble_$id')),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.rectangle &&
            (w.decoration! as BoxDecoration).color != null,
      ),
    ),
  );
  return c.isEmpty ? null : (c.first.decoration! as BoxDecoration).color;
}

Future<void> _openPanel(
  WidgetTester tester, {
  required Brightness brightness,
  required List<FootballChatSticker> favorites,
  required Future<List<FootballChatSticker>> Function(String) toggle,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () => showFootballChatStickerPanel(
                context,
                loadCatalog: () async =>
                    FootballChatStickerCatalog(items: _catalog()),
                loadFavorites: () async => favorites,
                toggleFavorite: toggle,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await _settle(tester, 12);
}

void main() {
  setUp(() {
    GarraStickerAssets.debugReset();
    GarraStickerPreloader.debugReset();
  });
  tearDown(() {
    GarraStickerAssets.debugReset();
    GarraStickerPreloader.debugReset();
  });

  group('picker', () {
    for (final b in Brightness.values) {
      testWidgets(
        '${b.name}: no visible labels, semantics/tooltip kept, no overflow at 360dp x1.3',
        (tester) async {
          await _openPanel(
            tester,
            brightness: b,
            favorites: const [],
            toggle: (_) async => const [],
            textScale: 1.3,
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('football_chat_sticker_grid')),
            findsOneWidget,
          );
          final first = GarraSticker.all.firstWhere(
            (s) => s.label.contains(' '),
          );
          // No label text under stickers.
          expect(find.text(first.label), findsNothing);
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  w.properties.label == 'Sticker ${first.label}',
            ),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (w) => w is Tooltip && w.message == first.label,
            ),
            findsOneWidget,
          );
          // Square responsive cells (~72-80 dp): 4 columns at 360 dp.
          final cell = tester.getSize(
            find.byKey(Key('football_chat_sticker_${first.stableId}')),
          );
          expect(cell.width, inInclusiveRange(64, 80));
          expect((cell.width - cell.height).abs(), lessThan(0.5));
        },
      );
    }

    testWidgets(
      'favorites: star toggles, favorites tab lists them, tap on cell picks (star does not steal)',
      (tester) async {
        final first = _catalog().first;
        var favs = <FootballChatSticker>[];
        await _openPanel(
          tester,
          brightness: Brightness.dark,
          favorites: favs,
          toggle: (id) async {
            favs = [first];
            return favs;
          },
        );
        await tester.tap(
          find.byKey(Key('football_chat_sticker_fav_${first.id}')),
        );
        await _settle(tester, 4);
        expect(
          find.descendant(
            of: find.byKey(Key('football_chat_sticker_fav_${first.id}')),
            matching: find.byIcon(Icons.star),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Favoritos'));
        await _settle(tester, 4);
        expect(
          find.byKey(Key('football_chat_sticker_${first.id}')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(Key('football_chat_sticker_${first.id}')));
        await _settle(tester, 8);
        expect(
          find.byKey(const Key('football_chat_sticker_grid')),
          findsNothing,
        );
      },
    );
  });

  group('image loading', () {
    testWidgets(
      'loading placeholder is a neutral box; glyph only for error / no CDN',
      (tester) async {
        GarraStickerAssets.debugSetBaseUrl('https://cdn.example.invalid');
        await tester.pumpWidget(
          const MaterialApp(
            home: GarraStickerImage(
              id: 'garra_gol_carajo',
              assetKey: 'garra/stickers/v1/garra_gol_carajo.webp',
              glyph: '*',
              size: 56,
              thumb: true,
            ),
          ),
        );
        final img = tester.widget<GarraCachedNetworkImage>(
          find.byType(GarraCachedNetworkImage),
        );
        expect(
          (img.placeholder!.key! as ValueKey).value,
          'garra-sticker-loading-garra_gol_carajo',
        );
        expect(img.placeholder, isA<SizedBox>());
        expect((img.placeholder! as SizedBox).child, isNull);
        expect(
          (img.errorWidget!.key! as ValueKey).value,
          'garra-sticker-fallback-garra_gol_carajo',
        );
        GarraStickerAssets.debugSetBaseUrl(null);
        await tester.pumpWidget(
          const MaterialApp(
            home: GarraStickerImage(
              id: 'garra_gol_carajo',
              assetKey: 'garra/stickers/v1/garra_gol_carajo.webp',
              glyph: '*',
              size: 56,
            ),
          ),
        );
        expect(find.text('*'), findsOneWidget);
      },
    );

    testWidgets(
      'preloader: thumbs only, max 16 per call, sequential, deduplicated',
      (tester) async {
        GarraStickerAssets.debugSetBaseUrl('https://cdn.example.invalid');
        final fetched = <String>[];
        var inFlight = 0;
        var maxInFlight = 0;
        GarraStickerPreloader.debugFetch = (url, _) async {
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          fetched.add(url);
          await Future<void>.delayed(const Duration(milliseconds: 1));
          inFlight--;
        };
        await tester.pumpWidget(const SizedBox());
        final ctx = tester.element(find.byType(SizedBox));
        final keys = [
          for (final s in GarraSticker.all) s.assetKey,
          for (final s in GarraSticker.all) s.assetKey,
        ];
        await tester.runAsync(
          () => GarraStickerPreloader.warmThumbs(ctx, keys),
        );
        expect(fetched, hasLength(16));
        expect(fetched.toSet(), hasLength(16));
        expect(
          fetched.every((u) => u.contains('/garra/stickers/v1/thumbs/')),
          isTrue,
        );
        expect(maxInFlight, 1);
        await tester.runAsync(
          () => GarraStickerPreloader.warmThumbs(ctx, keys),
        );
        await tester.runAsync(
          () => GarraStickerPreloader.warmThumbs(ctx, keys),
        );
        final withAsset = GarraSticker.all
            .where((s) => (s.assetKey ?? '').isNotEmpty)
            .length;
        expect(
          fetched.toSet(),
          hasLength(fetched.length),
          reason: 'no URL requested twice',
        );
        expect(fetched.length, withAsset);
      },
    );

    testWidgets(
      'room warms config + catalog once, rebuilds stickers when CDN arrives, precaches thumbs',
      (tester) async {
        await _stubConfig(tester, 'https://cdn.example.invalid');
        final fetched = <String>[];
        GarraStickerPreloader.debugFetch = (url, _) async => fetched.add(url);
        final chat = _Chat();
        await _pumpRoom(tester, chat, brightness: Brightness.dark);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await _settle(tester, 4);
        expect(chat.catalogCalls, 1);
        expect(fetched, isNotEmpty);
        expect(
          fetched.length,
          lessThanOrEqualTo(GarraStickerPreloader.maxPerCall),
        );
        expect(fetched.every((u) => u.contains('/thumbs/')), isTrue);
        // Opening the panel reuses the same catalog future (no second fetch).
        await tester.tap(
          find.byKey(const ValueKey('football_chat_sticker_btn')),
        );
        await _settle(tester, 10);
        expect(
          find.byKey(const Key('football_chat_sticker_grid')),
          findsOneWidget,
        );
        expect(chat.catalogCalls, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('light / dark', () {
    for (final match in [false, true]) {
      for (final b in Brightness.values) {
        testWidgets(
          '${match ? 'MATCH' : 'GENERAL'} ${b.name}: bubbles follow theme',
          (tester) async {
            await _stubConfig(tester, '');
            final chat = _Chat();
            await _pumpRoom(tester, chat, brightness: b, match: match);
            expect(tester.takeException(), isNull);
            expect(find.text('texto de otro'), findsOneWidget);
            expect(find.text('texto mio'), findsOneWidget);
            if (!match) {
              final other = _bubbleColor(tester, 'other-1');
              final mine = _bubbleColor(tester, 'mine-1');
              if (b == Brightness.light) {
                expect(other, const Color(0xFFFCF6EA)); // PRODUCT-07D: warm cream, no pure white
                expect(mine, const Color(0xFF7C0211));
              } else {
                expect(other, const Color(0xE6221A1C));
                expect(mine, const Color(0xFF6E2A35));
              }
              final otherText = tester.widget<Text>(find.text('texto de otro'));
              final expected = b == Brightness.light
                  ? const Color(0xFF2A1A1C)
                  : const Color(0xFFF3E9D2);
              expect(otherText.style?.color, expected);
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          },
        );
      }
    }
  });
}
