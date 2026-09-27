import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/reaction_result.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reaction_bar.dart';

// Staging-shaped payloads (PostCommentResponse with reply fields).
const _meId = '3f0c8a52-7d1e-4c55-9b0e-2a41f6c1d9aa';
const _otherId = '9b2d7e11-0c4f-4a8e-8f3a-5d6e7f8a9b0c';
const _postId = 'b1c2d3e4-0000-4000-8000-000000000001';
const _gone = 'Este comentario ya no est\u00e1 disponible.';

Map<String, dynamic> _commentJson({
  required String id,
  required String authorId,
  String content = 'Vamos la U',
  String? parentCommentId,
  int? replyCount,
  String? replyToUsername,
  String? myReaction,
}) => {
  'id': id,
  'postId': _postId,
  'username': authorId == _meId ? 'yo' : 'otro',
  'fullName': authorId == _meId ? 'Hincha Yo' : 'Hincha Otro',
  'content': content,
  'status': 'ACTIVE',
  'createdAt': '2026-09-26T20:00:00Z',
  'authorId': authorId,
  'avatarUrl': null,
  'updatedAt': null,
  'editedAt': null,
  'reactionCount': myReaction == null ? 0 : 1,
  'reactionSummary': {
    'LIKE': 0,
    'LOVE': 0,
    'FIRE': 0,
    'ANGER': 0,
    'SAD': 0,
    'GARRA': myReaction == 'GARRA' ? 1 : 0,
  },
  'myReaction': myReaction,
  'parentCommentId': parentCommentId,
  'replyCount': replyCount,
  'replyToUsername': replyToUsername,
  'replyToDisplayName': null,
};

WallPostModel _post(int commentCount) => WallPostModel.fromJson({
  'id': _postId,
  'username': 'otro',
  'fullName': 'Hincha Otro',
  'content': 'Arenga de detalle',
  'status': 'ACTIVE',
  'reportCount': 0,
  'createdAt': '2026-09-26T19:00:00Z',
  'reactionCount': 0,
  'commentCount': commentCount,
  'authorId': _otherId,
  'isMine': false,
});

class _Fan extends CurrentFanNotifier {
  _Fan(this.user);
  final AuthUser? user;

  @override
  Future<AuthUser?> build() async => user;
}

class _Service extends CommunityService {
  _Service(this.roots, {this.replies = const {}, int commentCount = 1})
    : post = _post(commentCount),
      super(dio: Dio());

  final List<Map<String, dynamic>> roots;
  final Map<String, List<Map<String, dynamic>>> replies;
  final WallPostModel post;
  final List<String> calls = [];
  bool replyGone = false;
  bool failRepliesOnce = false;

  @override
  Future<WallPostModel> getPost(String postId) async => post;

  @override
  Future<CommentsPageResult> listComments({
    required String postId,
    String? cursor,
    int size = 20,
  }) async => CommentsPageResult.fromJson({
    'items': roots,
    'page': {'size': size, 'hasNext': false, 'nextCursor': null},
  });

  @override
  Future<CommentsPageResult> fetchReplies({
    required String commentId,
    String? cursor,
    int size = 20,
  }) async {
    calls.add('replies:$commentId:${cursor ?? '-'}');
    if (failRepliesOnce) {
      failRepliesOnce = false;
      throw DioException(requestOptions: RequestOptions(path: '/x'));
    }
    final all = replies[commentId] ?? const [];
    final paged = cursor == null && all.length > 2;
    return CommentsPageResult.fromJson({
      'items': paged
          ? all.take(2).toList()
          : (cursor == null ? all : all.skip(2).toList()),
      'page': {
        'size': size,
        'hasNext': paged,
        'nextCursor': paged ? 'c2' : null,
      },
    });
  }

  @override
  Future<CommentActionResult> createReply({
    required String postId,
    required String parentCommentId,
    required String content,
  }) async {
    calls.add('reply:$parentCommentId:$content');
    if (replyGone) {
      return CommentActionResult.failure(_gone, notFound: true);
    }
    final isRoot = roots.any((r) => r['id'] == parentCommentId);
    return CommentActionResult.success(
      message: 'Respuesta publicada',
      comment: WallCommentModel.fromJson(
        _commentJson(
          id: 'new-reply',
          authorId: _meId,
          content: content,
          parentCommentId: isRoot ? parentCommentId : 'c1',
          replyToUsername: isRoot ? null : 'otro',
        ),
      ),
    );
  }

  @override
  Future<CommentActionResult> deleteComment(String commentId) async {
    calls.add('delete:$commentId');
    return CommentActionResult.success(message: 'Comentario eliminado');
  }

  @override
  Future<ReactionResult> upsertCommentReaction({
    required String commentId,
    required String type,
  }) async {
    calls.add('upsert:$commentId:$type');
    return ReactionResult.fromPayload({
      'myReaction': type,
      'reactionCount': 1,
      'reactionSummary': {type: 1},
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Service service, {
  AuthUser? me,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityServiceProvider.overrideWith((ref) => service),
        currentFanProvider.overrideWith(() => _Fan(me)),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        home: const PostDetailScreen(postId: _postId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _commentCount(String value) => find.descendant(
  of: find.byType(GarraReactionBar),
  matching: find.text(value),
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

CommunityService _http(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
    ..httpClientAdapter = adapter;
  return CommunityService(dio: dio);
}

void main() {
  final me = AuthUser.fromJson({'id': _meId, 'username': 'yo'});

  group('model + service contract', () {
    test('older payloads parse with reply defaults; new fields parse', () {
      final old = WallCommentModel.fromJson({
        'id': 'c1',
        'username': 'otro',
        'content': 'x',
        'createdAt': '2026-09-26T20:00:00Z',
      });
      expect(old.parentCommentId, isNull);
      expect(old.replyCount, 0);
      expect(old.replyToUsername, isNull);
      expect(old.isReply, isFalse);

      final reply = WallCommentModel.fromJson(
        _commentJson(
          id: 'r1',
          authorId: _meId,
          parentCommentId: 'c1',
          replyToUsername: 'otro',
        ),
      );
      expect(reply.isReply, isTrue);
      expect(reply.replyToUsername, 'otro');
      expect(reply.copyWith(content: 'y').parentCommentId, 'c1');
    });

    test(
      'REPLY_REQUEST: createReply sends parentCommentId, comments do not',
      () async {
        final adapter = _Adapter(
          (o) => _json(201, {
            'data': _commentJson(
              id: 'r1',
              authorId: _meId,
              parentCommentId: 'c1',
            ),
          }),
        );
        final service = _http(adapter);
        final reply = await service.createReply(
          postId: _postId,
          parentCommentId: 'c1',
          content: 'Aguante',
        );
        await service.createComment(postId: _postId, content: 'Raiz');
        expect(reply.success, isTrue);
        expect(reply.comment?.parentCommentId, 'c1');
        expect(adapter.requests[0].path, '/community/posts/$_postId/comments');
        expect(adapter.requests[0].data, {
          'content': 'Aguante',
          'parentCommentId': 'c1',
        });
        expect(
          (adapter.requests[1].data as Map).containsKey('parentCommentId'),
          isFalse,
        );
      },
    );

    test(
      'fetchReplies hits the thread endpoint; 404 reply is notFound',
      () async {
        final adapter = _Adapter((o) {
          if (o.method == 'GET') {
            return _json(200, {
              'data': {
                'items': [
                  _commentJson(
                    id: 'r1',
                    authorId: _meId,
                    parentCommentId: 'c1',
                  ),
                ],
                'page': {'size': 20, 'hasNext': true, 'nextCursor': 'abc'},
              },
            });
          }
          return _json(404, {'success': false, 'message': 'No encontrado'});
        });
        final service = _http(adapter);
        final page = await service.fetchReplies(commentId: 'c1', cursor: 'x');
        expect(adapter.requests[0].path, '/community/comments/c1/replies');
        expect(adapter.requests[0].queryParameters['cursor'], 'x');
        expect(page.items.single.parentCommentId, 'c1');
        expect(page.hasNext, isTrue);

        final gone = await service.createReply(
          postId: _postId,
          parentCommentId: 'c1',
          content: 'x',
        );
        expect(gone.success, isFalse);
        expect(gone.notFound, isTrue);
        expect(gone.message, _gone);
      },
    );
  });

  group('reply mode', () {
    testWidgets('Responder enters reply mode; x cancels', (tester) async {
      final service = _Service([_commentJson(id: 'c1', authorId: _otherId)]);
      await _pump(tester, service, me: me);
      expect(find.byKey(const ValueKey('reply_mode_bar')), findsNothing);

      await _tapKey(tester, 'comment_reply_c1');
      expect(find.byKey(const ValueKey('reply_mode_bar')), findsOneWidget);
      expect(find.text('Respondiendo a @otro'), findsOneWidget);
      expect(find.text('Responder a @otro...'), findsOneWidget);

      await _tapKey(tester, 'reply_cancel');
      expect(find.byKey(const ValueKey('reply_mode_bar')), findsNothing);
      expect(find.text('Escribe un comentario...'), findsOneWidget);
    });

    testWidgets('send reply: parentCommentId, exits mode, thread +1 locally', (
      tester,
    ) async {
      final service = _Service([_commentJson(id: 'c1', authorId: _otherId)]);
      await _pump(tester, service, me: me);
      expect(_commentCount('1'), findsOneWidget);

      await _tapKey(tester, 'comment_reply_c1');
      await tester.enterText(
        find.byKey(const ValueKey('comment_composer')),
        '  Aguante  ',
      );
      await _tapKey(tester, 'comment_send');

      expect(service.calls, ['reply:c1:Aguante']);
      expect(find.byKey(const ValueKey('reply_mode_bar')), findsNothing);
      expect(
        find.byKey(const ValueKey('comment_tile_new-reply')),
        findsOneWidget,
      );
      expect(find.text('Ocultar respuestas'), findsOneWidget);
      expect(_commentCount('2'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('comment_composer')),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('POLISH_05: comment/reply limit is 500 with counter near it', (
      tester,
    ) async {
      final service = _Service([_commentJson(id: 'c1', authorId: _otherId)]);
      await _pump(tester, service, me: me);
      final composer = find.byKey(const ValueKey('comment_composer'));
      expect(tester.widget<TextField>(composer).maxLength, 500);

      await tester.enterText(composer, 'a' * 449);
      await tester.pump();
      expect(find.byKey(const ValueKey('comment_counter')), findsNothing);

      await _tapKey(tester, 'comment_reply_c1');
      await tester.enterText(composer, 'b' * 520);
      await tester.pump();
      expect(find.text('500/500'), findsOneWidget);
      await _tapKey(tester, 'comment_send');
      expect(service.calls, ['reply:c1:${'b' * 500}']);
    });

    testWidgets('empty reply is blocked (no request)', (tester) async {
      final service = _Service([_commentJson(id: 'c1', authorId: _otherId)]);
      await _pump(tester, service, me: me);
      await _tapKey(tester, 'comment_reply_c1');
      await _tapKey(tester, 'comment_send');
      expect(service.calls, isEmpty);
      expect(find.byKey(const ValueKey('reply_mode_bar')), findsOneWidget);
    });

    testWidgets('reply to a deleted comment: Spanish 404 and removed', (
      tester,
    ) async {
      final service = _Service([_commentJson(id: 'c1', authorId: _otherId)])
        ..replyGone = true;
      await _pump(tester, service, me: me);
      await _tapKey(tester, 'comment_reply_c1');
      await tester.enterText(
        find.byKey(const ValueKey('comment_composer')),
        'Hola',
      );
      await _tapKey(tester, 'comment_send');
      expect(find.text(_gone), findsOneWidget);
      expect(find.byKey(const ValueKey('comment_tile_c1')), findsNothing);
      expect(find.byKey(const ValueKey('reply_mode_bar')), findsNothing);
    });
  });

  group('threads', () {
    Map<String, List<Map<String, dynamic>>> thread() => {
      'c1': [
        _commentJson(
          id: 'r1',
          authorId: _meId,
          content: 'Mi respuesta',
          parentCommentId: 'c1',
        ),
        _commentJson(
          id: 'r2',
          authorId: _otherId,
          content: 'Te contesto',
          parentCommentId: 'c1',
          replyToUsername: 'yo',
        ),
        _commentJson(
          id: 'r3',
          authorId: _otherId,
          content: 'Ultima',
          parentCommentId: 'c1',
        ),
      ],
    };

    testWidgets('Ver 1 respuesta vs Ver N respuestas', (tester) async {
      final service = _Service([
        _commentJson(id: 'c1', authorId: _otherId, replyCount: 1),
        _commentJson(id: 'c2', authorId: _otherId, replyCount: 3),
        _commentJson(id: 'c3', authorId: _otherId, replyCount: 0),
      ], commentCount: 7);
      await _pump(tester, service, me: me);
      expect(find.text('Ver 1 respuesta'), findsOneWidget);
      expect(find.text('Ver 3 respuestas'), findsOneWidget);
      expect(find.byKey(const ValueKey('replies_toggle_c3')), findsNothing);
      // Replies never show flattened in the main list.
      expect(find.byKey(const ValueKey('comment_tile_r1')), findsNothing);
    });

    for (final entry in <String, ThemeData Function()>{
      'Noche': () => AppTheme.darkTheme,
      'Crema': () => AppTheme.lightTheme,
    }.entries) {
      testWidgets('expand loads replies, paginates, collapses (${entry.key})', (
        tester,
      ) async {
        final service = _Service(
          [_commentJson(id: 'c1', authorId: _otherId, replyCount: 3)],
          replies: thread(),
          commentCount: 4,
        );
        await _pump(tester, service, me: me, theme: entry.value());
        await _tapKey(tester, 'replies_toggle_c1');
        expect(service.calls, ['replies:c1:-']);
        expect(find.text('Mi respuesta'), findsOneWidget);
        // "@usuario" comes from replyToUsername, not from the content.
        expect(
          find.byKey(const ValueKey('comment_reply_to_r2')),
          findsOneWidget,
        );
        expect(find.text('@yo Te contesto'), findsOneWidget);
        expect(find.text('Ultima'), findsNothing);

        await _tapKey(tester, 'replies_more_c1');
        expect(service.calls.last, 'replies:c1:c2');
        expect(find.text('Ultima'), findsOneWidget);

        await _tapKey(tester, 'replies_toggle_c1');
        expect(find.text('Mi respuesta'), findsNothing);
        expect(find.text('Ver 3 respuestas'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('load error shows Reintentar and retries', (tester) async {
      final service = _Service([
        _commentJson(id: 'c1', authorId: _otherId, replyCount: 3),
      ], replies: thread())..failRepliesOnce = true;
      await _pump(tester, service, me: me);
      await _tapKey(tester, 'replies_toggle_c1');
      expect(find.text('No pudimos cargar las respuestas.'), findsOneWidget);
      await _tapKey(tester, 'replies_retry_c1');
      expect(find.text('Mi respuesta'), findsOneWidget);
    });

    testWidgets('own reply keeps Editar/Eliminar; delete updates counts', (
      tester,
    ) async {
      final service = _Service(
        [_commentJson(id: 'c1', authorId: _otherId, replyCount: 3)],
        replies: thread(),
        commentCount: 4,
      );
      await _pump(tester, service, me: me);
      await _tapKey(tester, 'replies_toggle_c1');
      expect(find.byKey(const ValueKey('comment_menu_r2')), findsNothing);
      await _tapKey(tester, 'comment_menu_r1');
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('comment_delete_confirm')));
      await tester.pumpAndSettle();
      expect(service.calls.last, 'delete:r1');
      expect(find.text('Mi respuesta'), findsNothing);
      expect(_commentCount('3'), findsOneWidget);
      await _tapKey(tester, 'replies_toggle_c1');
      expect(find.text('Ver 2 respuestas'), findsOneWidget);
    });

    testWidgets('reaction on a reply updates only that reply', (tester) async {
      final service = _Service([
        _commentJson(id: 'c1', authorId: _otherId, replyCount: 3),
      ], replies: thread());
      await _pump(tester, service, me: me);
      await _tapKey(tester, 'replies_toggle_c1');
      await _tapKey(tester, 'comment_react_r2');
      await tester.tap(
        find.byKey(const ValueKey('comment_reaction_option_GARRA')),
      );
      await tester.pumpAndSettle();
      expect(service.calls.last, 'upsert:r2:GARRA');
      expect(tester.takeException(), isNull);
      expect(find.text('Mi respuesta'), findsOneWidget);
      expect(find.text('Ocultar respuestas'), findsOneWidget);
      // Root untouched, reply shows the selected reaction.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('comment_tile_c1')),
          matching: find.text('Reaccionar'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('comment_tile_r2')),
          matching: find.text('Reaccionar'),
        ),
        findsNothing,
      );
    });

    testWidgets('reply to a reply sends its id and stays in the root thread', (
      tester,
    ) async {
      final service = _Service(
        [_commentJson(id: 'c1', authorId: _otherId, replyCount: 3)],
        replies: thread(),
        commentCount: 4,
      );
      await _pump(tester, service, me: me);
      await _tapKey(tester, 'replies_toggle_c1');
      await _tapKey(tester, 'comment_reply_r2');
      expect(find.text('Respondiendo a @otro'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('comment_composer')),
        'Claro',
      );
      await _tapKey(tester, 'comment_send');
      expect(service.calls.last, 'reply:r2:Claro');
      expect(
        find.byKey(const ValueKey('comment_reply_to_new-reply')),
        findsOneWidget,
      );
      expect(_commentCount('5'), findsOneWidget);
    });
  });
}
