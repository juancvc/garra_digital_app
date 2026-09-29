import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/garra_error.dart';
import 'community_report.dart';
import 'create_wall_post_request.dart';
import 'reaction_result.dart';
import 'reactor_model.dart';
import 'report_wall_post_request.dart';
import 'wall_comment_model.dart';
import 'wall_post_model.dart';
import 'wall_status_model.dart';

/// ANALYTICS_12: result of POST /community/posts/{id}/view.
class PostViewResult {
  const PostViewResult({required this.counted, required this.viewCount});

  final bool counted;
  final int viewCount;
}

class CommunityService {
  CommunityService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  String _normalizeWallError(String message) {
    if (message.contains('Maximum posts per user')) {
      return 'Ya alcanzaste el máximo de 3 publicaciones para este partido';
    }

    if (message.contains('Wall is not open')) {
      return 'El muro no está abierto para este partido';
    }

    return message;
  }

  String _dioMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ?? fallback;
    }
    return fallback;
  }

  String _commentConfirmation(String? message) {
    if (message == null || message.isEmpty || message == 'Comment created') {
      return 'Comentario publicado';
    }
    return message;
  }

  final Dio _dio;

  Future<WallStatusModel?> getCurrentWallStatus() async {
    final response = await _dio.get('/community/wall/status/current');
    final data = response.data['data'];

    if (data == null) {
      return null;
    }

    return WallStatusModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<WallPostModel>> getPosts({
    required String matchId,
    String? locationTag,
  }) async {
    final response = await _dio.get(
      '/community/wall/$matchId/posts',
      queryParameters: locationTag != null && locationTag != 'ALL'
          ? {'locationTag': locationTag}
          : null,
    );

    final List data = response.data['data'] ?? [];

    return data
        .map((e) => WallPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WallPostModel> getPost(String postId) async {
    final response = await _dio.get('/community/posts/$postId');
    final data = response.data['data'] ?? response.data;
    return WallPostModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<WallActionResult> createPost(CreateWallPostRequest request) async {
    try {
      final response = await _dio.post(
        '/community/wall/posts',
        data: request.toJson(),
      );

      final data = response.data['data'];

      return WallActionResult.success(
        message: response.data['message']?.toString() ?? 'Publicación creada',
        post: data is Map<String, dynamic>
            ? WallPostModel.fromJson(data)
            : null,
      );
    } on DioException catch (e) {
      return WallActionResult.failure(
        _normalizeWallError(_dioMessage(e, 'No se pudo publicar en el muro')),
      );
    } catch (_) {
      return WallActionResult.failure('Ocurrió un error inesperado');
    }
  }

  Future<List<WallPostModel>> getMyPosts() async {
    final response = await _dio.get('/community/wall/my-posts');
    final List data = response.data['data'] ?? [];

    return data
        .map((e) => WallPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WallActionResult> reportPost({
    required String postId,
    required String reason,
    String category = 'OTHER',
  }) async {
    try {
      final response = await _dio.post(
        '/community/wall/posts/$postId/report',
        data: ReportWallPostRequest(
          category: category,
          reason: reason,
        ).toJson(),
      );

      final data = response.data['data'];

      return WallActionResult.success(
        message: response.data['message']?.toString() ?? 'Reportado. Gracias.',
        post: data is Map<String, dynamic>
            ? WallPostModel.fromJson(data)
            : null,
      );
    } on DioException catch (e) {
      return WallActionResult.failure(
        _dioMessage(e, 'No se pudo reportar la publicación'),
      );
    } catch (_) {
      return WallActionResult.failure('Ocurrió un error inesperado');
    }
  }

  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async {
    final response = await _dio.get(
      '/community/feed',
      queryParameters: {'mode': mode},
    );
    final List data = response.data['data'] ?? [];
    return data
        .map((e) => WallPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> followUser(String userId) async {
    await _dio.post('/community/users/$userId/follow');
  }

  Future<void> unfollowUser(String userId) async {
    await _dio.delete('/community/users/$userId/follow');
  }

  Future<void> savePost(String postId) async {
    await _dio.post('/community/posts/$postId/save');
  }

  Future<void> unsavePost(String postId) async {
    await _dio.delete('/community/posts/$postId/save');
  }

  Future<List<WallPostModel>> listSaved() async {
    final response = await _dio.get('/community/saved/me');
    final List data = response.data['data'] ?? [];
    return data
        .map((e) => WallPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> discoveryPeople() async {
    final response = await _dio.get('/community/discovery/people');
    final List data = response.data['data'] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> deleteOwnPost(String postId) async {
    await _dio.delete('/community/posts/$postId');
  }

  Future<Map<String, dynamic>> globalSearch(String q, {String? type}) async {
    final response = await _dio.get(
      '/search',
      queryParameters: {
        'q': q,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<WallActionResult> createGlobalPost({
    required String content,
    String? mediaAssetId,
    List<String>? mediaAssetIds,
    String? locationTag,
  }) async {
    try {
      final ids = <String>[
        ...?mediaAssetIds,
        if (mediaAssetId != null &&
            (mediaAssetIds == null || !mediaAssetIds.contains(mediaAssetId)))
          mediaAssetId,
      ];
      final response = await _dio.post(
        '/community/posts',
        data: {
          'content': content,
          if (ids.length == 1) 'mediaAssetId': ids.first,
          if (ids.isNotEmpty) 'mediaAssetIds': ids,
          if (locationTag != null) 'locationTag': locationTag,
        },
      );
      final data = response.data['data'];
      return WallActionResult.success(
        message: response.data['message']?.toString() ?? 'Publicado',
        post: data is Map<String, dynamic>
            ? WallPostModel.fromJson(data)
            : null,
      );
    } on DioException catch (e) {
      return WallActionResult.failure(_dioMessage(e, 'No se pudo publicar'));
    } catch (_) {
      return WallActionResult.failure('Ocurrió un error inesperado');
    }
  }

  Future<WallActionResult> shareGlobalPost(String postId) async {
    try {
      final response = await _dio.post('/community/posts/$postId/share');
      final data = response.data['data'];
      return WallActionResult.success(
        message: response.data['message']?.toString() ?? 'Compartido en Garra',
        post: data is Map ? WallPostModel.fromJson(Map<String, dynamic>.from(data)) : null,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return WallActionResult.failure('La publicación original ya no está disponible');
      }
      return WallActionResult.failure(_dioMessage(e, 'No pudimos compartir la publicación'));
    } catch (_) {
      return WallActionResult.failure('No pudimos compartir la publicación');
    }
  }

  Future<int?> undoGlobalShare(String postId) async {
    final response = await _dio.delete('/community/posts/$postId/share');
    return (response.data['data'] as num?)?.toInt();
  }

  Future<void> blockUser(String userId) async {
    await _dio.post('/community/users/$userId/block');
  }

  Future<void> unblockUser(String userId) async {
    await _dio.delete('/community/users/$userId/block');
  }

  Future<List<Map<String, dynamic>>> listBlocks() async {
    final response = await _dio.get('/community/blocks/me');
    final List data = response.data['data'] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getPublicProfile(String userId) async {
    final response = await _dio.get('/community/users/$userId/profile');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  /// ANALYTICS_12: registers a real view of someone else's post. The backend
  /// dedupes per viewer+post (rolling 24h) and ignores the author's own views.
  /// Best-effort: never throws; returns null when the request fails.
  Future<PostViewResult?> registerPostView(String postId) async {
    try {
      final response = await _dio.post('/community/posts/$postId/view');
      final body = response.data;
      final data = body is Map ? (body['data'] ?? body) : null;
      if (data is! Map) return null;
      return PostViewResult(
        counted: data['counted'] == true,
        viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// ANALYTICS_12: registers a visit to someone else's public profile. The
  /// response never carries the total (only the owner sees it). Best-effort.
  Future<bool> registerProfileView(String userId) async {
    try {
      final response = await _dio.post('/community/users/$userId/view');
      final body = response.data;
      final data = body is Map ? (body['data'] ?? body) : null;
      return data is Map && data['counted'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<ReactionResult> upsertReaction({
    required String postId,
    required String type,
  }) async {
    try {
      final response = await _dio.put(
        '/community/posts/$postId/reaction',
        data: {'type': type.toUpperCase()},
      );

      final payload = response.data['data'] ?? response.data;
      if (payload is Map<String, dynamic>) {
        return ReactionResult.fromPayload(
          payload,
          message:
              response.data['message']?.toString() ?? 'Reacción actualizada',
        );
      }

      return ReactionResult.success(message: 'Reacción actualizada');
    } on DioException catch (e) {
      return ReactionResult.failure(
        _dioMessage(e, 'No se pudo registrar la reacción'),
      );
    } catch (_) {
      return ReactionResult.failure('Ocurrió un error inesperado');
    }
  }

  Future<ReactionResult> removeReaction(String postId) async {
    try {
      final response = await _dio.delete('/community/posts/$postId/reaction');
      final payload = response.data['data'] ?? response.data;

      if (payload is Map<String, dynamic>) {
        return ReactionResult.fromPayload(
          payload,
          message: response.data['message']?.toString() ?? 'Reacción eliminada',
        );
      }

      return ReactionResult.success(
        message: 'Reacción eliminada',
        myReaction: null,
        reactionSummary: null,
        reactionCount: 0,
      );
    } on DioException catch (e) {
      return ReactionResult.failure(
        _dioMessage(e, 'No se pudo quitar la reacción'),
      );
    } catch (_) {
      return ReactionResult.failure('Ocurrió un error inesperado');
    }
  }

  Future<CommentsPageResult> listComments({
    required String postId,
    String? cursor,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/community/posts/$postId/comments',
      queryParameters: {
        'size': size,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    final payload = response.data['data'] ?? response.data;
    return CommentsPageResult.fromJson(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<CommentActionResult> createComment({
    required String postId,
    required String content,
  }) async {
    try {
      final response = await _dio.post(
        '/community/posts/$postId/comments',
        data: {'content': content},
      );

      final data = response.data['data'];
      return CommentActionResult.success(
        message: _commentConfirmation(response.data['message']?.toString()),
        comment: data is Map
            ? WallCommentModel.fromJson(Map<String, dynamic>.from(data))
            : null,
      );
    } on DioException catch (e) {
      return CommentActionResult.failure(
        _dioMessage(e, 'No se pudo publicar el comentario'),
      );
    } catch (_) {
      return CommentActionResult.failure('Ocurrió un error inesperado');
    }
  }

  /// Reply to [parentCommentId] (a root or a reply: the backend resolves the
  /// thread root and the "@usuario" target). Same content rules as comments.
  Future<CommentActionResult> createReply({
    required String postId,
    required String parentCommentId,
    required String content,
  }) async {
    try {
      final response = await _dio.post(
        '/community/posts/$postId/comments',
        data: {'content': content, 'parentCommentId': parentCommentId},
      );
      final data = response.data['data'];
      return CommentActionResult.success(
        message: 'Respuesta publicada',
        comment: data is Map
            ? WallCommentModel.fromJson(Map<String, dynamic>.from(data))
            : null,
      );
    } catch (e) {
      return CommentActionResult.failure(
        garraActionErrorMessage(e, notFoundMessage: _commentGoneMessage),
        notFound: e is DioException && e.response?.statusCode == 404,
      );
    }
  }

  /// Who reacted to a post, newest first (cursor pagination, max 50/page).
  Future<ReactorsPage> getPostReactors(
    String postId, {
    String? cursor,
    int size = 30,
  }) => _reactors('/community/posts/$postId/reactions', cursor, size);

  /// Who reacted to a comment or reply (same reaction system as posts).
  Future<ReactorsPage> getCommentReactors(
    String commentId, {
    String? cursor,
    int size = 30,
  }) => _reactors('/community/comments/$commentId/reactions', cursor, size);

  Future<ReactorsPage> _reactors(String path, String? cursor, int size) async {
    final response = await _dio.get(
      path,
      queryParameters: {
        'size': size,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final payload = response.data['data'] ?? response.data;
    return ReactorsPage.fromJson(Map<String, dynamic>.from(payload as Map));
  }

  /// Replies of a root comment, oldest first (cursor pagination).
  Future<CommentsPageResult> fetchReplies({
    required String commentId,
    String? cursor,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/community/comments/$commentId/replies',
      queryParameters: {
        'size': size,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final payload = response.data['data'] ?? response.data;
    return CommentsPageResult.fromJson(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<CommentActionResult> editComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final response = await _dio.patch(
        '/community/comments/$commentId',
        data: {'content': content.trim()},
      );
      final data = response.data is Map ? response.data['data'] : null;
      return CommentActionResult.success(
        message: 'Comentario actualizado',
        comment: data is Map
            ? WallCommentModel.fromJson(Map<String, dynamic>.from(data))
            : null,
      );
    } catch (e) {
      return CommentActionResult.failure(
        garraActionErrorMessage(e, notFoundMessage: _commentGoneMessage),
      );
    }
  }

  Future<CommentActionResult> deleteComment(String commentId) async {
    try {
      await _dio.delete('/community/comments/$commentId');
      return CommentActionResult.success(message: 'Comentario eliminado');
    } catch (e) {
      return CommentActionResult.failure(
        garraActionErrorMessage(e, notFoundMessage: _commentGoneMessage),
        notFound: e is DioException && e.response?.statusCode == 404,
      );
    }
  }

  /// Clan moderation (OWNER/ADMIN/MODERATOR of the clan): hides a clan post.
  Future<CommentActionResult> hideClanPost({
    required String clanSlug,
    required String postId,
  }) async {
    try {
      await _dio.patch('/clans/$clanSlug/posts/$postId/hide');
      return CommentActionResult.success(message: 'Publicaci\u00f3n oculta');
    } catch (e) {
      return CommentActionResult.failure(
        garraActionErrorMessage(e),
        notFound: e is DioException && e.response?.statusCode == 404,
      );
    }
  }

  /// Clan moderation: hides a comment (and its thread) of a clan post.
  Future<CommentActionResult> hideClanComment({
    required String clanSlug,
    required String postId,
    required String commentId,
  }) async {
    try {
      await _dio.patch(
        '/clans/$clanSlug/posts/$postId/comments/$commentId/hide',
      );
      return CommentActionResult.success(message: 'Comentario oculto');
    } catch (e) {
      return CommentActionResult.failure(
        garraActionErrorMessage(e, notFoundMessage: _commentGoneMessage),
        notFound: e is DioException && e.response?.statusCode == 404,
      );
    }
  }

  Future<ReactionResult> upsertCommentReaction({
    required String commentId,
    required String type,
  }) async {
    try {
      final response = await _dio.put(
        '/community/comments/$commentId/reaction',
        data: {'type': type.toUpperCase()},
      );
      return _commentReactionResult(response.data);
    } catch (e) {
      return ReactionResult.failure(
        garraActionErrorMessage(e, notFoundMessage: _commentGoneMessage),
      );
    }
  }

  Future<ReactionResult> removeCommentReaction(String commentId) async {
    try {
      final response = await _dio.delete(
        '/community/comments/$commentId/reaction',
      );
      return _commentReactionResult(response.data);
    } catch (e) {
      return ReactionResult.failure(
        garraActionErrorMessage(e, notFoundMessage: _commentGoneMessage),
      );
    }
  }

  static const _commentGoneMessage = 'Este comentario ya no está disponible.';

  ReactionResult _commentReactionResult(Object? body) {
    final payload = body is Map ? (body['data'] ?? body) : null;
    if (payload is Map) {
      return ReactionResult.fromPayload(
        Map<String, dynamic>.from(payload),
        message: 'Reacción actualizada',
      );
    }
    // No payload: keep the local (optimistic) state as-is.
    return ReactionResult.success(message: 'Reacción actualizada');
  }

  /// MODERATION_11: platform report of a post, comment or profile. The backend
  /// message is kept for business errors (e.g. "Ya denunciaste este
  /// contenido.").
  Future<ReportSubmitResult> createReport({
    required GarraReportTarget target,
    required String targetId,
    required String reason,
    String? detail,
  }) async {
    final trimmed = detail?.trim();
    try {
      await _dio.post(
        '/community/reports',
        data: {
          'targetType': target.apiValue,
          'targetId': targetId,
          'reason': reason,
          if (trimmed != null && trimmed.isNotEmpty) 'detail': trimmed,
        },
      );
      return ReportSubmitResult.success();
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final message = _dioMessage(e, garraReportFallbackError);
        return ReportSubmitResult.failure(
          message == 'Validation failed' ? garraReportFallbackError : message,
        );
      }
      if (e.response?.statusCode == 404) {
        return ReportSubmitResult.failure(
          'Este contenido ya no est\u00e1 disponible.',
        );
      }
      return ReportSubmitResult.failure(classifyDioError(e).message);
    } catch (_) {
      return ReportSubmitResult.failure(garraReportFallbackError);
    }
  }

  Future<CommentActionResult> reportComment({
    required String commentId,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/community/comments/$commentId/report',
        data: {'reason': reason},
      );
      return CommentActionResult.success(
        message: response.data['message']?.toString() ?? 'Reporte enviado',
      );
    } on DioException catch (e) {
      return CommentActionResult.failure(
        _dioMessage(e, 'No se pudo reportar el comentario'),
      );
    } catch (_) {
      return CommentActionResult.failure('Ocurrió un error inesperado');
    }
  }
}

class WallActionResult {
  const WallActionResult({
    required this.success,
    required this.message,
    this.post,
  });

  final bool success;
  final String message;
  final WallPostModel? post;

  factory WallActionResult.success({
    required String message,
    WallPostModel? post,
  }) {
    return WallActionResult(success: true, message: message, post: post);
  }

  factory WallActionResult.failure(String message) {
    return WallActionResult(success: false, message: message);
  }
}

class CommentActionResult {
  const CommentActionResult({
    required this.success,
    required this.message,
    this.comment,
    this.notFound = false,
  });

  final bool success;
  final String message;
  final WallCommentModel? comment;

  /// The target comment no longer exists (HTTP 404).
  final bool notFound;

  factory CommentActionResult.success({
    required String message,
    WallCommentModel? comment,
  }) {
    return CommentActionResult(
      success: true,
      message: message,
      comment: comment,
    );
  }

  factory CommentActionResult.failure(String message, {bool notFound = false}) {
    return CommentActionResult(
      success: false,
      message: message,
      notFound: notFound,
    );
  }
}
