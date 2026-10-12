import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_assets.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_availability.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_prefs.dart';
import 'package:garra_digital_app/core/widgets/garra_stickers.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/presentation/football_chat_sticker_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyServer = {
  'garra_aliento', 'garra_gol', 'garra_fuerza', 'garra_corazon', 'garra_fuego', 'garra_celebra',
};

Widget _picker() => const MaterialApp(home: Scaffold(body: GarraStickerPickerSheet()));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GarraStickerAssets.debugSetBaseUrl(null);
    GarraStickerAvailability.debugReset();
  });

  group('availability', () {
    test('server returns only legacy (28 inactive) -> 28 not offered', () async {
      final ids = await GarraStickerAvailability.ensureLoaded(fetch: () async => _legacyServer);
      expect(ids, hasLength(6));
      expect(GarraStickerAvailability.offered(GarraSticker.v1Catalog), isEmpty);
      expect(GarraStickerAvailability.offered(GarraSticker.catalog), hasLength(6));
    });

    test('fetch failure -> legacy 6 only', () async {
      await GarraStickerAvailability.ensureLoaded(fetch: () async => throw Exception('net'));
      expect(GarraStickerAvailability.offered(GarraSticker.all).map((s) => s.stableId).toSet(),
          GarraStickerAvailability.legacyIds);
    });

    test('server activates some V1 -> only those offered; legacy always', () async {
      await GarraStickerAvailability.ensureLoaded(
          fetch: () async => {'garra_gol_carajo', 'unknown_x'});
      final offered = GarraStickerAvailability.offered(GarraSticker.all).map((s) => s.stableId).toSet();
      expect(offered, {...GarraStickerAvailability.legacyIds, 'garra_gol_carajo'});
    });

    test('fetched once (no polling)', () async {
      var calls = 0;
      Future<Set<String>> f() async {
        calls++;
        return _legacyServer;
      }
      await GarraStickerAvailability.ensureLoaded(fetch: f);
      await GarraStickerAvailability.ensureLoaded(fetch: f);
      expect(calls, 1);
    });

    test('historic tokens of inactive stickers still render-resolve', () {
      expect(GarraSticker.fromContent(':garra_gol_carajo:')?.id, 'garra_gol_carajo');
      expect(GarraSticker.byId('garra_jajaja_xd'), isNotNull);
      expect(GarraSticker.all, hasLength(34));
    });
  });

  group('community/private/comments picker', () {
    testWidgets('inactive V1 hidden, legacy shown', (t) async {
      await GarraStickerAvailability.ensureLoaded(fetch: () async => _legacyServer);
      await t.pumpWidget(_picker());
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('garra-sticker-tab-all')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sticker-:garra_gol:')), findsOneWidget);
      expect(find.byKey(const Key('sticker-:garra_gol_carajo:')), findsNothing);
    });

    testWidgets('fetch failure -> picker shows legacy only', (t) async {
      await GarraStickerAvailability.ensureLoaded(fetch: () async => throw Exception('500'));
      await t.pumpWidget(_picker());
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('garra-sticker-tab-all')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sticker-:garra_fuego:')), findsOneWidget);
      expect(find.byKey(const Key('sticker-:garra_jajaja_xd:')), findsNothing);
    });

    testWidgets('stored favorite of inactive sticker is hidden but preserved', (t) async {
      final prefs = GarraStickerPrefs();
      await prefs.toggleFavorite('garra_gol_carajo');
      await prefs.toggleFavorite('garra_gol');
      await GarraStickerAvailability.ensureLoaded(fetch: () async => _legacyServer);
      await t.pumpWidget(_picker());
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('garra-sticker-tab-favorites')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sticker-:garra_gol:')), findsOneWidget);
      expect(find.byKey(const Key('sticker-:garra_gol_carajo:')), findsNothing);
      expect(await prefs.favorites(), containsAll(['garra_gol_carajo', 'garra_gol']));
    });
  });

  group('football chat panel', () {
    testWidgets('offers only server-active catalog (legacy)', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showFootballChatStickerPanel(
                ctx,
                loadCatalog: () async => FootballChatStickerCatalog(items: [
                  for (final id in _legacyServer)
                    FootballChatSticker(id: id, name: id, category: 'animo', glyph: '*'),
                ]),
                loadFavorites: () async => const [],
                toggleFavorite: (_) async => const [],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('football_chat_sticker_garra_gol')), findsOneWidget);
      expect(find.byKey(const Key('football_chat_sticker_garra_gol_carajo')), findsNothing);
    });
  });
}