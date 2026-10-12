import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_assets.dart';
import 'package:garra_digital_app/core/widgets/garra_cached_network_image.dart';
import 'package:garra_digital_app/core/widgets/garra_stickers.dart';

class _CountingAdapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': {'assetBaseUrl': 'https://cdn.example.invalid/', 'packVersion': 'v1'}}),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() => GarraStickerAssets.debugReset());

  group('contract: token -> sticker only when whole body is a known token', () {
    test('exact (trimmed) known token is a sticker', () {
      expect(GarraSticker.fromContent(':garra_gol_carajo:')?.id, 'garra_gol_carajo');
      expect(GarraSticker.fromContent('\n :garra_te_amo_crema: \t')?.id, 'garra_te_amo_crema');
      expect(GarraSticker.fromContent(':garra_gol:')?.label, 'Gol');
    });
    test('inline tokens, unknown tokens and normal text stay text', () {
      expect(GarraSticker.fromContent('vamos :garra_gol_carajo:'), isNull);
      expect(GarraSticker.fromContent(':garra_gol_carajo: :garra_gol:'), isNull);
      expect(GarraSticker.fromContent(':garra_no_existe:'), isNull);
      expect(GarraSticker.fromContent(':GARRA_GOL_CARAJO:'), isNull);
      expect(GarraSticker.fromContent('garra_gol_carajo'), isNull);
      expect(GarraSticker.fromContent(''), isNull);
    });
  });

  group('catalog == manifest == files', () {
    final manifest = File('design_assets/garra_stickers/v1/manifest/stickers_v1_catalog.json');
    test('ids, categories, phrases and asset keys match stickers_v1_catalog.json; files exist', () {
      if (!manifest.existsSync()) {
        markTestSkipped('design_assets not present');
        return;
      }
      final json = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
      final items = (json['stickers'] as List).cast<Map<String, dynamic>>();
      expect(items, hasLength(28));
      expect(GarraSticker.v1Catalog.map((s) => s.id).toList(), items.map((e) => e['id']).toList());
      for (final e in items) {
        final s = GarraSticker.byId(e['id'] as String)!;
        expect(s.assetKey, e['assetKey']);
        expect(s.label, e['phrase']);
        expect(s.category, e['category']);
        expect(File('design_assets/garra_stickers/v1/${e['relativePath']}').existsSync(), isTrue);
        expect(File('design_assets/garra_stickers/v1/optimized/thumbs_128/${e['id']}.webp').existsSync(), isTrue);
      }
    });
  });

  group('url building (r2_publication_plan.md)', () {
    const k = 'garra/stickers/v1/garra_gol_carajo.webp';
    test('512 and thumbs keys', () {
      expect(GarraStickerAssets.fullUrl(k, base: 'https://cdn.example.invalid'),
          'https://cdn.example.invalid/garra/stickers/v1/garra_gol_carajo.webp');
      expect(GarraStickerAssets.thumbUrl(k, base: 'https://cdn.example.invalid'),
          'https://cdn.example.invalid/garra/stickers/v1/thumbs/garra_gol_carajo.webp');
    });
    test('rejects arbitrary keys and invalid bases', () {
      for (final bad in ['../secret.webp', 'garra/stickers/v1/../x.webp', 'https://evil.invalid/x.webp',
        'garra/stickers/v1/a b.webp', 'garra/stickers/v1/x.png', '/garra/stickers/v1/x.webp']) {
        expect(GarraStickerAssets.fullUrl(bad, base: 'https://cdn.example.invalid'), isNull, reason: bad);
      }
      expect(GarraStickerAssets.fullUrl(k, base: 'ftp://cdn.example.invalid'), isNull);
      expect(GarraStickerAssets.fullUrl(k, base: 'javascript:alert(1)'), isNull);
      expect(GarraStickerAssets.fullUrl(k, base: 'https://cdn.example.invalid/x?y=1'), isNull);
      expect(GarraStickerAssets.fullUrl(k, base: ''), isNull);
    });
    test('remote config fetched once and cached', () async {
      final adapter = _CountingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid/api/v1'))..httpClientAdapter = adapter;
      await Future.wait([
        GarraStickerAssets.ensureRemoteConfig(dio: dio),
        GarraStickerAssets.ensureRemoteConfig(dio: dio),
      ]);
      await GarraStickerAssets.ensureRemoteConfig(dio: dio);
      expect(adapter.calls, 1);
      expect(GarraStickerAssets.baseUrl, 'https://cdn.example.invalid');
    });
  });

  group('renderer fallbacks', () {
    testWidgets('no CDN => glyph, no network widget', (t) async {
      await t.pumpWidget(const MaterialApp(home: GarraStickerImage(id: 'garra_jajaja_xd',
          assetKey: 'garra/stickers/v1/garra_jajaja_xd.webp', glyph: '😂')));
      expect(find.byType(GarraCachedNetworkImage), findsNothing);
      expect(find.text('😂'), findsOneWidget);
    });
    testWidgets('CDN set => cached image with glyph as placeholder AND errorWidget (404/timeout/invalid)', (t) async {
      GarraStickerAssets.debugSetBaseUrl('https://cdn.example.invalid');
      await t.pumpWidget(const MaterialApp(home: GarraStickerImage(id: 'garra_jajaja_xd',
          assetKey: 'garra/stickers/v1/garra_jajaja_xd.webp', glyph: '😂', thumb: true, size: 56)));
      final img = t.widget<GarraCachedNetworkImage>(find.byType(GarraCachedNetworkImage));
      expect(img.imageUrl, 'https://cdn.example.invalid/garra/stickers/v1/thumbs/garra_jajaja_xd.webp');
      expect((img.errorWidget!.key as ValueKey).value, 'garra-sticker-fallback-garra_jajaja_xd');
      expect((img.placeholder!.key as ValueKey).value, 'garra-sticker-fallback-garra_jajaja_xd');
      expect(img.memCacheWidth, lessThanOrEqualTo(128));
    });
    testWidgets('unknown server sticker (null assetKey) renders glyph', (t) async {
      GarraStickerAssets.debugSetBaseUrl('https://cdn.example.invalid');
      await t.pumpWidget(const MaterialApp(home: GarraStickerImage(id: 'garra_futuro', assetKey: null, glyph: '⭐')));
      expect(find.text('⭐'), findsOneWidget);
    });
  });
}
