import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/session_events.dart';
import 'package:garra_digital_app/core/network/private_media_loader.dart';
import 'package:garra_digital_app/core/widgets/garra_cached_network_image.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_media_grid.dart';

const _api = 'https://api.garra.test/api/v1';

// 1x1 transparent PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  int status;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) async {
    seen.add(options);
    if (status != 200) return ResponseBody.fromString('{}', status);
    return ResponseBody.fromBytes(_png, 200, headers: {
      Headers.contentTypeHeader: ['image/png'],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Mirrors DioClient: the interceptor adds the bearer to every request, so the
/// loader itself must never send a foreign URL through this client.
(Dio, _Adapter) _client(int status) {
  final adapter = _Adapter(status);
  final dio = Dio(BaseOptions(baseUrl: _api))..httpClientAdapter = adapter;
  dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    o.headers['Authorization'] = 'Bearer test-token';
    h.next(o);
  }));
  return (dio, adapter);
}

ChatMediaItem _img(String url) =>
    ChatMediaItem(assetId: 'a1', url: url, contentType: 'image/jpeg', kind: 'IMAGE');

void main() {
  group('isPrivateApiMediaUrl', () {
    test('relative API paths are private, protocol-relative are not', () {
      expect(isPrivateApiMediaUrl('/chat/messages/m/media/a', apiBaseUrl: _api), isTrue);
      expect(isPrivateApiMediaUrl('/clans/s/chat/messages/m/media/a', apiBaseUrl: _api), isTrue);
      expect(isPrivateApiMediaUrl('//evil.test/chat/x', apiBaseUrl: _api), isFalse);
    });

    test('absolute URL needs same scheme, host, port and base path', () {
      expect(isPrivateApiMediaUrl('https://api.garra.test/api/v1/chat/m', apiBaseUrl: _api), isTrue);
      expect(isPrivateApiMediaUrl('http://api.garra.test/api/v1/chat/m', apiBaseUrl: _api), isFalse);
      expect(isPrivateApiMediaUrl('https://api.garra.test:8443/api/v1/chat/m', apiBaseUrl: _api), isFalse);
      expect(isPrivateApiMediaUrl('https://api.garra.test.evil.test/api/v1/x', apiBaseUrl: _api), isFalse);
      expect(isPrivateApiMediaUrl('https://user@api.garra.test/api/v1/x', apiBaseUrl: _api), isFalse);
      expect(isPrivateApiMediaUrl('https://api.garra.test/other', apiBaseUrl: _api), isFalse);
      expect(isPrivateApiMediaUrl('https://media.garradigital.pe/community/a.jpg', apiBaseUrl: _api), isFalse);
    });
  });

  group('PrivateMediaLoader', () {
    test('private path is fetched once with the API client and cached without token in key', () async {
      final (dio, adapter) = _client(200);
      final loader = PrivateMediaLoader(client: dio, apiBaseUrl: _api);
      final bytes = await loader.load('/chat/messages/m/media/a');
      await loader.load('/chat/messages/m/media/a');
      expect(bytes, isNotEmpty);
      expect(adapter.seen, hasLength(1));
      expect(adapter.seen.single.uri.host, 'api.garra.test');
      expect(adapter.seen.single.uri.toString(), isNot(contains('token')));
      expect(loader.cached('/chat/messages/m/media/a'), isNotNull);
      await loader.dispose();
    });

    test('foreign host never reaches the authenticated client', () async {
      final (dio, adapter) = _client(200);
      final loader = PrivateMediaLoader(client: dio, apiBaseUrl: _api);
      await expectLater(loader.load('https://pub-x.r2.dev/chat/u/a.jpg'), throwsA(isA<PrivateMediaException>()));
      await expectLater(loader.load('//evil.test/a.jpg'), throwsA(isA<PrivateMediaException>()));
      expect(adapter.seen, isEmpty);
      await loader.dispose();
    });

    test('401 and 404 map to exceptions; 404 is "unavailable"', () async {
      final (dio, adapter) = _client(401);
      final loader = PrivateMediaLoader(client: dio, apiBaseUrl: _api);
      await expectLater(loader.load('/chat/messages/m/media/a'),
          throwsA(isA<PrivateMediaException>().having((e) => e.unavailable, 'unavailable', isFalse)));
      adapter.status = 404;
      await expectLater(loader.load('/chat/messages/m/media/b'),
          throwsA(isA<PrivateMediaException>().having((e) => e.unavailable, 'unavailable', isTrue)));
      await loader.dispose();
    });

    test('session end clears the private cache', () async {
      final (dio, _) = _client(200);
      final loader = PrivateMediaLoader(client: dio, apiBaseUrl: _api);
      await loader.load('/chat/messages/m/media/a');
      SessionEvents.emit(SessionEventKind.ended);
      await Future<void>.delayed(Duration.zero);
      expect(loader.cached('/chat/messages/m/media/a'), isNull);
      await loader.dispose();
    });
  });

  group('widgets', () {
    late PrivateMediaLoader previous;
    setUp(() => previous = PrivateMediaLoader.instance);
    tearDown(() => PrivateMediaLoader.instance = previous);

    testWidgets('public image keeps CachedNetworkImage and never uses the token client', (tester) async {
      final (dio, adapter) = _client(200);
      PrivateMediaLoader.instance = PrivateMediaLoader(client: dio, apiBaseUrl: _api);
      await tester.pumpWidget(const MaterialApp(
        home: GarraCachedNetworkImage(imageUrl: 'https://media.garradigital.pe/community/a.jpg'),
      ));
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(find.byKey(const ValueKey('garra_private_image')), findsNothing);
      expect(adapter.seen, isEmpty);
    });

    testWidgets('chat thumbnail and fullscreen load the private image via API once', (tester) async {
      final (dio, adapter) = _client(200);
      PrivateMediaLoader.instance = PrivateMediaLoader(client: dio, apiBaseUrl: _api);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ChatMediaGrid(media: [_img('/chat/messages/m/media/a')])),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.byKey(const ValueKey('garra_private_image')), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);

      await tester.tap(find.byKey(const Key('chat-media-image-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('garra_private_image')), findsNWidgets(2));
      expect(adapter.seen, hasLength(1));
      expect(adapter.seen.single.headers['Authorization'], 'Bearer test-token');
      expect(adapter.seen.single.uri.host, 'api.garra.test');
    });

    testWidgets('404 (third party / deleted) shows unavailable state', (tester) async {
      final (dio, _) = _client(404);
      PrivateMediaLoader.instance = PrivateMediaLoader(client: dio, apiBaseUrl: _api);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ChatMediaGrid(media: [_img('/chat/messages/m/media/gone')])),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.byKey(const ValueKey('garra_private_image_unavailable')), findsOneWidget);
    });

    testWidgets('401 expired session shows error state (refresh/expiry handled by DioClient)', (tester) async {
      final (dio, _) = _client(401);
      PrivateMediaLoader.instance = PrivateMediaLoader(client: dio, apiBaseUrl: _api);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ChatMediaGrid(media: [_img('/chat/messages/m/media/x')])),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.byKey(const ValueKey('garra_private_image_error')), findsOneWidget);
    });
  });
}