import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/network/garra_error.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/engagement_utils.dart';
import 'package:garra_digital_app/features/community/data/reaction_result.dart';
import 'package:garra_digital_app/features/community/data/reaction_type.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_comment_reactions.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_comment_tile.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reaction_bar.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

WallPostModel _post({int commentCount = 2}) {
  return WallPostModel(
    id: 'post-1',
    matchId: 'm1',
    username: 'cremafan',
    fullName: 'Hincha Crema',
    content: 'Arenga de detalle',
    imageUrl: null,
    locationTag: 'STADIUM',
    status: 'ACTIVE',
    reportCount: 0,
    createdAt: DateTime.now().toIso8601String(),
    reactionSummary: emptyReactionSummary(),
    commentCount: commentCount,
  );
}

WallCommentModel _comment({
  String id = 'c1',
  String content = 'Vamos la U',
  bool isMine = true,
  String? authorId,
  String? editedAt,
  int reactionCount = 0,
  Map<String, int>? summary,
  String? myReaction,
}) {
  return WallCommentModel(
    id: id,
    postId: 'post-1',
    username: isMine ? 'yo' : 'otro',
    fullName: isMine ? 'Hincha Yo' : 'Hincha Otro',
    content: content,
    createdAt: DateTime.now().toIso8601String(),
    isMine: isMine,
    authorId: authorId,
    editedAt: editedAt,
    reactionCount: reactionCount,
    reactionSummary: summary ?? emptyReactionSummary(),
    myReaction: myReaction,
  );
}

class _FakeFan extends CurrentFanNotifier {
  _FakeFan([this.user]);
  final AuthUser? user;

  @override
  Future<AuthUser?> build() async => user;
}

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

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Dio _dio(_Adapter adapter) {
  return Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
    ..httpClientAdapter = adapter;
}

/// Fake service: every comment action is recorded. Reactions reuse the
/// optimistic math as the "server" so responses are realistic.
class _FakeService extends CommunityService {
  _FakeService({
    required this.comments,
    this.editError,
    this.serverCountOverride,
    Dio? dio,
  }) : super(dio: dio ?? Dio());

  List<WallCommentModel> comments;
  WallPostModel post = _post();
  String? failReactionWith;
  String? editError;
  int? serverCountOverride;
  Completer<void>? holdReaction;
  final List<String> calls = [];

  @override
  Future<WallPostModel> getPost(String postId) async => post;

  @override
  Future<CommentsPageResult> listComments({
    required String postId,
    String? cursor,
    int size = 20,
  }) async {
    return CommentsPageResult(
      items: List.of(comments),
      size: size,
      hasNext: false,
    );
  }

  @override
  Future<CommentActionResult> editComment({
    required String commentId,
    required String content,
  }) async {
    calls.add('edit:$commentId:$content');
    if (editError != null) return CommentActionResult.failure(editError!);
    final current = comments.firstWhere((c) => c.id == commentId);
    final updated = current.copyWith(
      content: content,
      editedAt: '2026-09-26T10:00:00Z',
    );
    return CommentActionResult.success(
      message: 'Comentario actualizado',
      comment: updated,
    );
  }

  @override
  Future<CommentActionResult> deleteComment(String commentId) async {
    calls.add('delete:$commentId');
    comments = comments.where((c) => c.id != commentId).toList();
    return CommentActionResult.success(message: 'Comentario eliminado');
  }

  Future<ReactionResult> _react(String commentId, String? type) async {
    if (holdReaction != null) await holdReaction!.future;
    if (failReactionWith != null) {
      return ReactionResult.failure(failReactionWith!);
    }
    final index = comments.indexWhere((c) => c.id == commentId);
    final next = applyOptimisticCommentReaction(comments[index], type);
    comments[index] = next;
    return ReactionResult.success(
      message: 'Reacción actualizada',
      myReaction: next.myReaction,
      reactionSummary: next.reactionSummary,
      reactionCount: serverCountOverride ?? next.reactionCount,
    );
  }

  @override
  Future<ReactionResult> upsertCommentReaction({
    required String commentId,
    required String type,
  }) {
    calls.add('upsert:$commentId:$type');
    return _react(commentId, type);
  }

  @override
  Future<ReactionResult> removeCommentReaction(String commentId) {
    calls.add('remove:$commentId');
    return _react(commentId, null);
  }
}

Widget _detail(_FakeService fake, {AuthUser? me, ThemeData? theme}) {
  return ProviderScope(
    overrides: [
      communityServiceProvider.overrideWith((ref) => fake),
      currentFanProvider.overrideWith(() => _FakeFan(me)),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      home: const PostDetailScreen(postId: 'post-1'),
    ),
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _FakeService fake, {
  AuthUser? me,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_detail(fake, me: me, theme: theme));
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester, String id) async {
  final menu = find.byKey(ValueKey('comment_menu_$id'));
  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
}

Future<void> _react(WidgetTester tester, String id, ReactionType type) async {
  final button = find.byKey(ValueKey('comment_react_$id'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(ValueKey('comment_reaction_option_${type.apiValue}')),
  );
  await tester.pumpAndSettle();
}

Finder _summaryText(String id, String text) {
  return find.descendant(
    of: find.byKey(ValueKey('comment_reaction_summary_$id')),
    matching: find.text(text),
  );
}

Finder _reactText(String id, String text) {
  return find.descendant(
    of: find.byKey(ValueKey('comment_react_$id')),
    matching: find.text(text),
  );
}

DioException _dioError(int status, Object? body) {
  final options = RequestOptions(path: '/community/comments/c1');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

Widget _tileHost(ThemeData theme, WallCommentModel comment) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GarraCommentTile(
          comment: comment,
          isOwn: true,
          onEdit: () {},
          onDelete: () {},
          onReact: () {},
        ),
      ),
    ),
  );
}

void main() {
  group('model', () {
    test('COMMENT_PARSE_REACTION_FIELDS', () {
      final full = WallCommentModel.fromJson({
        'id': 'c1',
        'postId': 'p1',
        'username': 'ana',
        'fullName': 'Ana',
        'content': 'Hola',
        'createdAt': '2026-09-25T07:00:00Z',
        'updatedAt': '2026-09-25T08:00:00Z',
        'editedAt': '2026-09-25T08:00:00Z',
        'reactionCount': 4,
        'reactionSummary': {'LOVE': 2, 'FIRE': 1, 'GARRA': 0, 'LIKE': 1},
        'myReaction': 'love',
      });
      expect(full.updatedAt, '2026-09-25T08:00:00Z');
      expect(full.editedAt, '2026-09-25T08:00:00Z');
      expect(full.isEdited, isTrue);
      expect(full.reactionCount, 4);
      expect(full.reactionSummary['LOVE'], 2);
      expect(full.reactionSummary['LIKE'], 1);
      expect(full.myReaction, 'LOVE');

      final legacy = WallCommentModel.fromJson({
        'id': 'c2',
        'postId': 'p1',
        'username': 'ana',
        'content': 'Viejo',
        'createdAt': '2026-09-25T07:00:00Z',
      });
      expect(legacy.reactionCount, 0);
      expect(legacy.reactionSummary, isEmpty);
      expect(legacy.myReaction, isNull);
      expect(legacy.editedAt, isNull);
      expect(legacy.isEdited, isFalse);

      final nulls = WallCommentModel.fromJson({
        'id': 'c3',
        'editedAt': null,
        'updatedAt': null,
        'reactionCount': null,
        'reactionSummary': null,
        'myReaction': null,
      });
      expect(nulls.reactionCount, 0);
      expect(nulls.reactionSummary, isEmpty);
      expect(nulls.myReaction, isNull);
      expect(nulls.isEdited, isFalse);
    });

    test('optimistic comment reaction add / change / remove', () {
      final base = _comment(isMine: false);
      final love = applyOptimisticCommentReaction(base, 'LOVE');
      expect(love.myReaction, 'LOVE');
      expect(love.reactionCount, 1);
      final fire = applyOptimisticCommentReaction(love, 'FIRE');
      expect(fire.myReaction, 'FIRE');
      expect(fire.reactionCount, 1);
      expect(fire.reactionSummary['LOVE'], 0);
      expect(fire.reactionSummary['FIRE'], 1);
      final removed = applyOptimisticCommentReaction(fire, 'FIRE');
      expect(removed.myReaction, isNull);
      expect(removed.reactionCount, 0);
    });
  });

  group('error mapping', () {
    test('403 never shows Access denied', () {
      final message = garraActionErrorMessage(
        _dioError(403, {'success': false, 'message': 'Access denied'}),
      );
      expect(message, 'No tienes permiso para realizar esta acción.');
      expect(message.contains('Access denied'), isFalse);
    });

    test('400 keeps backend Spanish, 429 keeps anti-abuse copy', () {
      expect(
        garraActionErrorMessage(
          _dioError(400, {
            'success': false,
            'message': 'No puedes editar un comentario que está en revisión.',
          }),
        ),
        'No puedes editar un comentario que está en revisión.',
      );
      const abuse =
          'Estás haciendo demasiadas acciones. Inténtalo nuevamente en unos segundos.';
      expect(
        garraActionErrorMessage(
          _dioError(429, {'success': false, 'message': abuse}),
        ),
        abuse,
      );
      expect(garraActionErrorMessage(_dioError(429, null)), abuse);
    });

    test('network, unknown and raw English fall back to Spanish', () {
      const fallback = 'No pudimos completar la acción. Inténtalo nuevamente.';
      expect(
        garraActionErrorMessage(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        ),
        fallback,
      );
      expect(garraActionErrorMessage(StateError('boom')), fallback);
      expect(
        garraActionErrorMessage(_dioError(400, {'message': 'Access denied'})),
        fallback,
      );
      expect(garraActionErrorMessage(_dioError(500, 'stack')), fallback);
    });
  });

  group('repository', () {
    test('editComment sends PATCH with trimmed content', () async {
      final adapter = _Adapter(
        (o) => _json(200, {
          'success': true,
          'message': 'Comentario actualizado',
          'data': {
            'id': 'c1',
            'postId': 'p1',
            'content': 'Nuevo texto',
            'createdAt': '2026-09-25T07:00:00Z',
            'editedAt': '2026-09-26T07:00:00Z',
            'reactionCount': 0,
          },
        }),
      );
      final result = await CommunityService(
        dio: _dio(adapter),
      ).editComment(commentId: 'c1', content: '  Nuevo texto  ');
      expect(result.success, isTrue);
      expect(result.message, 'Comentario actualizado');
      expect(result.comment?.content, 'Nuevo texto');
      expect(result.comment?.isEdited, isTrue);
      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.path, '/community/comments/c1');
      expect(adapter.requests.single.data, {'content': 'Nuevo texto'});
    });

    test('comment reactions use PUT and DELETE on /reaction', () async {
      final adapter = _Adapter(
        (o) => _json(200, {
          'success': true,
          'data': {
            'myReaction': o.method == 'PUT' ? 'GARRA' : null,
            'reactionSummary': {'GARRA': o.method == 'PUT' ? 1 : 0},
            'reactionCount': o.method == 'PUT' ? 1 : 0,
          },
        }),
      );
      final service = CommunityService(dio: _dio(adapter));
      final put = await service.upsertCommentReaction(
        commentId: 'c9',
        type: 'garra',
      );
      expect(put.success, isTrue);
      expect(put.myReaction, 'GARRA');
      expect(put.reactionCount, 1);
      expect(put.reactionSummary?['GARRA'], 1);
      final del = await service.removeCommentReaction('c9');
      expect(del.success, isTrue);
      expect(del.myReaction, isNull);
      expect(del.reactionCount, 0);
      expect(adapter.requests[0].method, 'PUT');
      expect(adapter.requests[0].path, '/community/comments/c9/reaction');
      expect(adapter.requests[0].data, {'type': 'GARRA'});
      expect(adapter.requests[1].method, 'DELETE');
      expect(adapter.requests[1].path, '/community/comments/c9/reaction');
    });

    test('403 on edit/delete/react maps to Spanish permission copy', () async {
      final adapter = _Adapter(
        (o) => _json(403, {'success': false, 'message': 'Access denied'}),
      );
      final service = CommunityService(dio: _dio(adapter));
      final edit = await service.editComment(commentId: 'c1', content: 'x');
      final delete = await service.deleteComment('c1');
      final react = await service.upsertCommentReaction(
        commentId: 'c1',
        type: 'LOVE',
      );
      for (final message in [edit.message, delete.message, react.message]) {
        expect(message, 'No tienes permiso para realizar esta acción.');
      }
      expect(edit.success || delete.success || react.success, isFalse);
    });
  });

  group('own comment menu', () {
    testWidgets('COMMENT_EDIT_OWN_ACTION_VISIBLE', (tester) async {
      final fake = _FakeService(comments: [_comment()]);
      await _pumpDetail(tester, fake);
      expect(find.byKey(const ValueKey('comment_menu_c1')), findsOneWidget);
      await _openMenu(tester, 'c1');
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('own comment detected by authorId fallback', (tester) async {
      final fake = _FakeService(
        comments: [_comment(isMine: false, authorId: 'fan-1')],
      );
      await _pumpDetail(
        tester,
        fake,
        me: const AuthUser(
          userId: 'fan-1',
          email: 'a@b.pe',
          username: 'yo',
          fullName: 'Hincha Yo',
          status: 'ACTIVE',
        ),
      );
      expect(find.byKey(const ValueKey('comment_menu_c1')), findsOneWidget);
    });

    testWidgets('COMMENT_EDIT_OTHER_ACTION_HIDDEN', (tester) async {
      final fake = _FakeService(
        comments: [_comment(isMine: false, authorId: 'other')],
      );
      await _pumpDetail(tester, fake);
      expect(find.byKey(const ValueKey('comment_menu_c1')), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(find.byTooltip('Opciones del comentario'), findsNothing);
      // Reactions stay available on other users' comments.
      expect(find.byKey(const ValueKey('comment_react_c1')), findsOneWidget);
    });
  });

  group('edit', () {
    testWidgets('COMMENT_EDIT_SUCCESS', (tester) async {
      final fake = _FakeService(comments: [_comment(content: 'Texto viejo')]);
      await _pumpDetail(tester, fake);
      await _openMenu(tester, 'c1');
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar comentario'), findsOneWidget);
      final field = find.byKey(const ValueKey('comment_edit_field'));
      expect(tester.widget<TextField>(field).controller!.text, 'Texto viejo');

      await tester.enterText(field, '  Texto nuevo  ');
      await tester.tap(find.byKey(const ValueKey('comment_edit_save')));
      await tester.pumpAndSettle();

      expect(fake.calls, ['edit:c1:Texto nuevo']);
      expect(find.text('Editar comentario'), findsNothing);
      expect(find.text('Texto nuevo'), findsOneWidget);
      expect(find.text('Texto viejo'), findsNothing);
      expect(find.text('Editado'), findsOneWidget);
      expect(find.text('Comentario actualizado'), findsOneWidget);
    });

    testWidgets('COMMENT_EDIT_VALIDATION_EMPTY', (tester) async {
      final fake = _FakeService(comments: [_comment()]);
      await _pumpDetail(tester, fake);
      await _openMenu(tester, 'c1');
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('comment_edit_field')),
        '    ',
      );
      await tester.pump();
      expect(find.text('El comentario no puede estar vacío.'), findsOneWidget);
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('comment_edit_save')),
      );
      expect(save.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('comment_edit_save')));
      await tester.pump();
      expect(fake.calls, isEmpty);

      await tester.tap(find.byKey(const ValueKey('comment_edit_cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Editar comentario'), findsNothing);
      expect(find.text('Vamos la U'), findsOneWidget);
      expect(fake.calls, isEmpty);
    });

    testWidgets('COMMENT_EDIT_MAX_LENGTH', (tester) async {
      final fake = _FakeService(comments: [_comment()]);
      await _pumpDetail(tester, fake);
      await _openMenu(tester, 'c1');
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('comment_edit_field'));
      await tester.enterText(field, 'a' * 600);
      await tester.pump();
      final controller = tester.widget<TextField>(field).controller!;
      expect(controller.text.length, commentEditMaxLength);
      expect(tester.widget<TextField>(field).maxLength, 500);
      expect(find.text('500/500'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('comment_edit_save')));
      await tester.pumpAndSettle();
      expect(fake.calls.single, 'edit:c1:${'a' * 500}');
    });

    testWidgets('edit shows backend Spanish error and keeps sheet', (
      tester,
    ) async {
      final fake = _FakeService(
        comments: [_comment()],
        editError: 'No puedes editar un comentario que está en revisión.',
      );
      await _pumpDetail(tester, fake);
      await _openMenu(tester, 'c1');
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('comment_edit_field')),
        'Otro texto',
      );
      await tester.tap(find.byKey(const ValueKey('comment_edit_save')));
      await tester.pumpAndSettle();
      expect(
        find.text('No puedes editar un comentario que está en revisión.'),
        findsOneWidget,
      );
      expect(find.text('Editar comentario'), findsOneWidget);
      expect(find.text('Editado'), findsNothing);
    });
  });

  group('delete', () {
    testWidgets('COMMENT_DELETE_CONFIRMATION', (tester) async {
      final fake = _FakeService(comments: [_comment()]);
      await _pumpDetail(tester, fake);
      await _openMenu(tester, 'c1');
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar comentario?'), findsOneWidget);
      expect(
        find.text('Esta acción quitará tu comentario de la publicación.'),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('comment_delete_confirm')),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
      expect(find.text('Vamos la U'), findsOneWidget);
    });

    testWidgets('COMMENT_DELETE_SUCCESS', (tester) async {
      final fake = _FakeService(
        comments: [
          _comment(),
          _comment(id: 'c2', content: 'Otro', isMine: false),
        ],
      );
      await _pumpDetail(tester, fake);
      final bar = find.byType(GarraReactionBar);
      expect(find.descendant(of: bar, matching: find.text('2')), findsOne);

      await _openMenu(tester, 'c1');
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('comment_delete_confirm')));
      await tester.pumpAndSettle();

      expect(fake.calls, ['delete:c1']);
      expect(find.text('Vamos la U'), findsNothing);
      expect(find.byKey(const ValueKey('comment_tile_c1')), findsNothing);
      expect(find.text('Otro'), findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('1')), findsOne);
      expect(find.text('Comentario eliminado'), findsOneWidget);
    });
  });

  group('reactions', () {
    testWidgets('COMMENT_REACTION_PICKER', (tester) async {
      final semantics = tester.ensureSemantics();
      final fake = _FakeService(comments: [_comment(isMine: false)]);
      await _pumpDetail(tester, fake);
      expect(_reactText('c1', 'Reaccionar'), findsOneWidget);
      // Zero reactions: no noisy counter.
      expect(_summaryText('c1', '0'), findsNothing);
      expect(find.textContaining('0 reacciones'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('comment_react_c1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('comment_reaction_picker')),
        findsOneWidget,
      );
      for (final key in ['LOVE', 'FIRE', 'GARRA']) {
        expect(
          find.byKey(ValueKey('comment_reaction_option_$key')),
          findsOneWidget,
        );
      }
      for (final key in ['LIKE', 'ANGER', 'SAD']) {
        expect(
          find.byKey(ValueKey('comment_reaction_option_$key')),
          findsNothing,
        );
      }
      expect(find.bySemanticsLabel('Me encanta'), findsOneWidget);
      expect(find.bySemanticsLabel('Fuego'), findsOneWidget);
      expect(find.bySemanticsLabel('Garra'), findsOneWidget);
      expect(find.text('Me gusta'), findsNothing);
      expect(find.text('Me enoja'), findsNothing);
      expect(find.text('Me entristece'), findsNothing);
      semantics.dispose();
    });

    for (final type in commentReactionTypes) {
      final label = commentReactionLabel(type);
      testWidgets('COMMENT_REACTION_${type.apiValue}', (tester) async {
        final fake = _FakeService(comments: [_comment(isMine: false)]);
        await _pumpDetail(tester, fake);
        await _react(tester, 'c1', type);

        expect(fake.calls, ['upsert:c1:${type.apiValue}']);
        expect(_reactText('c1', label), findsOneWidget);
        expect(_reactText('c1', 'Reaccionar'), findsNothing);
        expect(_summaryText('c1', '1'), findsOneWidget);
      });
    }

    testWidgets('COMMENT_REACTION_CHANGE', (tester) async {
      final fake = _FakeService(
        comments: [
          _comment(
            isMine: false,
            myReaction: 'LOVE',
            reactionCount: 3,
            summary: {'LOVE': 2, 'FIRE': 1},
          ),
        ],
      );
      await _pumpDetail(tester, fake);
      expect(_reactText('c1', 'Me encanta'), findsOneWidget);
      await _react(tester, 'c1', ReactionType.fire);

      expect(fake.calls, ['upsert:c1:FIRE']);
      expect(_reactText('c1', 'Fuego'), findsOneWidget);
      expect(_summaryText('c1', '3'), findsOneWidget);
      expect(fake.comments.single.reactionSummary['FIRE'], 2);
      expect(fake.comments.single.reactionSummary['LOVE'], 1);
    });

    testWidgets('COMMENT_REACTION_REMOVE_SAME', (tester) async {
      final fake = _FakeService(
        comments: [
          _comment(
            isMine: false,
            myReaction: 'GARRA',
            reactionCount: 1,
            summary: {'GARRA': 1},
          ),
        ],
      );
      await _pumpDetail(tester, fake);
      expect(_reactText('c1', 'Garra'), findsOneWidget);
      await _react(tester, 'c1', ReactionType.garra);

      expect(fake.calls, ['remove:c1']);
      expect(_reactText('c1', 'Reaccionar'), findsOneWidget);
      expect(_summaryText('c1', '1'), findsNothing);
      expect(_summaryText('c1', '0'), findsNothing);
    });

    testWidgets('COMMENT_REACTION_COUNT_UPDATE', (tester) async {
      final fake = _FakeService(
        comments: [
          _comment(isMine: false, reactionCount: 5, summary: {'FIRE': 5}),
        ],
        serverCountOverride: 9,
      );
      await _pumpDetail(tester, fake);
      expect(_summaryText('c1', '5'), findsOneWidget);
      await _react(tester, 'c1', ReactionType.love);
      // Server response is the source of truth.
      expect(_summaryText('c1', '9'), findsOneWidget);
      expect(_summaryText('c1', '6'), findsNothing);
    });

    testWidgets('COMMENT_REACTION_ERROR_ROLLBACK', (tester) async {
      final adapter = _Adapter(
        (o) => _json(403, {'success': false, 'message': 'Access denied'}),
      );
      final fake = _RealReactionService(
        comments: [_comment(isMine: false)],
        realDio: _dio(adapter),
      );
      await _pumpDetail(tester, fake);
      await _react(tester, 'c1', ReactionType.garra);

      expect(adapter.requests.single.method, 'PUT');
      expect(_reactText('c1', 'Reaccionar'), findsOneWidget);
      expect(_summaryText('c1', '1'), findsNothing);
      expect(
        find.text('No tienes permiso para realizar esta acción.'),
        findsOneWidget,
      );
      expect(find.textContaining('Access denied'), findsNothing);
    });

    testWidgets('in-flight guard blocks duplicate reaction requests', (
      tester,
    ) async {
      final fake = _FakeService(comments: [_comment(isMine: false)])
        ..holdReaction = Completer<void>();
      await _pumpDetail(tester, fake);
      await _react(tester, 'c1', ReactionType.fire);
      // Optimistic state is visible while the request is in flight.
      expect(_reactText('c1', 'Fuego'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('comment_react_c1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('comment_reaction_picker')),
        findsNothing,
      );
      fake.holdReaction!.complete();
      await tester.pumpAndSettle();
      expect(fake.calls, ['upsert:c1:FIRE']);
      expect(_reactText('c1', 'Fuego'), findsOneWidget);
    });
  });

  group('themes and branding', () {
    final reacted = _comment(
      myReaction: 'GARRA',
      reactionCount: 3,
      summary: {'GARRA': 2, 'LOVE': 1},
      editedAt: '2026-09-26T10:00:00Z',
    );

    Color? textColor(WidgetTester tester, String text) {
      return tester.widget<Text>(find.text(text)).style?.color;
    }

    Color clawColor(WidgetTester tester) {
      final glyph = tester.widget<GarraClawReactionGlyph>(
        find
            .descendant(
              of: find.byKey(const ValueKey('comment_react_c1')),
              matching: find.byType(GarraClawReactionGlyph),
            )
            .first,
      );
      return glyph.color;
    }

    testWidgets('COMMENT_THEME_CREMA', (tester) async {
      const colors = GarraSemanticColors.crema;
      await tester.pumpWidget(_tileHost(AppTheme.lightTheme, reacted));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(textColor(tester, 'Hincha Yo'), colors.textPrimary);
      expect(textColor(tester, 'Vamos la U'), colors.textPrimary);
      expect(textColor(tester, 'Garra'), colors.textPrimary);
      expect(textColor(tester, 'Editado'), colors.textSecondary);
      expect(clawColor(tester), colors.brandPrimary);
      expect(find.byKey(const ValueKey('comment_edited_c1')), findsOneWidget);
      expect(_summaryText('c1', '3'), findsOneWidget);
    });

    testWidgets('COMMENT_THEME_NOCHE', (tester) async {
      const colors = GarraSemanticColors.noche;
      await tester.pumpWidget(_tileHost(AppTheme.darkTheme, reacted));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(textColor(tester, 'Hincha Yo'), colors.textPrimary);
      expect(textColor(tester, 'Vamos la U'), colors.textPrimary);
      expect(textColor(tester, 'Garra'), colors.textPrimary);
      expect(textColor(tester, 'Editado'), colors.textSecondary);
      expect(clawColor(tester), colors.brandPrestige);
    });

    testWidgets('unselected react label uses semantic secondary text', (
      tester,
    ) async {
      for (final entry in {
        AppTheme.lightTheme: GarraSemanticColors.crema,
        AppTheme.darkTheme: GarraSemanticColors.noche,
      }.entries) {
        await tester.pumpWidget(_tileHost(entry.key, _comment()));
        await tester.pumpAndSettle();
        expect(textColor(tester, 'Reaccionar'), entry.value.textSecondary);
      }
    });

    testWidgets('narrow comment tile does not overflow', (tester) async {
      tester.view.physicalSize = const Size(300, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _tileHost(
          AppTheme.lightTheme,
          _comment(
            content: 'Texto largo ' * 20,
            myReaction: 'LOVE',
            reactionCount: 120,
            summary: {'LOVE': 60, 'FIRE': 40, 'GARRA': 20},
            editedAt: '2026-09-26T10:00:00Z',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('GARRA_REACTION_NOT_GENERIC_EMOJI', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: GarraCommentReactionPicker()),
        ),
      );
      final garraOption = find.byKey(
        const ValueKey('comment_reaction_option_GARRA'),
      );
      final claw = find.descendant(
        of: garraOption,
        matching: find.byType(GarraClawReactionGlyph),
      );
      expect(claw, findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.descendant(of: claw, matching: find.byType(CustomPaint)),
      );
      expect(paint.painter, isA<GarraClawReactionPainter>());
      for (final emoji in ['🐾', '🛡', '✋', '🤚', '👋', '🐯', '🦁']) {
        expect(find.textContaining(emoji), findsNothing);
      }
      // No emoji glyphs anywhere in the comment picker.
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        final value = text.data ?? '';
        expect(value.runes.every((r) => r < 0x2190), isTrue, reason: value);
      }
      // Heart and flame are vector icons too.
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });

    testWidgets('legacy reaction types still render a safe count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _tileHost(
          AppTheme.darkTheme,
          _comment(reactionCount: 2, summary: {'LIKE': 1, 'SAD': 1}),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_summaryText('c1', '2'), findsOneWidget);
      expect(find.text('👍'), findsNothing);
    });
  });
}

/// Uses the real CommunityService reaction call (through a fake Dio
/// adapter) so the Spanish error mapping is exercised end to end.
class _RealReactionService extends _FakeService {
  _RealReactionService({required super.comments, required this.realDio})
    : super(dio: realDio);

  final Dio realDio;

  @override
  Future<ReactionResult> upsertCommentReaction({
    required String commentId,
    required String type,
  }) {
    calls.add('upsert:$commentId:$type');
    return CommunityService(
      dio: realDio,
    ).upsertCommentReaction(commentId: commentId, type: type);
  }
}
