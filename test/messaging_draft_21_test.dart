import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/post_location.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/create_community_post_page.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_conversation_page.dart';

class _Posts extends CommunityService {
  _Posts() : super(dio: Dio());
  int calls = 0;
  bool fail = false;

  @override
  Future<WallActionResult> createGlobalPost({required String content,
      String? mediaAssetId, List<String>? mediaAssetIds, String? locationTag,
      PostLocation? postLocation, String visibility = 'PUBLIC'}) async {
    calls++;
    if (fail) throw Exception('network');
    return WallActionResult.success(message: 'ok', post: WallPostModel(
      id: 'created', username: 'hincha', fullName: 'Hincha', content: content, imageUrl: null,
      locationTag: 'HOME', status: 'ACTIVE', reportCount: 0,
      createdAt: '2026-09-29T12:00:00Z'));
  }
}

class _Media extends MediaUploadService {
  _Media() : super(dio: Dio());
  bool fail = false;

  @override
  Future<List<XFile>> pickMultiImage({int max = 4}) async => [XFile('photo.jpg')];

  @override
  Future<MediaDraft> uploadFile({required XFile file,
      required MediaUploadPurpose purpose, void Function(MediaDraft draft)? onUpdate,
      int? squareMax, bool Function()? canStartRemote, CancelToken? cancelToken}) async {
    final draft = MediaDraft(localId: file.path, localPath: file.path,
        assetId: fail ? null : 'asset',
        state: fail ? MediaUploadState.failed : MediaUploadState.ready);
    onUpdate?.call(draft);
    return draft;
  }
}

class _Chat extends ChatService {
  _Chat() : super(dio: Dio());
  int sends = 0;

  @override
  Future<ChatConversation> conversation(String id) async => const ChatConversation(
    id: 'c1', otherUserId: 'other', otherDisplayName: 'Otra persona', status: 'ACTIVE');

  @override
  Future<List<ChatMessage>> messages(String id) async => [];

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<ChatMessage> send(String id, String content, {List<String> mediaAssetIds = const []}) async {
    sends++;
    return ChatMessage(id: 'm1', conversationId: id, senderId: 'me', content: content, mine: true);
  }
}

void main() {
  late _Posts posts;
  late _Media media;
  late GoRouter router;

  setUp(() {
    posts = _Posts();
    media = _Media();
    router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Feed'))),
      GoRoute(path: '/compose', builder: (_, _) =>
          CreateCommunityPostPage(communityService: posts, media: media)),
    ]);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    router.push('/compose');
    await tester.pumpAndSettle();
  }

  testWidgets('clean composer leaves without a dialog', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('¿Descartar borrador?'), findsNothing);
  });

  testWidgets('text draft keeps editing or discards on explicit choice', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Vamos Garra');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar borrador?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Vamos Garra'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Feed'), findsOneWidget);
  });

  testWidgets('failed photo upload remains a guarded draft', (tester) async {
    media.fail = true;
    await open(tester);
    await tester.tap(find.text('Agregar fotos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir de galería'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar borrador?'), findsOneWidget);
  });

  testWidgets('successful publish exits without discard prompt; failed publish keeps text', (tester) async {
    posts.fail = true;
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Post');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(find.text('Post'), findsOneWidget);
    posts.fail = false;
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(posts.calls, 2);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('¿Descartar borrador?'), findsNothing);
  });

  testWidgets('private chat draft is guarded and a successful send clears it', (tester) async {
    final chat = _Chat();
    final chatRouter = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Inbox'))),
      GoRoute(path: '/chat', builder: (_, _) => ChatConversationPage(
          conversationId: 'c1', chatService: chat, pollInterval: const Duration(hours: 1))),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: chatRouter));
    chatRouter.push('/chat');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chat-composer')), 'Hola');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar borrador?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Hola'), findsOneWidget);
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();
    expect(chat.sends, 1);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('¿Descartar borrador?'), findsNothing);
  });
}
