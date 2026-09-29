import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_share_sheet.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';

final _original = WallPostModel.fromJson({
  'id': 'original', 'username': 'ana', 'fullName': 'Ana',
  'content': 'Vamos la U', 'status': 'ACTIVE', 'contextType': 'GLOBAL',
  'createdAt': '2026-09-29T12:00:00Z', 'reactionCount': 2,
  'reactionSummary': {'FIRE': 2}, 'commentCount': 3, 'shareCount': 1,
});

final _share = WallPostModel.fromJson({
  'id': 'share', 'username': 'luis', 'fullName': 'Luis',
  'content': '', 'status': 'ACTIVE', 'contextType': 'GLOBAL',
  'isMine': true,
  'createdAt': '2026-09-29T13:00:00Z',
  'originalPost': {
    'id': 'original', 'authorId': 'ana-id', 'username': 'ana',
    'fullName': 'Ana', 'content': 'Vamos la U',
    'createdAt': '2026-09-29T12:00:00Z', 'shareCount': 2,
    'media': [{'id': 'media-1', 'url': 'https://example.invalid/one.jpg'}],
  },
});

class _ShareService extends CommunityService {
  _ShareService() : super(dio: Dio());
  int shareCalls = 0;
  int undoCalls = 0;
  Completer<WallActionResult>? pending;
  @override
  Future<WallActionResult> shareGlobalPost(String postId) {
    shareCalls++;
    return pending?.future ?? Future.value(WallActionResult.success(message: 'ok', post: _share));
  }
  @override
  Future<int?> undoGlobalShare(String postId) async { undoCalls++; return 0; }
  @override
  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async => [_original];
}

class _NoFan extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

Future<void> _pumpSheet(WidgetTester tester, _ShareService service, WallPostModel post,
    ValueChanged<GarraShareOutcome?> onResult) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
    TextButton(onPressed: () async => onResult(await showGarraShareSheet(
      context, post: post, service: service)), child: const Text('Abrir'))))));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('narrow post metrics fit without truncating share count', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 280, child: GarraSocialPostCard(
        post: _original, onOpen: () {})),
    ))));
    expect(tester.takeException(), isNull);
    expect(find.text('· 1 comp.'), findsOneWidget);
    expect(find.textContaining('comparti...'), findsNothing);
  });
  test('legacy response has safe share defaults; share preview is flat', () {
    expect(_original.shareCount, 1);
    expect(WallPostModel.fromJson({'id': 'legacy'}).shareCount, 0);
    expect(_share.originalPost?.id, 'original');
    expect(_share.originalPost?.media.single.id, 'media-1');
    expect(_share.originalPost?.asPost().originalPost, isNull);
  });

  testWidgets('card keeps reactions, comment and share actions distinct', (tester) async {
    var reacted = 0, commented = 0, shared = 0, opened = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GarraSocialPostCard(
      post: _original, onOpen: () => opened++, onReact: () => reacted++,
      onComment: () => commented++, onShare: () => shared++))));
    expect(find.text('3 comentarios'), findsOneWidget);
    expect(find.text('· 1 compartido'), findsOneWidget);
    expect(find.textContaining('Ver 2 reacciones'), findsNothing);
    await tester.tap(find.text('Reaccionar'));
    await tester.tap(find.text('Comentar'));
    await tester.tap(find.text('Compartir'));
    expect((reacted, commented, shared), (1, 1, 1));
    await tester.tap(find.text('· 1 compartido'));
    expect(opened, 1);
  });

  testWidgets('share card distinguishes authors and opens original', (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: GarraSocialPostCard(post: _share, onOpen: () {},
        onOpenOriginal: () => opened++)))));
    expect(find.text('Luis compartió'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.text('Vamos la U'));
    expect(opened, 1);
    await tester.tap(find.byKey(const ValueKey('post_media_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('garra_media_viewer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('viewer_view_post')));
    expect(opened, 2);
  });

  testWidgets('sheet prevents double tap and returns successful share', (tester) async {
    final service = _ShareService()..pending = Completer<WallActionResult>();
    GarraShareOutcome? result;
    await _pumpSheet(tester, service, _original, (value) => result = value);
    await tester.tap(find.text('Compartir en Garra'));
    await tester.pump();
    expect(find.text('Procesando...'), findsOneWidget);
    expect(find.text('Compartir en otras apps'), findsOneWidget);
    await tester.tap(find.text('Procesando...'), warnIfMissed: false);
    expect(service.shareCalls, 1);
    service.pending!.complete(WallActionResult.success(message: 'ok', post: _share));
    await tester.pumpAndSettle();
    expect(result?.sharedPost?.id, 'share');
  });

  testWidgets('share error keeps sheet and external option available', (tester) async {
    final service = _ShareService()..pending = Completer<WallActionResult>();
    GarraShareOutcome? result;
    await _pumpSheet(tester, service, _original, (value) => result = value);
    await tester.tap(find.text('Compartir en Garra'));
    service.pending!.complete(WallActionResult.failure('gone'));
    await tester.pumpAndSettle();
    expect(find.text('gone'), findsOneWidget);
    await tester.tap(find.text('Compartir en otras apps'));
    await tester.pumpAndSettle();
    expect(result?.external, isTrue);
  });

  testWidgets('existing share can be undone', (tester) async {
    final service = _ShareService();
    GarraShareOutcome? result;
    await _pumpSheet(tester, service, _original.copyWith(sharedByMe: true),
        (value) => result = value);
    await tester.tap(find.text('Deshacer compartido'));
    await tester.pumpAndSettle();
    expect(service.undoCalls, 1);
    expect(result?.undoCount, 0);
  });

  testWidgets('share signal reconciles original count and undo without reload', (tester) async {
    final service = _ShareService();
    final container = ProviderContainer(overrides: [
      communityServiceProvider.overrideWithValue(service),
      currentFanProvider.overrideWith(_NoFan.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: Scaffold(body: SocialFeedTab(mode: 'RECENT')))));
    await tester.pumpAndSettle();
    container.read(communityFeedRevisionProvider.notifier).published(_share);
    await tester.pumpAndSettle();
    expect(find.text('Luis compartió'), findsOneWidget);
    expect(find.text('0 comentarios'), findsWidgets);
    expect(find.text('· 2 compartidos'), findsWidgets);
    container.read(communityFeedRevisionProvider.notifier).published(_share);
    await tester.pumpAndSettle();
    expect(find.text('Luis compartió'), findsOneWidget);
    container.read(communityFeedRevisionProvider.notifier).unshared('original', 1);
    await tester.pumpAndSettle();
    expect(find.text('Luis compartió'), findsNothing);
    expect(tester.widgetList<Text>(find.byType(Text)).map((t) => t.data)
        .where((t) => t?.contains('compartid') == true).toList(),
        contains('· 1 compartido'));
  });
}
