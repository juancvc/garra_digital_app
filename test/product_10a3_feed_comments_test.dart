import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_post_media_grid.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';

WallPostModel _post({bool photo = false}) => WallPostModel(
  id: 'post-1', username: 'crema', fullName: 'Hincha Crema',
  content: 'Una historia de la tribuna con texto visible hasta el final.',
  imageUrl: null, locationTag: 'HOME', status: 'ACTIVE', reportCount: 0,
  createdAt: DateTime.now().toUtc().toIso8601String(), commentCount: 1,
  media: photo ? const [WallPostMediaItem(id: 'm1',
      url: 'https://example.invalid/photo.jpg', sortOrder: 0)] : const [],
);

class _CommentsService extends CommunityService {
  int postCalls = 0;
  int commentCalls = 0;

  @override
  Future<FeedPage> getFeedPage({required String mode, String? cursor,
      int size = 20}) async => FeedPage.posts(
          posts: [_post().copyWith(isMine: true)]);

  @override
  Future<WallPostModel> getPost(String postId) async {
    postCalls++;
    return _post();
  }

  @override
  Future<CommentsPageResult> listComments({required String postId,
      String? cursor, int size = 20}) async {
    commentCalls++;
    return CommentsPageResult(items: [WallCommentModel(id: 'c1', postId: postId,
      username: 'otra', fullName: 'Otra hincha', content: 'Respuesta real',
      createdAt: DateTime.now().toUtc().toIso8601String())],
      size: size, hasNext: false);
  }
}

void main() {
  testWidgets('feed Comentar opens sheet and content tap keeps detail callback',
      (tester) async {
    final service = _CommentsService();
    await tester.pumpWidget(ProviderScope(
      overrides: [communityServiceProvider.overrideWithValue(service)],
      child: MaterialApp(theme: AppTheme.darkTheme,
        home: const Scaffold(body: SocialFeedTab(mode: 'FOR_YOU'))),
    ));
    await tester.pumpAndSettle();
    final comment = find.text('Comentar').first;
    await tester.ensureVisible(comment);
    await tester.tap(comment);
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('Respuesta real'), findsOneWidget);
  });

  for (final withPhoto in [false, true]) {
    testWidgets('post at 220 px fits without overflow (photo=$withPhoto)',
        (tester) async {
      tester.view.physicalSize = const Size(220, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme,
        home: Scaffold(body: SingleChildScrollView(child:
          GarraSocialPostCard(post: _post(photo: withPhoto), onOpen: () {})))));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('text post stays clean and opens detail on content tap', (tester) async {
    var opens = 0;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child:
        GarraSocialPostCard(post: _post(), onOpen: () => opens++)))));
    expect(find.byType(GarraPostMediaGrid), findsNothing);
    await tester.tap(find.textContaining('Una historia'));
    expect(opens, 1);
  });

  testWidgets('photo post keeps editorial media and separate comment action', (tester) async {
    var comments = 0;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child:
        GarraSocialPostCard(post: _post(photo: true), onOpen: () {},
          onComment: () => comments++)))));
    expect(find.byType(GarraPostMediaGrid), findsOneWidget);
    await tester.ensureVisible(find.text('Comentar'));
    await tester.tap(find.text('Comentar'));
    expect(comments, 1);
  });

  testWidgets('comments sheet reuses detail comments, composer and sticker preview', (tester) async {
    final service = _CommentsService();
    await tester.pumpWidget(ProviderScope(
      overrides: [communityServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPostCommentsSheet(context, postId: 'post-1'),
                child: const Text('Abrir comentarios'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir comentarios'));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.textContaining('Comentarios · 1'), findsOneWidget);
    expect(find.text('Respuesta real'), findsOneWidget);
    expect(find.byKey(const ValueKey('comment_sticker')), findsOneWidget);
    expect(service.postCalls, 1);
    expect(service.commentCalls, 1);
    final sheet = tester.getRect(find.byType(DraggableScrollableSheet));
    expect(sheet.height, greaterThan(400));
    expect(sheet.height, lessThan(tester.view.physicalSize.height));
    await tester.tap(find.text('Responder'));
    await tester.pump();
    expect(find.byKey(const ValueKey('reply_mode_bar')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('comment_composer')),
        ':garra_gol:');
    await tester.pump();
    expect(find.byKey(const ValueKey('comment_sticker_draft')), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar sticker'));
    await tester.pump();
    expect(find.byKey(const ValueKey('comment_composer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reply_cancel')));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('comment_composer')), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar comentarios'));
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsNothing);
  });

  testWidgets('comments sheet fits a narrow screen with keyboard inset',
      (tester) async {
    tester.view.physicalSize = const Size(220, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _CommentsService();
    await tester.pumpWidget(ProviderScope(
      overrides: [communityServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPostCommentsSheet(context, postId: 'post-1'),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('comment_composer')), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
  });
}
