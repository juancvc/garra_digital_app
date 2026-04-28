import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'create_wall_post_request.dart';
import 'report_wall_post_request.dart';
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
      final message = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;

      return WallActionResult.failure(
        _normalizeWallError(message ?? 'No se pudo publicar en el muro'),
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
  }) async {
    try {
      final response = await _dio.post(
        '/community/wall/posts/$postId/report',
        data: ReportWallPostRequest(reason: reason).toJson(),
      );

      final data = response.data['data'];

      return WallActionResult.success(
        message: response.data['message']?.toString() ?? 'Reporte enviado',
        post: data is Map<String, dynamic>
            ? WallPostModel.fromJson(data)
            : null,
      );
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;

      return WallActionResult.failure(
        message ?? 'No se pudo reportar la publicación',
      );
    } catch (_) {
      return WallActionResult.failure('Ocurrió un error inesperado');
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