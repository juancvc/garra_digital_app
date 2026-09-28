import '../../../core/utils/garra_message_time.dart';
import '../data/chat_models.dart';

/// CHAT_V2_A: consecutive messages of the same sender, on the same local day
/// and at most this far apart, render as one visual group.
const Duration chatGroupGap = Duration(minutes: 5);

/// One row of the conversation transcript.
sealed class ChatTimelineEntry {
  const ChatTimelineEntry();
}

/// Discreet centered day label ("Hoy", "Ayer", "sábado 26 de septiembre").
class ChatDaySeparatorEntry extends ChatTimelineEntry {
  const ChatDaySeparatorEntry(this.label);

  final String label;
}

class ChatMessageEntry extends ChatTimelineEntry {
  const ChatMessageEntry({
    required this.message,
    required this.firstInGroup,
    required this.lastInGroup,
  });

  final ChatMessage message;
  final bool firstInGroup;
  final bool lastInGroup;
}

bool _sameSender(ChatMessage a, ChatMessage b) =>
    a.mine == b.mine && (a.mine || a.senderId == b.senderId);

/// Whether [next] continues the group started by [previous].
bool chatMessagesGroup(ChatMessage previous, ChatMessage next) {
  if (!_sameSender(previous, next)) return false;
  final a = previous.createdAt;
  final b = next.createdAt;
  if (a == null || b == null) return a == null && b == null;
  if (!isSameGarraLocalDay(a, b)) return false;
  return b.difference(a).abs() <= chatGroupGap;
}

/// Builds the transcript rows: day separators between local days plus the
/// group boundaries of every message. Messages keep the backend order.
List<ChatTimelineEntry> buildChatTimeline(
  List<ChatMessage> messages, {
  DateTime? now,
}) {
  final entries = <ChatTimelineEntry>[];
  DateTime? lastDay;
  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    final created = message.createdAt;
    var newDay = false;
    if (created != null &&
        (lastDay == null || !isSameGarraLocalDay(lastDay, created))) {
      entries.add(
        ChatDaySeparatorEntry(formatGarraDaySeparator(created, now: now)),
      );
      lastDay = created;
      newDay = true;
    }
    final previous = i > 0 ? messages[i - 1] : null;
    final next = i + 1 < messages.length ? messages[i + 1] : null;
    final first =
        newDay || previous == null || !chatMessagesGroup(previous, message);
    final last = next == null || !chatMessagesGroup(message, next);
    entries.add(
      ChatMessageEntry(
        message: message,
        firstInGroup: first,
        lastInGroup: last,
      ),
    );
  }
  return entries;
}
