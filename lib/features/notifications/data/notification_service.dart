import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.referenceType,
    this.referenceId,
    this.readAt,
    required this.createdAt,
    required this.read,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String? referenceType;
  final String? referenceId;
  final DateTime? readAt;
  final DateTime createdAt;
  final bool read;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      referenceType: json['referenceType']?.toString(),
      referenceId: json['referenceId']?.toString(),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      read: json['read'] as bool? ?? false,
    );
  }
}

class ActivityItem {
  const ActivityItem(this.latest, this.count, this.unreadCount);

  final NotificationItem latest;
  final int count;
  final int unreadCount;

  bool get read => unreadCount == 0;
  bool get isChatGroup => latest.type.toUpperCase() == 'CHAT' &&
      latest.referenceType?.toUpperCase() == 'CHAT_CONVERSATION' &&
      latest.referenceId != null;

  String get title {
    if (!isChatGroup || count == 1) return latest.title;
    final sender = latest.message.replaceFirst(RegExp(r'^Nuevo mensaje de '), '');
    final quantity = unreadCount > 0 ? unreadCount : count;
    final noun = quantity == 1 ? 'mensaje' : 'mensajes';
    final qualifier = unreadCount == 0 ? '' : quantity == 1 ? ' nuevo' : ' nuevos';
    return '$sender · $quantity $noun$qualifier';
  }
}

/// Only direct-chat events with the same conversation are grouped.
List<ActivityItem> groupActivityItems(List<NotificationItem> items) {
  final result = <ActivityItem>[];
  final chatIndexes = <String, int>{};
  for (final item in items) {
    final isChat = item.type.toUpperCase() == 'CHAT' &&
        item.referenceType?.toUpperCase() == 'CHAT_CONVERSATION' &&
        item.referenceId != null;
    if (!isChat) {
      result.add(ActivityItem(item, 1, item.read ? 0 : 1));
      continue;
    }
    final key = item.referenceId!;
    final existing = chatIndexes[key];
    if (existing == null) {
      chatIndexes[key] = result.length;
      result.add(ActivityItem(item, 1, item.read ? 0 : 1));
    } else {
      final group = result[existing];
      result[existing] = ActivityItem(group.latest, group.count + 1,
          group.unreadCount + (item.read ? 0 : 1));
    }
  }
  return result;
}

class NotificationService {
  NotificationService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<NotificationItem>> getMyNotifications({int size = 30}) async {
    final response = await _dio.get(
      '/notifications/me',
      queryParameters: {'size': size},
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    final items = data['items'] as List? ?? const [];
    return items
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> markAllRead() async {
    await _dio.post('/notifications/me/read-all');
  }

  Future<void> markRead(String id) async {
    await _dio.patch('/notifications/$id/read');
  }
}
