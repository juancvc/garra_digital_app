import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'create_wall_post_request.dart';
import 'reaction_result.dart';
import 'report_wall_post_request.dart';
import 'wall_comment_model.dart';
import 'wall_post_model.dart';
import 'wall_status_model.dart';

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
          ? {
              'locationTag': locationTag,
            }
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
        _normalizeWallError(
          _dioMessage(e, 'No se pudo publicar en el muro'),
        ),
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
        data: ReportWallPostRequest(category: category, reason: reason).toJson(),
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
        post: data is Map<String, dynamic> ? WallPostModel.fromJson(data) : null,
      );
    } on DioException catch (e) {
      return WallActionResult.failure(
        _dioMessage(e, 'No se pudo publicar'),
      );
    } catch (_) {
      return WallActionResult.failure('Ocurrió un error inesperado');
    }
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
          message:
              response.data['message']?.toString() ?? 'Reacción eliminada',
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
        message: response.data['message']?.toString() ?? 'Comentario publicado',
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

  Future<CommentActionResult> deleteComment(String commentId) async {
    try {
      final response =
          await _dio.delete('/community/comments/$commentId');
      return CommentActionResult.success(
        message:
            response.data['message']?.toString() ?? 'Comentario eliminado',
      );
    } on DioException catch (e) {
      return CommentActionResult.failure(
        _dioMessage(e, 'No se pudo eliminar el comentario'),
      );
    } catch (_) {
      return CommentActionResult.failure('Ocurrió un error inesperado');
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
    return WallActionResult(
      success: true,
      message: message,
      post: post,
    );
  }

  factory WallActionResult.failure(String message) {
    return WallActionResult(
      success: false,
      message: message,
    );
  }
}

class CommentActionResult {
  const CommentActionResult({
    required this.success,
    required this.message,
    this.comment,
  });

  final bool success;
  final String message;
  final WallCommentModel? comment;

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

  factory CommentActionResult.failure(String message) {
    return CommentActionResult(
      success: false,
      message: message,
    );
  }
}
