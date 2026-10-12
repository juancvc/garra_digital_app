import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

/// PRODUCT-08C: `GET/PATCH /notifications/me/preferences` (backend 08B adds `socialChatRepliesEnabled`).
/// Only the fields this app edits are modelled; PATCH sends just the changed field.
class ChatReplyPreference {
  const ChatReplyPreference({required this.socialChatRepliesEnabled});

  final bool socialChatRepliesEnabled;

  /// Older backends do not send the field yet: default ON (same as the server default).
  factory ChatReplyPreference.fromJson(Map<String, dynamic> json) => ChatReplyPreference(
        socialChatRepliesEnabled: json['socialChatRepliesEnabled'] is bool
            ? json['socialChatRepliesEnabled'] as bool
            : true,
      );
}

class NotificationPreferencesService {
  NotificationPreferencesService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  static const path = '/notifications/me/preferences';

  Future<ChatReplyPreference> load() async {
    final response = await _dio.get(path);
    return ChatReplyPreference.fromJson(_data(response));
  }

  /// Returns the value the server stored (never assumes success).
  Future<ChatReplyPreference> setChatReplies(bool enabled) async {
    final response = await _dio.patch(path, data: {'socialChatRepliesEnabled': enabled});
    final pref = ChatReplyPreference.fromJson(_data(response));
    return pref;
  }

  static Map<String, dynamic> _data(Response<dynamic> response) {
    final body = response.data;
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return const {};
  }
}
