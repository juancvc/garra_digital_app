import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reaction_bar.dart';

// Staging-shaped payloads (backend DTOs: AuthMeResponse, PostCommentResponse,
// WallPostResponse). Jackson serializes UUIDs as lowercase strings.
const _meId = '3f0c8a52-7d1e-4c55-9b0e-2a41f6c1d9aa';
const _otherId = '9b2d7e11-0c4f-4a8e-8f3a-5d6e7f8a9b0c';

Map<String, dynamic> _authMeJson() => {
  'id': _meId,
  'email': 'hincha@garra.pe',
  'username': 'yo',
  'fullName': 'Hincha Yo',
  'phone': null,
  'favoriteStand': 'NORTE',
  'favoritePlayer': null,
  'loyaltyPoints': 120,
  'status': 'ACTIVE',
  'role': 'USER',
};

Map<String, dynamic> _commentJson({
  required String id,
  required String authorId,
  String content = 'Vamos la U',
  String? editedAt,
}) => {
  'id': id,
  'postId': 'b1c2d3e4-0000-4000-8000-000000000001',
  'username': authorId == _meId ? 'yo' : 'otro',
  'fullName': authorId == _meId ? 'Hincha Yo' : 'Hincha Otro',
  'content': content,
  'status': 'ACTIVE',
  'createdAt': '2026-09-26T20:00:00Z',
  'authorId': authorId,
  'avatarUrl': null,
  'updatedAt': editedAt,
  'editedAt': editedAt,
  'reactionCount': 0,
  'reactionSummary': {
    'LIKE': 0,
    'LOVE': 0,
    'FIRE': 0,
    'ANGER': 0,
    'SAD': 0,
    'GARRA': 0,
  },
  'myReaction': null,
};

WallPostModel _post({int commentCount = 2}) => WallPostModel.fromJson({
  'id': 'b1c2d3e4-0000-4000-8000-000000000001',
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
  _Service(this.commentsJson) : super(dio: Dio());

  List<Map<String, dynamic>> commentsJson;
  WallPostModel post = _post();
  Completer<void>? holdDelete;
  bool failDelete = false;
  final List<String> calls = [];

  @override
  Future<WallPostModel> getPost(String postId) async => post;

  @override
  Future<CommentsPageResult> listComments({
    required String postId,
    String? cursor,
    int size = 20,
  }) async {
    return CommentsPageResult.fromJson({
      'items': commentsJson,
      'page': {'size': size, 'hasNext': false, 'nextCursor': null},
    });
  }

  @override
  Future<CommentActionResult> deleteComment(String commentId) async {
    calls.add('delete:$commentId');
    if (holdDelete != null) await holdDelete!.future;
    if (failDelete) {
      return CommentActionResult.failure(
        'No tienes permiso para realizar esta acción.',
      );
    }
    return CommentActionResult.success(message: 'Comentario eliminado');
  }

  @override
  Future<CommentActionResult> editComment({
    required String commentId,
    required String content,
  }) async {
    calls.add('edit:$commentId:$content');
    return CommentActionResult.success(
      message: 'Comentario actualizado',
      comment: WallCommentModel.fromJson(
        _commentJson(
          id: commentId,
          authorId: _meId,
          content: content,
          editedAt: '2026-09-26T21:00:00Z',
        ),
      ),
    );
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
        home: const PostDetailScreen(
          postId: 'b1c2d3e4-0000-4000-8000-000000000001',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _commentCount(String value) => find.descendant(
  of: find.byType(GarraReactionBar),
  matching: find.text(value),
);

class _ProfileCommunity extends CommunityService {
  _ProfileCommunity(this.profile) : super(dio: Dio());
  final Map<String, dynamic> profile;

  @override
  Future<Map<String, dynamic>> getPublicProfile(String userId) async => profile;
}

class _Chat extends ChatService {
  _Chat() : super(dio: Dio());

  @override
  Future<ChatRelationship> relationship(
    String userId, {
    String context = 'SOCIAL',
  }) async => ChatRelationship.none();
}

// PublicFanProfileResponse shape.
Map<String, dynamic> _profileJson({required bool isMe}) => {
  'id': isMe ? _meId : _otherId,
  'username': 'anaq',
  'displayName': 'Ana Quispe',
  'avatarUrl': null,
  'levelNumber': 3,
  'levelName': 'Hincha Fiel',
  'memberSince': '2025-03-14T15:00:00Z',
  'followerCount': 128,
  'followingCount': 45,
  'globalPostCount': 12,
  'isFollowedByMe': false,
  'isBlockedByMe': false,
  'isMe': isMe,
  'globalPosts': const [],
};

Widget _profileApp(ThemeData theme, {required bool isMe}) => MaterialApp(
  theme: theme,
  home: PublicFanProfilePage(
    userId: isMe ? _meId : _otherId,
    communityService: _ProfileCommunity(_profileJson(isMe: isMe)),
    chatService: _Chat(),
  ),
);

void main() {
  final me = AuthUser.fromJson(_authMeJson());

  group('COMMENT_DELETE_OWNERSHIP (root cause)', () {
    test('GET /auth/me `id` is parsed as the session fan id', () {
      expect(me.id, _meId);
      // Login/refresh shape keeps working.
      final login = AuthUser.fromJson({'userId': _meId, 'username': 'yo'});
      expect(login.id, _meId);
    });

    test('staging comment payload has no isMine; authorId is the key', () {
      final comment = WallCommentModel.fromJson(
        _commentJson(id: 'c1', authorId: _meId),
      );
      expect(comment.isMine, isFalse);
      expect(isSameFanId(me.id, comment.authorId), isTrue);
      expect(isSameFanId(me.id, _meId.toUpperCase()), isTrue);
      expect(isSameFanId('', ''), isFalse);
      expect(isSameFanId(null, _meId), isFalse);
    });

    testWidgets('own staging comment shows Editar/Eliminar', (tester) async {
      final service = _Service([
        _commentJson(id: 'c1', authorId: _meId),
        _commentJson(id: 'c2', authorId: _otherId, content: 'Ajeno'),
      ]);
      await _pump(tester, service, me: me);
      expect(find.byKey(const ValueKey('comment_menu_c1')), findsOneWidget);
      // MODERATION_11: someone else's comment now has a report-only menu.
      expect(find.byKey(const ValueKey('comment_menu_c2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('comment_menu_c1')));
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('without a session id no comment is treated as own', (
      tester,
    ) async {
      final service = _Service([_commentJson(id: 'c1', authorId: _meId)]);
      await _pump(tester, service);
      expect(find.byKey(const ValueKey('comment_menu_c1')), findsNothing);
    });

    testWidgets('delete removes only after backend confirms, count -1 once', (
      tester,
    ) async {
      final service = _Service([
        _commentJson(id: 'c1', authorId: _meId),
        _commentJson(id: 'c2', authorId: _otherId, content: 'Ajeno'),
      ])..holdDelete = Completer<void>();
      await _pump(tester, service, me: me);
      expect(_commentCount('2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('comment_menu_c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar comentario?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('comment_delete_confirm')));
      await tester.pump();

      // Pending backend: still visible, count unchanged.
      expect(service.calls, ['delete:c1']);
      expect(find.text('Vamos la U'), findsOneWidget);
      expect(_commentCount('2'), findsOneWidget);

      service.holdDelete!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Vamos la U'), findsNothing);
      expect(find.text('Ajeno'), findsOneWidget);
      expect(_commentCount('1'), findsOneWidget);
      expect(find.text('Comentario eliminado'), findsOneWidget);
    });

    testWidgets('failed delete keeps comment and count, shows Spanish error', (
      tester,
    ) async {
      final service = _Service([_commentJson(id: 'c1', authorId: _meId)])
        ..failDelete = true;
      await _pump(tester, service, me: me);
      await tester.tap(find.byKey(const ValueKey('comment_menu_c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('comment_delete_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Vamos la U'), findsOneWidget);
      expect(_commentCount('2'), findsOneWidget);
      expect(
        find.text('No tienes permiso para realizar esta acción.'),
        findsOneWidget,
      );
    });

    testWidgets('COMMENT_EDIT_DEVICE: Editar works on staging comment', (
      tester,
    ) async {
      final service = _Service([_commentJson(id: 'c1', authorId: _meId)]);
      await _pump(tester, service, me: me);
      await tester.tap(find.byKey(const ValueKey('comment_menu_c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('comment_edit_field')),
        'Vamos la U, siempre',
      );
      await tester.tap(find.byKey(const ValueKey('comment_edit_save')));
      await tester.pumpAndSettle();
      expect(service.calls, ['edit:c1:Vamos la U, siempre']);
      expect(find.text('Vamos la U, siempre'), findsOneWidget);
      expect(find.text('Editado'), findsOneWidget);
    });
  });

  group('POST_ACTIONS', () {
    testWidgets('Reaccionar | Comentar | Compartir row', (tester) async {
      final service = _Service([]);
      await _pump(tester, service, me: me);
      expect(find.byKey(const ValueKey('post_action_row')), findsOneWidget);
      expect(find.byKey(const ValueKey('reaction_cta')), findsOneWidget);
      expect(find.text('Comentar'), findsWidgets);
      expect(find.text('Compartir'), findsOneWidget);
      // Share lives in the action row only (no duplicate app bar icon).
      expect(find.byTooltip('Compartir'), findsNothing);
      // No fake share counter.
      expect(find.textContaining('compartido'), findsNothing);
    });

    testWidgets('Compartir opens the existing share sheet', (tester) async {
      final service = _Service([]);
      await _pump(tester, service, me: me);
      await tester.tap(find.byKey(const ValueKey('post_action_share')));
      await tester.pumpAndSettle();
      expect(find.text('Compartir texto'), findsOneWidget);
      expect(find.text('Compartir tarjeta'), findsOneWidget);
    });

    testWidgets('Comentar focuses the composer', (tester) async {
      final service = _Service([]);
      await _pump(tester, service, me: me);
      await tester.tap(find.byKey(const ValueKey('post_action_comment')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('comment_composer')),
      );
      expect(field.focusNode?.hasFocus, isTrue);
    });

    testWidgets('post text uses semantic color in Crema', (tester) async {
      final service = _Service([]);
      await _pump(tester, service, me: me, theme: AppTheme.lightTheme);
      final text = tester.widget<Text>(find.text('Arenga de detalle'));
      expect(text.style?.color, GarraSemanticColors.crema.textPrimary);
      expect(tester.takeException(), isNull);
    });
  });

  group('PROFILE_V1', () {
    testWidgets('other fan: identity, stats, Seguir + Mensaje', (tester) async {
      await tester.pumpWidget(_profileApp(AppTheme.darkTheme, isMe: false));
      await tester.pumpAndSettle();
      expect(find.text('Ana Quispe'), findsOneWidget);
      expect(find.text('@anaq'), findsOneWidget);
      expect(find.text('En Garra desde 2025'), findsOneWidget);
      expect(find.textContaining('Hincha Fiel'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Seguir'), findsOneWidget);
      expect(find.text('Mensaje'), findsOneWidget);
      expect(find.text('Editar perfil'), findsNothing);
      for (final sensitive in ['hincha@garra.pe', 'Teléfono', 'Dirección']) {
        expect(find.textContaining(sensitive), findsNothing);
      }
    });

    testWidgets('own profile: Editar perfil, no Mensaje/Seguir', (
      tester,
    ) async {
      await tester.pumpWidget(_profileApp(AppTheme.darkTheme, isMe: true));
      await tester.pumpAndSettle();
      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Mensaje'), findsNothing);
      expect(find.text('Seguir'), findsNothing);
    });

    for (final entry in {
      'CREMA': (() => AppTheme.lightTheme, GarraSemanticColors.crema),
      'NOCHE': (() => AppTheme.darkTheme, GarraSemanticColors.noche),
    }.entries) {
      testWidgets('profile uses semantic colors (${entry.key})', (
        tester,
      ) async {
        final (theme, colors) = entry.value;
        await tester.pumpWidget(_profileApp(theme(), isMe: false));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, colors.background);
        expect(
          tester.widget<Text>(find.text('Ana Quispe')).style?.color,
          colors.textPrimary,
        );
        expect(
          tester.widget<Text>(find.text('128')).style?.color,
          colors.textPrimary,
        );
      });
    }
  });
}
