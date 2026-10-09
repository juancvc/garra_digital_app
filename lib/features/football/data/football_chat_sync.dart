import 'football_chat_service.dart';

/// Compares chat messages for stable ordering (matches backend keyset).
int footballChatMessageOrder(FootballChatMessage a, FootballChatMessage b) {
  final ta = a.createdAt ?? DateTime.utc(9999);
  final tb = b.createdAt ?? DateTime.utc(9999);
  final byTime = ta.compareTo(tb);
  if (byTime != 0) return byTime;
  return a.id.compareTo(b.id);
}

bool footballChatIsSameOrNewer(FootballChatMessage m, DateTime anchor, String anchorId) {
  final t = m.createdAt;
  if (t == null) return false;
  final cmp = t.compareTo(anchor);
  if (cmp > 0) return true;
  if (cmp < 0) return false;
  return m.id.compareTo(anchorId) >= 0;
}

/// Drops local messages in the server's latest window that are no longer returned
/// (moderated away). Messages older than [anchor] are never removed — a limited poll
/// page cannot prove moderation for deep history.
List<FootballChatMessage> reconcileFootballChatRecentWindow({
  required List<FootballChatMessage> local,
  required List<FootballChatMessage> serverWindow,
}) {
  if (serverWindow.isEmpty) return local;
  final anchor = serverWindow.first;
  final anchorAt = anchor.createdAt;
  if (anchorAt == null) return local;
  final serverIds = {for (final m in serverWindow) m.id};
  return [
    for (final m in local)
      if (!footballChatIsSameOrNewer(m, anchorAt, anchor.id) ||
          serverIds.contains(m.id))
        m,
  ];
}

List<FootballChatMessage> footballChatSortedUnique(Iterable<FootballChatMessage> source) {
  final byId = <String, FootballChatMessage>{};
  for (final m in source) {
    if (m.id.isEmpty) continue;
    byId[m.id] = m;
  }
  final list = byId.values.toList()..sort(footballChatMessageOrder);
  return list;
}
