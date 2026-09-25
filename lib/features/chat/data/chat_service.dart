import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
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

  Future<ChatRelationship> relationship(String userId) async {
    final data = await _data('/chat/with/$userId');
    return ChatRelationship.fromJson(data);
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
    final data = await _data('/chat/requests/$conversationId/accept', body: const {});
    return ChatConversation.fromJson(data);
  }

  Future<ChatConversation> reject(String conversationId) async {
    final data = await _data('/chat/requests/$conversationId/reject', body: const {});
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

  Future<ChatMessage> send(String conversationId, String content) async {
    final data = await _data(
      '/chat/conversations/$conversationId/messages',
      body: {'content': content},
    );
    return ChatMessage.fromJson(data);
  }

  Future<void> markRead(String conversationId) async {
    await _data('/chat/conversations/$conversationId/read', body: const {});
  }

  Future<int> unreadCount() async {
    final data = await _data('/chat/unread-count');
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> _data(String path, {Object? body}) async {
    try {
      final response = body == null
          ? await _dio.get(path)
          : await _dio.post(path, data: body);
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
