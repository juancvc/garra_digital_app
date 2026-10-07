import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/post_location.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/create_community_post_page.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

WallPostModel post(String id, String content, {String? imageUrl}) =>
    WallPostModel(
      id: id,
      username: 'hincha',
      fullName: 'Hincha',
      content: content,
      imageUrl: imageUrl,
      locationTag: 'HOME',
      status: 'ACTIVE',
      reportCount: 0,
      createdAt: '2026-09-29T12:00:00Z',
    );

class FakeService extends CommunityService {
  FakeService() : super(dio: Dio());

  int creates = 0;
  int feedCalls = 0;
  List<WallPostModel> feed = [post('old', 'Post anterior')];
  List<String>? uploadedIds;
  String? submittedVisibility;
  Completer<WallActionResult>? pending;
  WallActionResult result = WallActionResult.success(
    message: 'ok',
    post: post('new', 'Nuevo post'),
  );

  @override
  Future<FeedPage> getFeedPage({required String mode, String? cursor, int size = 20}) async => FeedPage.posts(posts: await getGlobalFeed(mode: mode));

  @override
  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async {
    feedCalls++;
    return feed;
  }

  @override
  Future<WallActionResult> createGlobalPost({
    required String content,
    String? mediaAssetId,
    List<String>? mediaAssetIds,
    String? locationTag,
    PostLocation? postLocation,
    String visibility = 'PUBLIC',
  }) async {
    creates++;
    submittedVisibility = visibility;
    uploadedIds = mediaAssetIds;
    return pending?.future ?? result;
  }
}

class FakeMedia extends MediaUploadService {
  FakeMedia() : super(dio: Dio());

  @override
  Future<List<XFile>> pickMultiImage({int max = 4}) async => [
    XFile('photo.jpg'),
  ];

  @override
  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
    bool Function()? canStartRemote,
    CancelToken? cancelToken,
  }) async {
    final draft = MediaDraft(
      localId: file.path,
      assetId: 'asset-photo',
      state: MediaUploadState.ready,
    );
    onUpdate?.call(draft);
    return draft;
  }
}

Future<void> mountFeed(
  WidgetTester tester,
  FakeService service,
  String mode, {
  MediaUploadService? media,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: SocialFeedTab(mode: mode)),
      ),
      GoRoute(
        path: '/comunidad/compose',
        builder: (context, state) =>
            CreateCommunityPostPage(communityService: service, media: media),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityServiceProvider.overrideWithValue(service)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openComposer(WidgetTester tester) async {
  await tester.tap(find.text('¿Qué vive la crema hoy?'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('GLOBAL defaults PUBLIC and can publish to followers', (tester) async {
    final service = FakeService();
    await mountFeed(tester, service, 'RECENT');
    await openComposer(tester);
    expect(find.text('Todo Garra'), findsOneWidget);
    await tester.tap(find.text('Todo Garra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis seguidores').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar borrador?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Solo seguidores');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(service.submittedVisibility, 'FOLLOWERS');
  });
  testWidgets(
    'publish shows progress, blocks duplicate tap, then inserts once in FOR_YOU',
    (tester) async {
      final service = FakeService()..pending = Completer<WallActionResult>();
      await mountFeed(tester, service, 'FOR_YOU');
      await openComposer(tester);
      await tester.enterText(find.byType(TextField), 'Nuevo post');
      await tester.tap(find.text('Publicar'));
      await tester.pump();
      expect(find.text('Publicando...'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Publicando...'),
            )
            .onPressed,
        isNull,
      );
      service.pending!.complete(service.result);
      await tester.pumpAndSettle();
      expect(service.creates, 1);
      expect(service.feedCalls, 1);
      expect(find.text('Nuevo post'), findsOneWidget);
      expect(find.text('Post anterior'), findsOneWidget);
    },
  );

  testWidgets(
    'RECENT inserts locally and later reconciliation replaces by ID',
    (tester) async {
      final service = FakeService();
      await mountFeed(tester, service, 'RECENT');
      await openComposer(tester);
      await tester.enterText(find.byType(TextField), 'Nuevo post');
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo post'), findsOneWidget);
      expect(service.feedCalls, 1);
      final element = tester.element(find.byType(SocialFeedTab));
      ProviderScope.containerOf(element)
          .read(communityFeedRevisionProvider.notifier)
          .published(post('new', 'Nuevo post'));
      await tester.pump();
      expect(find.text('Nuevo post'), findsOneWidget);
    },
  );

  testWidgets('failure preserves draft and restores publish action', (
    tester,
  ) async {
    final service = FakeService()..result = WallActionResult.failure('failed');
    await mountFeed(tester, service, 'FOR_YOU');
    await openComposer(tester);
    await tester.enterText(find.byType(TextField), 'Borrador');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(find.text('Borrador'), findsOneWidget);
    expect(find.text('Publicar'), findsOneWidget);
    expect(
      find.text('No pudimos publicar. Intenta nuevamente.'),
      findsOneWidget,
    );
  });

  testWidgets('photo post is visible locally with its uploaded asset', (
    tester,
  ) async {
    final service = FakeService()
      ..result = WallActionResult.success(
        message: 'ok',
        post: post(
          'photo-new',
          'Foto nueva',
          imageUrl: 'https://example.invalid/photo.jpg',
        ),
      );
    await mountFeed(tester, service, 'FOR_YOU', media: FakeMedia());
    await openComposer(tester);
    await tester.enterText(find.byType(TextField), 'Foto nueva');
    await tester.tap(find.text('Agregar fotos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir de galería'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(service.uploadedIds, ['asset-photo']);
    expect(find.text('Foto nueva'), findsOneWidget);
    expect(service.feedCalls, 1);
  });

  testWidgets('Home feed returns to top after publish', (tester) async {
    final service = FakeService()
      ..feed = List.generate(25, (i) => post('old-$i', 'Anterior $i'));
    await mountFeed(tester, service, 'FOR_YOU');
    final controller = tester
        .widget<ListView>(find.byType(ListView).first)
        .controller!;
    controller.jumpTo(500);
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    final router = GoRouter.of(tester.element(find.byType(SocialFeedTab)));
    unawaited(router.push<bool>('/comunidad/compose'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nuevo post');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(find.text('Nuevo post'), findsOneWidget);
  });
}
