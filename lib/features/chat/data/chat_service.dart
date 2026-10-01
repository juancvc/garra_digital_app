import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../community/data/reaction_type.dart';
import 'chat_models.dart';

class ChatException implements Exception {
  ChatException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ChatService {
  ChatService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<ChatRelationship> relationship(
    String userId, {
    String context = 'SOCIAL',
  }) async {
    final data = await _data('/chat/with/$userId', query: {'context': context});
    return ChatRelationship.fromJson(data);
  }

  Future<ChatConversation> openMarketplace({
    required String recipientUserId,
    required String content,
    String? listingTitle,
    String? listingPrice,
  }) async {
    final data = await _data(
      '/chat/marketplace',
      body: {
        'recipientUserId': recipientUserId,
        'content': content,
        if (listingTitle != null && listingTitle.trim().isNotEmpty)
          'listingTitle': listingTitle.trim(),
        if (listingPrice != null && listingPrice.trim().isNotEmpty)
          'listingPriceLabel': listingPrice.trim(),
      },
    );
    return ChatConversation.fromJson(data);
  }

  Future<ChatConversation> request(
    String recipientUserId, {
    String? initialMessage,
  }) async {
    final body = <String, dynamic>{'recipientUserId': recipientUserId};
    final text = initialMessage?.trim();
    if (text != null && text.isNotEmpty) {
      body['initialMessage'] = text;
    }
    final data = await _data('/chat/requests', body: body);
    return ChatConversation.fromJson(data);
  }

  Future<List<ChatConversation>> incoming() async {
    final data = await _list('/chat/requests/incoming');
    return data.map(ChatConversation.fromJson).toList();
  }

  Future<ChatConversation> accept(String conversationId) async {
    final data = await _data(
      '/chat/requests/$conversationId/accept',
      body: const {},
    );
    return ChatConversation.fromJson(data);
  }

  Future<ChatConversation> reject(String conversationId) async {
    final data = await _data(
      '/chat/requests/$conversationId/reject',
      body: const {},
    );
    return ChatConversation.fromJson(data);
  }

  Future<List<ChatConversation>> conversations() async {
    final data = await _list('/chat/conversations');
    return data.map(ChatConversation.fromJson).toList();
  }

  Future<ChatConversation> conversation(String conversationId) async {
    final data = await _data('/chat/conversations/$conversationId');
    return ChatConversation.fromJson(data);
  }

  Future<List<ChatMessage>> messages(String conversationId) async {
    final data = await _list('/chat/conversations/$conversationId/messages');
    return data.map(ChatMessage.fromJson).toList();
  }

  Future<ChatMessage> send(
    String conversationId,
    String content, {
    List<String> mediaAssetIds = const [],
  }) async {
    final data = await _data(
      '/chat/conversations/$conversationId/messages',
      body: {
        'content': content,
        if (mediaAssetIds.isNotEmpty) 'mediaAssetIds': mediaAssetIds,
      },
    );
    return ChatMessage.fromJson(data);
  }

  Future<ChatMessage> sendReply(
    String conversationId,
    String content,
    String replyToMessageId, {
    List<String> mediaAssetIds = const [],
  }) async {
    final data = await _data(
      '/chat/conversations/$conversationId/messages',
      body: {
        'content': content,
        if (mediaAssetIds.isNotEmpty) 'mediaAssetIds': mediaAssetIds,
        'replyToMessageId': replyToMessageId,
      },
    );
    return ChatMessage.fromJson(data);
  }

  Future<ChatMessage> sendAudio(String conversationId, String assetId,
      int durationSeconds) async {
    final data = await _data('/chat/conversations/$conversationId/messages',
        body: {'content': '', 'mediaAssetIds': [assetId],
          'audioDurationSeconds': durationSeconds});
    return ChatMessage.fromJson(data);
  }

  Future<ChatMessage> editMessage(String messageId, String content) async {
    final data = await _write(
      'PUT',
      '/chat/messages/$messageId',
      body: {'content': content},
    );
    return ChatMessage.fromJson(data);
  }

  Future<ChatMessage> deleteMessage(String messageId) async {
    final data = await _write('DELETE', '/chat/messages/$messageId');
    return ChatMessage.fromJson(data);
  }

  /// CHAT_REACTIONS_13: set or change my reaction (PUT, idempotent).
  Future<ChatMessageReactionsResult> reactToMessage(
    String messageId,
    ReactionType type,
  ) async {
    final data = await _write(
      'PUT',
      '/chat/messages/$messageId/reaction',
      body: {'type': type.apiValue},
    );
    return ChatMessageReactionsResult.fromJson(data);
  }

  /// CHAT_REACTIONS_13: remove my reaction (DELETE, idempotent).
  Future<ChatMessageReactionsResult> removeMessageReaction(
    String messageId,
  ) async {
    final data = await _write('DELETE', '/chat/messages/$messageId/reaction');
    return ChatMessageReactionsResult.fromJson(data);
  }

  Future<void> markRead(String conversationId) async {
    await _data('/chat/conversations/$conversationId/read', body: const {});
  }

  /// Total unread (private + community); see [unreadSummary].
  Future<int> unreadCount() async => (await unreadSummary()).unreadCount;

  /// COMMUNITY_GROUP_CHAT_14C: one call with the total and its split.
  Future<ChatUnreadSummary> unreadSummary() async {
    final data = await _data('/chat/unread-count');
    return ChatUnreadSummary.fromJson(data);
  }

  Future<List<CommunityChatPreview>> communityPreviews() async {
    final data = await _list('/chat/community-previews');
    return data.map(CommunityChatPreview.fromJson).toList();
  }

  Future<Map<String, dynamic>> _data(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = body == null
          ? await _dio.get(path, queryParameters: query)
          : await _dio.post(path, data: body, queryParameters: query);
      final payload = response.data;
      if (payload is Map && payload['data'] is Map) {
        return Map<String, dynamic>.from(payload['data'] as Map);
      }
      if (payload is Map<String, dynamic>) return payload;
      return {};
    } on DioException catch (error) {
      throw ChatException(_message(error));
    }
  }

  Future<Map<String, dynamic>> _write(
    String method,
    String path, {
    Object? body,
  }) async {
    try {
      final response = await _dio.request(
        path,
        data: body,
        options: Options(method: method),
      );
      final payload = response.data;
      if (payload is Map && payload['data'] is Map) {
        return Map<String, dynamic>.from(payload['data'] as Map);
      }
      if (payload is Map<String, dynamic>) return payload;
      return {};
    } on DioException catch (error) {
      throw ChatException(_message(error));
    }
  }

  Future<List<Map<String, dynamic>>> _list(String path) async {
    try {
      final response = await _dio.get(path);
      final payload = response.data;
      final raw = payload is Map ? payload['data'] : payload;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on DioException catch (error) {
      throw ChatException(_message(error));
    }
  }

  String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'No pudimos completar la acción de chat';
  }
}
