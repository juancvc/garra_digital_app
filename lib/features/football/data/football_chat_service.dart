import 'package:dio/dio.dart';
import 'package:garra_digital_app/core/network/dio_client.dart';

class FootballChatMessage {
  const FootballChatMessage({required this.id, required this.authorId,
    required this.authorName, required this.authorUsername, required this.body,
    required this.createdAt});
  final String id;
  final String authorId;
  final String authorName;
  final String authorUsername;
  final String body;
  final DateTime? createdAt;

  factory FootballChatMessage.fromJson(Map<String, dynamic> json) => FootballChatMessage(
    id: json['id']?.toString() ?? '',
    authorId: json['authorId']?.toString() ?? '',
    authorName: json['authorName']?.toString() ?? 'Hincha',
    authorUsername: json['authorUsername']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
  );
}

class FootballChatPage {
  const FootballChatPage({required this.items, required this.hasMore});
  final List<FootballChatMessage> items;
  final bool hasMore;
}

/// SONIC_03 Chat Futbolero — polls Garra backend (no second realtime stack).
class FootballChatService {
  FootballChatService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<FootballChatPage> messages({DateTime? before, int size = 30}) async {
    final response = await _dio.get('/football/chat/messages', queryParameters: {
      if (before != null) 'before': before.toUtc().toIso8601String(),
      'size': size,
    });
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FootballChatMessage.fromJson)
        .toList();
    return FootballChatPage(items: items, hasMore: data['hasMore'] == true);
  }

  Future<FootballChatMessage> send(String body) async {
    final response = await _dio.post('/football/chat/messages', data: {'body': body});
    return FootballChatMessage.fromJson(
        response.data['data'] as Map<String, dynamic>? ?? {});
  }
}
