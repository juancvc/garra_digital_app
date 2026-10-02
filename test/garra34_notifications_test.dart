import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/notifications/data/notification_service.dart';

NotificationItem item(String id, String type, String? referenceId,
    {bool read = false}) => NotificationItem(
  id: id,
  type: type,
  title: 'Mensaje nuevo',
  message: 'Nuevo mensaje de crema',
  referenceType: type == 'CHAT' ? 'CHAT_CONVERSATION' : 'POST',
  referenceId: referenceId,
  createdAt: DateTime.utc(2026, 10, 2),
  read: read,
);

void main() {
  test('chat activity groups by conversation while preserving other events', () {
    final grouped = groupActivityItems([
      item('1', 'CHAT', 'conversation-a'),
      item('2', 'CHAT', 'conversation-a'),
      item('3', 'REACTION', 'post-a'),
      item('4', 'CHAT', 'conversation-b'),
      item('5', 'CHAT', 'conversation-a', read: true),
    ]);
    expect(grouped, hasLength(3));
    expect(grouped.first.latest.id, '1');
    expect(grouped.first.count, 3);
    expect(grouped.first.unreadCount, 2);
    expect(grouped.first.title, 'crema · 2 mensajes nuevos');
    expect(grouped[1].isChatGroup, isFalse);
    expect(grouped[2].latest.referenceId, 'conversation-b');
  });

  test('single unread chat message uses singular label', () {
    final grouped = groupActivityItems([
      item('1', 'CHAT', 'conversation-a'),
      item('2', 'CHAT', 'conversation-a', read: true),
    ]);
    expect(grouped.single.title, 'crema · 1 mensaje nuevo');
  });
}
