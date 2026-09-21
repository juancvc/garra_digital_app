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
}
