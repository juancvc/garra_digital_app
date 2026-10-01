import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/widgets/garra_stickers.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_audio_composer.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_audio_player.dart';
import 'package:garra_digital_app/core/widgets/garra_avatar.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';

class _Recorder implements ChatAudioRecorder {
  bool permission = true;
  bool started = false;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start(String path) async {
    started = true;
  }

  @override
  Future<String?> stop() async {
    started = false;
    return 'note.m4a';
  }

  @override
  Future<void> dispose() async {}
}

class _Media extends MediaUploadService {
  int calls = 0;
  bool fail = false;
  @override
  Future<MediaDraft> uploadChatAudio({
    required String path,
    void Function(MediaDraft draft)? onUpdate,
    bool Function()? canStartRemote,
    cancelToken,
  }) async {
    calls++;
    return MediaDraft(
      localId: 'note',
      localPath: path,
      assetId: fail ? null : 'asset-1',
      state: fail ? MediaUploadState.failed : MediaUploadState.ready,
    );
  }
}

class _Engine implements ChatAudioEngine {
  final position = StreamController<Duration>.broadcast();
  final duration = StreamController<Duration>.broadcast();
  final complete = StreamController<void>.broadcast();
  int plays = 0;
  int pauses = 0;
  @override
  Stream<Duration> get positions => position.stream;
  @override
  Stream<Duration> get durations => duration.stream;
  @override
  Stream<void> get completions => complete.stream;
  @override
  Future<void> play(String path) async {
    expect(path, 'audio.m4a');
    plays++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> dispose() async {
    await position.close();
    await duration.close();
    await complete.close();
  }
}

void main() {
  testWidgets('audio player fetches relative path then plays with progress', (
    tester,
  ) async {
    final calls = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options.path);
            handler.resolve(
              Response<List<int>>(requestOptions: options, data: [1, 2, 3]),
            );
          },
        ),
      );
    final engine = _Engine();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAudioPlayer(
            url: '/chat/messages/m1/audio/a1',
            client: dio,
            engine: engine,
            saveBytes: (_) async => 'audio.m4a',
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('chat-audio-play')));
    await tester.pumpAndSettle();
    expect(calls, ['/chat/messages/m1/audio/a1']);
    expect(engine.plays, 1);
    engine.duration.add(const Duration(seconds: 10));
    engine.position.add(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('5s'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-audio-play')));
    await tester.pump();
    expect(engine.pauses, 1);
  });

  test('audio signs, PUTs and confirms without image compression', () async {
    final dir = await Directory.systemTemp.createTemp('garra_audio_test');
    final file = await File('${dir.path}/voice.m4a').writeAsBytes([1, 2, 3]);
    final calls = <String>[];
    final api = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/media/uploads') {
              calls.add('sign');
              expect(options.data['purpose'], 'CHAT_AUDIO');
              expect(options.data['contentType'], 'audio/mp4');
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'data': {
                      'assetId': 'audio-1',
                      'uploadUrl': 'https://storage.example/voice',
                      'method': 'PUT',
                      'requiredHeaders': {'Content-Type': 'audio/mp4'},
                    },
                  },
                ),
              );
            } else {
              calls.add('confirm');
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'data': {'mediaUrl': null},
                  },
                ),
              );
            }
          },
        ),
      );
    final storage = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add('put');
            expect(options.contentType, 'audio/mp4');
            expect(options.sendTimeout, MediaUploadService.storageSendTimeout);
            handler.resolve(Response(requestOptions: options));
          },
        ),
      );
    final stages = <MediaUploadState>[];
    final result = await MediaUploadService(dio: api, binaryClient: storage)
        .uploadChatAudio(
          path: file.path,
          onUpdate: (draft) => stages.add(draft.state),
        );
    expect(result.isReady, isTrue);
    expect(calls, ['sign', 'put', 'confirm']);
    expect(
      stages,
      containsAllInOrder([
        MediaUploadState.signing,
        MediaUploadState.uploading,
        MediaUploadState.confirming,
        MediaUploadState.ready,
      ]),
    );
    await dir.delete(recursive: true);
  });

  testWidgets('post author avatar uses the same URL returned by the API', (
    tester,
  ) async {
    final post = WallPostModel.fromJson({
      'id': 'post-1',
      'username': 'hincha',
      'fullName': 'Hincha',
      'content': 'Vamos',
      'createdAt': '2026-10-01T12:00:00Z',
      'contextType': 'GLOBAL',
      'avatarUrl': 'https://cdn.example/avatar.jpg',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GarraSocialPostCard(post: post, onOpen: () {}),
        ),
      ),
    );
    expect(
      tester.widget<GarraAvatar>(find.byType(GarraAvatar).first).avatarUrl,
      'https://cdn.example/avatar.jpg',
    );
  });

  test('local sticker catalog recognizes only its stable tokens', () {
    expect(GarraSticker.catalog, hasLength(6));
    expect(GarraSticker.fromContent(':garra_gol:')?.label, 'Gol');
    expect(GarraSticker.fromContent('hola'), isNull);
  });

  testWidgets(
    'record, cancel, and retry a failed upload without losing draft',
    (tester) async {
      final recorder = _Recorder();
      final media = _Media();
      var sends = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatAudioComposer(
              recorder: recorder,
              media: media,
              recordingPath: () async => 'note.m4a',
              onSend: (_, _) async {
                sends++;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('chat-audio-record')));
      await tester.pump();
      expect(recorder.started, isTrue);
      await tester.tap(find.byKey(const Key('chat-audio-cancel')));
      await tester.pump();
      expect(find.byKey(const Key('chat-audio-send')), findsNothing);

      await tester.tap(find.byKey(const Key('chat-audio-record')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-audio-stop')));
      await tester.pump();
      media.fail = true;
      await tester.tap(find.byKey(const Key('chat-audio-send')));
      await tester.pump();
      expect(sends, 0);
      expect(find.byKey(const Key('chat-audio-send')), findsOneWidget);
      expect(find.textContaining('Conservamos tu audio'), findsOneWidget);

      media.fail = false;
      await tester.tap(find.byKey(const Key('chat-audio-send')));
      await tester.pump();
      expect(media.calls, 2);
      expect(sends, 1);
      expect(find.byKey(const Key('chat-audio-record')), findsOneWidget);
    },
  );
}
