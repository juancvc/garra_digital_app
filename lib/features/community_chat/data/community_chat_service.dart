import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../community/data/reaction_type.dart';
import 'community_chat_models.dart';

/// Error of a community chat call. [statusCode] drives the UX (403 access
/// lost / read-only, 404 unavailable); the backend text is never shown.
class CommunityChatException implements Exception {
  const CommunityChatException(this.statusCode, [this.message = '']);

  /// HTTP status, or null for network errors / timeouts.
  final int? statusCode;
  final String message;

  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => 'CommunityChatException($statusCode)';
}

/// COMMUNITY_GROUP_CHAT_14B: client of `/clans/{slug}/chat` (backend 14A).
class CommunityChatService {
  CommunityChatService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  static const int pageSize = 30;

  String _base(String slug) => '/clans/${Uri.encodeComponent(slug)}/chat';

  /// GET /clans/{slug}/chat
  Future<CommunityChatInfo> info(String slug) async {
    final data = await _request('GET', _base(slug));
    return CommunityChatInfo.fromJson(data);
  }

  /// GET /clans/{slug}/chat/messages?size=30 (latest page, ascending seq).
  Future<CommunityChatMessagePage> latest(String slug, {int size = pageSize}) {
    return _page(slug, {'size': size});
  }

  /// GET /clans/{slug}/chat/messages?beforeSeq=N&size=30
  Future<CommunityChatMessagePage> older(
    String slug, {
    required int beforeSeq,
    int size = pageSize,
  }) {
    return _page(slug, {'beforeSeq': beforeSeq, 'size': size});
  }

  Future<CommunityChatMessagePage> _page(
    String slug,
    Map<String, dynamic> query,
  ) async {
    final data = await _request('GET', '${_base(slug)}/messages', query: query);
    return CommunityChatMessagePage.fromJson(data);
  }

  /// GET /clans/{slug}/chat/changes?sinceVersion=V
  Future<CommunityChatChanges> changes(
    String slug, {
    required int sinceVersion,
  }) async {
    final data = await _request(
      'GET',
      '${_base(slug)}/changes',
      query: {'sinceVersion': sinceVersion},
    );
    return CommunityChatChanges.fromJson(data);
  }

  /// POST /clans/{slug}/chat/messages {content, mediaAssetIds}
  Future<CommunityChatMessage> send(
    String slug,
    String content, {
    List<String> mediaAssetIds = const [],
  }) async {
    final data = await _request(
      'POST',
      '${_base(slug)}/messages',
      body: {
        'content': content,
        if (mediaAssetIds.isNotEmpty) 'mediaAssetIds': mediaAssetIds,
      },
    );
    return CommunityChatMessage.fromJson(data);
  }

  /// PUT /clans/{slug}/chat/messages/{id}/reaction {type}
  Future<CommunityChatReactionsResult> react(
    String slug,
    String messageId,
    ReactionType type,
  ) async {
    final data = await _request(
      'PUT',
      '${_base(slug)}/messages/${Uri.encodeComponent(messageId)}/reaction',
      body: {'type': type.apiValue},
    );
    return CommunityChatReactionsResult.fromJson(data);
  }

  /// DELETE /clans/{slug}/chat/messages/{id}/reaction
  Future<CommunityChatReactionsResult> removeReaction(
    String slug,
    String messageId,
  ) async {
    final data = await _request(
      'DELETE',
      '${_base(slug)}/messages/${Uri.encodeComponent(messageId)}/reaction',
    );
    return CommunityChatReactionsResult.fromJson(data);
  }

  /// DELETE /clans/{slug}/chat/messages/{id}: author self-delete. Returns the
  /// DELETED_BY_AUTHOR tombstone (idempotent; 409 if hidden by moderation).
  Future<CommunityChatMessage> deleteMessage(
    String slug,
    String messageId,
  ) async {
    final data = await _request(
      'DELETE',
      '${_base(slug)}/messages/${Uri.encodeComponent(messageId)}',
    );
    return CommunityChatMessage.fromJson(data);
  }

  /// POST /clans/{slug}/chat/messages/{id}/hide: moderator hide. Returns the
  /// HIDDEN_BY_MODERATOR tombstone (403 without rank, 409 if author-deleted).
  Future<CommunityChatMessage> hideMessage(
    String slug,
    String messageId,
  ) async {
    final data = await _request(
      'POST',
      '${_base(slug)}/messages/${Uri.encodeComponent(messageId)}/hide',
    );
    return CommunityChatMessage.fromJson(data);
  }

  /// POST /clans/{slug}/chat/read {seq} (monotonic on the backend).
  Future<CommunityChatInfo> markRead(String slug, int seq) async {
    final data = await _request(
      'POST',
      '${_base(slug)}/read',
      body: {'seq': seq},
    );
    return CommunityChatInfo.fromJson(data);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.request(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      final payload = response.data;
      if (payload is Map && payload['data'] is Map) {
        return Map<String, dynamic>.from(payload['data'] as Map);
      }
      if (payload is Map<String, dynamic>) return payload;
      return {};
    } on DioException catch (error) {
      final data = error.response?.data;
      throw CommunityChatException(
        error.response?.statusCode,
        data is Map && data['message'] != null
            ? data['message'].toString()
            : '',
      );
    }
  }
}

final communityChatServiceProvider = Provider<CommunityChatService>(
  (ref) => CommunityChatService(),
);
