import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_assets.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_availability.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_prefs.dart';
import 'package:garra_digital_app/core/widgets/garra_stickers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GarraStickerAssets.debugSetBaseUrl(null);
  });

  group('catalog', () {
    test('legacy 6 kept + 28 v1, unique ids and tokens', () {
      expect(GarraSticker.catalog, hasLength(6));
      expect(GarraSticker.v1Catalog, hasLength(28));
      expect(GarraSticker.all, hasLength(34));
      expect(GarraSticker.all.map((s) => s.stableId).toSet(), hasLength(34));
      expect(GarraSticker.all.map((s) => s.token).toSet(), hasLength(34));
      for (final s in GarraSticker.v1Catalog) {
        expect(s.token, ':${s.id}:');
        expect(s.assetKey, 'garra/stickers/v1/${s.id}.webp');
        expect(GarraSticker.categories.containsKey(s.category), isTrue);
        expect(s.glyph, isNotEmpty);
      }
    });

    test('legacy and v1 tokens resolve from text content', () {
      expect(GarraSticker.fromContent(':garra_gol:')?.label, 'Gol');
      expect(GarraSticker.fromContent(' :garra_gol_carajo: ')?.id, 'garra_gol_carajo');
      expect(GarraSticker.fromContent(':garra_gol_carajo: hola'), isNull);
      expect(GarraSticker.fromContent('hola'), isNull);
      expect(GarraSticker.byId('garra_fuego')?.token, ':garra_fuego:');
    });

    test('phrases keep accents', () {
      expect(GarraSticker.byId('garra_dale_alegria_a_mi_corazon')!.label, contains('CORAZÓN'));
    });
  });

  group('urls', () {
    test('no base url => null (glyph fallback)', () {
      expect(GarraStickerAssets.fullUrl('garra/stickers/v1/garra_gol_carajo.webp'), isNull);
    });
    test('builds 512 and thumb urls, trims slash', () {
      const k = 'garra/stickers/v1/garra_gol_carajo.webp';
      expect(GarraStickerAssets.fullUrl(k, base: 'https://cdn.example.invalid/'),
          'https://cdn.example.invalid/garra/stickers/v1/garra_gol_carajo.webp');
      expect(GarraStickerAssets.thumbUrl(k, base: 'https://cdn.example.invalid'),
          'https://cdn.example.invalid/garra/stickers/v1/thumbs/garra_gol_carajo.webp');
      expect(GarraStickerAssets.fullUrl(null, base: 'https://x.invalid'), isNull);
    });
    test('remote config overrides only when non-empty', () {
      GarraStickerAssets.applyRemoteConfig({'assetBaseUrl': null});
      expect(GarraStickerAssets.baseUrl, isNull);
      GarraStickerAssets.applyRemoteConfig({'assetBaseUrl': 'https://cdn.example.invalid/'});
      expect(GarraStickerAssets.baseUrl, 'https://cdn.example.invalid');
    });
  });

  group('prefs', () {
    test('favorites toggle and recents dedupe/limit', () async {
      final p = GarraStickerPrefs(maxRecents: 2);
      expect(await p.toggleFavorite('garra_gol_carajo'), ['garra_gol_carajo']);
      expect(await p.toggleFavorite('garra_gol_carajo'), isEmpty);
      await p.pushRecent('a');
      await p.pushRecent('b');
      expect(await p.pushRecent('a'), ['a', 'b']);
      expect(await p.pushRecent('c'), ['c', 'a']);
    });
  });

  group('renderer', () {
    testWidgets('fallback glyph when assets unpublished', (t) async {
      final s = GarraSticker.byId('garra_gol_carajo')!;
      await t.pumpWidget(_host(GarraStickerView(sticker: s)));
      expect(find.byKey(const Key('garra-sticker-fallback-garra_gol_carajo')), findsOneWidget);
      expect(find.text('⚽'), findsOneWidget);
    });
    testWidgets('network image path when base url configured', (t) async {
      GarraStickerAssets.debugSetBaseUrl('https://cdn.example.invalid');
      final s = GarraSticker.byId('garra_jajaja_xd')!;
      await t.pumpWidget(_host(GarraStickerView(sticker: s, compact: true)));
      expect(find.byKey(const Key('garra-sticker-image-garra_jajaja_xd')), findsOneWidget);
    });
    testWidgets('legacy sticker still renders glyph + label', (t) async {
      await t.pumpWidget(_host(GarraStickerView(sticker: GarraSticker.fromContent(':garra_fuego:')!)));
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('Fuego'), findsOneWidget);
    });
  });

  group('picker + insert', () {
    testWidgets('picker lists all, filters by category, inserts token and records recent', (t) async {
      // Simulates post-activation: server reports the V1 ids as active.
      GarraStickerAvailability.debugReset();
      await GarraStickerAvailability.ensureLoaded(
          fetch: () async => {for (final s in GarraSticker.v1Catalog) s.stableId});
      final controller = TextEditingController();
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => insertGarraSticker(ctx, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('garra-sticker-grid')), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('garra-sticker-tab-humor_reaccion')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('garra-sticker-tab-humor_reaccion')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sticker-:garra_jajaja_xd:')), findsOneWidget);
      expect(find.byKey(const Key('sticker-:garra_gol:')), findsNothing);
      await t.tap(find.byKey(const Key('sticker-:garra_jajaja_xd:')));
      await t.pumpAndSettle();
      expect(controller.text, ':garra_jajaja_xd:');
      expect(await GarraStickerPrefs().recents(), ['garra_jajaja_xd']);
    });
  });
}
