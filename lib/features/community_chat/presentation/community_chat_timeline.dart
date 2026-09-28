import '../../../core/utils/garra_message_time.dart';
import '../../chat/presentation/chat_timeline.dart' show chatGroupGap;
import '../data/community_chat_models.dart';

/// One row of the community chat transcript.
sealed class CommunityTimelineEntry {
  const CommunityTimelineEntry();
}

/// Centered day label ("Hoy", "Ayer", date), same formatter as private chat.
class CommunityDaySeparatorEntry extends CommunityTimelineEntry {
  const CommunityDaySeparatorEntry(this.label);

  final String label;
}

class CommunityMessageEntry extends CommunityTimelineEntry {
  const CommunityMessageEntry({
    required this.message,
    required this.firstInGroup,
    required this.lastInGroup,
  });

  final CommunityChatMessage message;
  final bool firstInGroup;
  final bool lastInGroup;
}

/// Same sender (sender.id), same local day and at most [chatGroupGap] apart:
/// the private chat grouping window.
bool communityMessagesGroup(
  CommunityChatMessage previous,
  CommunityChatMessage next,
) {
  if (previous.mine != next.mine) return false;
  if (!previous.mine && previous.sender.id != next.sender.id) return false;
  final a = previous.createdAt;
  final b = next.createdAt;
  if (a == null || b == null) return a == null && b == null;
  if (!isSameGarraLocalDay(a, b)) return false;
  return b.difference(a).abs() <= chatGroupGap;
}

/// Transcript rows for [messages] (ascending seq): day separators between
/// local days plus the group boundaries of every message.
///
/// [groupBreakBeforeId] always starts a new group at that message (the scroll
/// anchor), so prepending older history never changes its layout.
List<CommunityTimelineEntry> buildCommunityTimeline(
  List<CommunityChatMessage> messages, {
  DateTime? now,
  String? groupBreakBeforeId,
}) {
  final entries = <CommunityTimelineEntry>[];
  DateTime? lastDay;
  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    final created = message.createdAt;
    var newDay = false;
    if (created != null &&
        (lastDay == null || !isSameGarraLocalDay(lastDay, created))) {
      entries.add(
        CommunityDaySeparatorEntry(formatGarraDaySeparator(created, now: now)),
      );
      lastDay = created;
      newDay = true;
    }
    final previous = i > 0 ? messages[i - 1] : null;
    final next = i + 1 < messages.length ? messages[i + 1] : null;
    final first =
        newDay ||
        previous == null ||
        message.id == groupBreakBeforeId ||
        !communityMessagesGroup(previous, message);
    final nextStartsDay =
        next?.createdAt != null &&
        created != null &&
        !isSameGarraLocalDay(created, next!.createdAt!);
    final last =
        next == null ||
        nextStartsDay ||
        next.id == groupBreakBeforeId ||
        !communityMessagesGroup(message, next);
    entries.add(
      CommunityMessageEntry(
        message: message,
        firstInGroup: first,
        lastInGroup: last,
      ),
    );
  }
  return entries;
}
