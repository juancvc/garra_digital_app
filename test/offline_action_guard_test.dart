import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/network/offline_action_guard.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_conversation_page.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/post_location.dart';
import 'package:garra_digital_app/features/community/data/create_wall_post_request.dart';
import 'package:garra_digital_app/features/community/presentation/create_community_post_page.dart';
import 'package:garra_digital_app/features/polla/data/matchday_poll_models.dart';
import 'package:garra_digital_app/features/polla/data/polla_service.dart';
import 'package:garra_digital_app/features/polla/presentation/matchday_polls_page.dart';
import 'package:garra_digital_app/features/polla/presentation/providers/polla_provider.dart';
import 'package:garra_digital_app/features/passport/data/passport_models.dart';
import 'package:garra_digital_app/features/passport/presentation/profile_edit_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/providers/passport_provider.dart';
import 'package:garra_digital_app/features/clans/presentation/create_community_page.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/reaction_result.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:image_picker/image_picker.dart';

class _Source implements ConnectivitySource {
  _Source(this.result);
  final ConnectivityResult result;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );
  @override
  Future<List<ConnectivityResult>> check() async => [result];
  @override
  Stream<List<ConnectivityResult>> get changes => _controller.stream;
  void emit(ConnectivityResult value) => _controller.add([value]);
  Future<void> dispose() => _controller.close();
}

class _Community extends CommunityService {
  _Community() : super(dio: Dio());
  int calls = 0;
  @override
  Future<WallActionResult> createGlobalPost({
    required String content,
    String? mediaAssetId,
    List<String>? mediaAssetIds,
    String? locationTag,
    PostLocation? postLocation,
  }) async {
    calls++;
    return WallActionResult.success(message: 'ok');
  }

  @override
  Future<WallActionResult> createPost(CreateWallPostRequest request) async {
    calls++;
    return WallActionResult.success(message: 'ok');
  }
}

class _Media extends MediaUploadService {
  _Media() : super(dio: Dio());
  int picks = 0;
  int uploads = 0;
  Completer<List<XFile>>? pendingMultiPick;
  Completer<XFile?>? pendingSinglePick;
  int avatarUploads = 0;
  @override
  Future<XFile?> pickImage({double maxSide = 1920}) async {
    picks++;
    return pendingSinglePick?.future ?? XFile('test.jpg');
  }

  @override
  Future<List<XFile>> pickMultiImage({int max = 4}) async {
    picks++;
    if (pendingMultiPick != null) return pendingMultiPick!.future;
    return [XFile('test.jpg')];
  }

  @override
  Future<MediaDraft> uploadAvatar(XFile file, {bool Function()? canStartRemote, CancelToken? cancelToken}) async {
    avatarUploads++;
    return MediaDraft(
      localId: file.path,
      state: MediaUploadState.ready,
      assetId: 'avatar',
      mediaUrl: 'https://example.test/avatar.jpg',
    );
  }

  @override
  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
    bool Function()? canStartRemote,
    CancelToken? cancelToken,
  }) async {
    uploads++;
    return MediaDraft(
      localId: file.path,
      state: MediaUploadState.ready,
      assetId: 'asset',
    );
  }
}

class _Chat extends ChatService {
  _Chat() : super(dio: Dio());
  int sends = 0;
  @override
  Future<ChatConversation> conversation(String id) async => ChatConversation(
    id: id,
    otherUserId: 'other',
    otherDisplayName: 'Otro',
    status: 'ACTIVE',
  );
  @override
  Future<List<ChatMessage>> messages(String id) async => [];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<ChatMessage> send(
    String id,
    String content, {
    List<String> mediaAssetIds = const [],
  }) async {
    sends++;
    return ChatMessage(
      id: 'sent',
      conversationId: id,
      senderId: 'me',
      content: content,
      mine: true,
    );
  }
}

class _Polls extends PollaService {
  _Polls() : super(dio: Dio());
  int votes = 0;
  @override
  Future<MatchPollResults> getPollResults(String id) async =>
      const MatchPollResults(
        pollId: 'poll',
        totalVotes: 0,
        options: [
          MatchPollOptionResult(
            optionId: 'a',
            displayName: 'La U',
            sortOrder: 0,
            voteCount: 0,
            percentage: 0,
          ),
        ],
      );
  @override
  Future<MatchPollResults> vote({
    required String pollId,
    required String optionId,
  }) async {
    votes++;
    return getPollResults(pollId);
  }
}

class _NoFan extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _Reactions extends CommunityService {
  _Reactions() : super(dio: Dio());
  int writes = 0;
  @override
  Future<WallPostModel> getPost(String id) async => WallPostModel(
    id: id,
    username: 'fan',
    fullName: 'Hincha',
    content: 'Vamos',
    imageUrl: null,
    locationTag: 'HOME',
    status: 'ACTIVE',
    reportCount: 0,
    createdAt: DateTime.now().toIso8601String(),
    isMine: true,
  );
  @override
  Future<CommentsPageResult> listComments({
    required String postId,
    String? cursor,
    int size = 20,
  }) async => const CommentsPageResult(items: [], size: 20, hasNext: false);
  @override
  Future<ReactionResult> upsertReaction({
    required String postId,
    required String type,
  }) async {
    writes++;
    return ReactionResult.success(message: 'ok');
  }
}

const _passport = PassportModel(
  identity: PassportIdentity(username: 'fan', displayName: 'Hincha Crema'),
  level: PassportLevel(
    number: 1,
    name: 'Hincha',
    points: 0,
    levelMinPoints: 0,
    progressPercent: 0,
    pointsToNextLevel: 10,
  ),
  stats: PassportStats(
    checkIns: 0,
    predictions: 0,
    predictionPoints: 0,
    posts: 0,
    streakCurrent: 0,
    streakBest: 0,
  ),
  globalRank: null,
  profileVisibility: 'PUBLIC',
  viewerIsOwner: true,
);

Widget _app(_Source source, Widget child) => ProviderScope(
  overrides: [connectivitySourceProvider.overrideWithValue(source)],
  child: Consumer(
    builder: (context, ref, _) {
      ref.watch(connectivityStatusProvider);
      return MaterialApp(home: child);
    },
  ),
);

void main() {
  testWidgets(
    'offline post retains draft and selects photo locally without upload',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _Source(ConnectivityResult.none);
      addTearDown(source.dispose);
      final community = _Community();
      final media = _Media();
      await tester.pumpWidget(
        _app(
          source,
          CreateCommunityPostPage(communityService: community, media: media),
        ),
      );
      await tester.pump();
      source.emit(ConnectivityResult.none);
      await tester.enterText(find.byType(TextField), 'Mi borrador');
      await tester.tap(find.text('Agregar fotos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de galería'));
      await tester.pump();
      expect(media.picks, 1);
      expect(media.uploads, 0);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      await tester.tap(find.text('Publicar'));
      await tester.pump();
      expect(community.calls, 0);
      expect(find.text('Mi borrador'), findsOneWidget);
      expect(find.text(offlineActionMessage), findsOneWidget);
    },
  );

  testWidgets(
    'offline chat retains draft and selects attachment without upload',
    (tester) async {
      final source = _Source(ConnectivityResult.none);
      addTearDown(source.dispose);
      final chat = _Chat();
      final media = _Media();
      await tester.pumpWidget(
        _app(
          source,
          ChatConversationPage(
            conversationId: 'c1',
            chatService: chat,
            mediaService: media,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();
      source.emit(ConnectivityResult.none);
      await tester.enterText(
        find.byKey(const Key('chat-composer')),
        'Mensaje pendiente',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-attach-photo')));
      await tester.pump();
      expect(media.picks, 1);
      expect(media.uploads, 0);
      expect(find.byKey(const Key('chat-image-preview-0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      expect(chat.sends, 0);
      expect(find.text('Mensaje pendiente'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('offline community creation can select local avatar', (
    tester,
  ) async {
    final source = _Source(ConnectivityResult.none);
    addTearDown(source.dispose);
    final media = _Media();
    await tester.pumpWidget(_app(source, CreateCommunityPage(media: media)));
    await tester.pump();
    source.emit(ConnectivityResult.none);
    await tester.tap(find.text('Agregar avatar'));
    await tester.pump();
    expect(media.picks, 1);
    expect(media.uploads, 0);
    expect(
      find.byKey(const ValueKey('community_avatar_field')),
      findsOneWidget,
    );
  });

  testWidgets(
    'online chat picker uploads selected image',
    (tester) async {
      final source = _Source(ConnectivityResult.wifi);
      addTearDown(source.dispose);
      final media = _Media();
      final chat = _Chat();
      await tester.pumpWidget(
        _app(
          source,
          ChatConversationPage(
            conversationId: 'c1',
            chatService: chat,
            mediaService: media,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-attach-photo')));
      await tester.pump();
      expect(media.picks, 1);
      expect(media.uploads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'online to offline during chat picker preserves selected image without upload',
    (tester) async {
      final source = _Source(ConnectivityResult.wifi);
      addTearDown(source.dispose);
      final media = _Media()..pendingMultiPick = Completer<List<XFile>>();
      await tester.pumpWidget(
        _app(
          source,
          ChatConversationPage(
            conversationId: 'c1',
            chatService: _Chat(),
            mediaService: media,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-attach-photo')));
      await tester.pump();
      source.emit(ConnectivityResult.none);
      media.pendingMultiPick!.complete([XFile('selected.jpg')]);
      await tester.pump();
      expect(media.uploads, 0);
      expect(find.byKey(const Key('chat-image-preview-0')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'online to offline during post picker preserves photo without upload',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = _Source(ConnectivityResult.wifi);
      addTearDown(source.dispose);
      final media = _Media()..pendingMultiPick = Completer<List<XFile>>();
      await tester.pumpWidget(
        _app(
          source,
          CreateCommunityPostPage(communityService: _Community(), media: media),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Agregar fotos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de galería'));
      await tester.pump();
      source.emit(ConnectivityResult.none);
      media.pendingMultiPick!.complete([XFile('selected.jpg')]);
      await tester.pump();
      expect(media.uploads, 0);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    },
  );

  testWidgets(
    'avatar selection stays pending and loading clears when offline blocks upload',
    (tester) async {
      final source = _Source(ConnectivityResult.wifi);
      addTearDown(source.dispose);
      final media = _Media()..pendingSinglePick = Completer<XFile?>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivitySourceProvider.overrideWithValue(source),
            myPassportProvider.overrideWith((ref) async => _passport),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(connectivityStatusProvider);
              return MaterialApp(home: ProfileEditScreen(media: media));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('change-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Galería'));
      await tester.pump();
      source.emit(ConnectivityResult.none);
      media.pendingSinglePick!.complete(XFile('avatar.jpg'));
      await tester.pump();
      expect(media.avatarUploads, 0);
      expect(find.text('Subir foto seleccionada'), findsOneWidget);
      expect(find.text('Subiendo foto…'), findsNothing);
      source.emit(ConnectivityResult.wifi);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('change-avatar')));
      await tester.pump();
      expect(media.avatarUploads, 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('change-avatar')),
          matching: find.text('Cambiar foto'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('reaction picker checks offline again before remote mutation', (
    tester,
  ) async {
    final source = _Source(ConnectivityResult.wifi);
    addTearDown(source.dispose);
    final service = _Reactions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivitySourceProvider.overrideWithValue(source),
          communityServiceProvider.overrideWithValue(service),
          currentFanProvider.overrideWith(_NoFan.new),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(connectivityStatusProvider);
            return const MaterialApp(home: PostDetailScreen(postId: 'post-1'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('reaction_cta')));
    await tester.tap(find.byKey(const ValueKey('reaction_cta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('post_reaction_picker')), findsOneWidget);
    source.emit(ConnectivityResult.none);
    await tester.tap(find.byKey(const ValueKey('reaction_option_LIKE')));
    await tester.pumpAndSettle();
    expect(service.writes, 0);
    expect(find.text(offlineActionMessage), findsOneWidget);
  });

  for (final degraded in [false, true]) {
    testWidgets(
      degraded ? 'degraded chat still sends' : 'online chat still sends',
      (tester) async {
        final source = _Source(ConnectivityResult.wifi);
        addTearDown(source.dispose);
        final chat = _Chat();
        await tester.pumpWidget(
          _app(
            source,
            ChatConversationPage(
              conversationId: 'c1',
              chatService: chat,
              pollInterval: const Duration(hours: 1),
            ),
          ),
        );
        await tester.pump();
        if (degraded) {
          ProviderScope.containerOf(
            tester.element(find.byKey(const Key('chat-composer'))),
          ).read(connectivityStatusProvider.notifier).reportDegraded();
        }
        await tester.enterText(
          find.byKey(const Key('chat-composer')),
          'Enviar ahora',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('chat-send')));
        await tester.pump();
        expect(chat.sends, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('offline vote does not call service', (tester) async {
    final source = _Source(ConnectivityResult.none);
    addTearDown(source.dispose);
    final polls = _Polls();
    const poll = MatchPoll(
      id: 'poll',
      matchId: 'm1',
      question: '¿Quién gana?',
      type: 'GENERAL',
      status: 'OPEN',
      voteCount: 0,
      options: [
        MatchPollOption(
          id: 'a',
          displayName: 'La U',
          sortOrder: 0,
          voteCount: 0,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivitySourceProvider.overrideWithValue(source),
          pollaServiceProvider.overrideWithValue(polls),
          matchdayPollsProvider.overrideWith((ref, id) async => [poll]),
          matchdayProvider.overrideWith(
            (ref, id) async => throw StateError('unused'),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(connectivityStatusProvider);
            return const MaterialApp(home: MatchdayPollsPage(matchId: 'm1'));
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    source.emit(ConnectivityResult.none);
    await tester.tap(find.text('La U'));
    await tester.pump();
    expect(polls.votes, 0);
  });

  testWidgets(
    'online and degraded actions proceed; offline navigation remains available',
    (tester) async {
      final source = _Source(ConnectivityResult.wifi);
      addTearDown(source.dispose);
      var calls = 0;
      Widget page() => Scaffold(
        body: Column(
          children: [
            const Text('Contenido disponible'),
            TextButton(
              onPressed: () {
                if (allowNetworkAction(
                  tester.element(find.text('Contenido disponible')),
                )) {
                  calls++;
                }
              },
              child: const Text('Acción'),
            ),
            Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Otra pantalla')),
                  ),
                ),
                child: const Text('Navegar'),
              ),
            ),
          ],
        ),
      );
      await tester.pumpWidget(_app(source, page()));
      await tester.pump();
      await tester.tap(find.text('Acción'));
      expect(calls, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.text('Acción')),
      );
      container.read(connectivityStatusProvider.notifier).reportDegraded();
      await tester.pump();
      await tester.tap(find.text('Acción'));
      expect(calls, 2);
      source.emit(ConnectivityResult.none);
      await tester.pump();
      await tester.tap(find.text('Acción'));
      expect(calls, 2);
      expect(find.text('Contenido disponible'), findsOneWidget);
      await tester.tap(find.text('Navegar'));
      await tester.pumpAndSettle();
      expect(find.text('Otra pantalla'), findsOneWidget);
    },
  );
}
