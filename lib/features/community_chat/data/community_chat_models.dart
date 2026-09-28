import '../../chat/data/chat_models.dart';
import '../../community/data/reaction_type.dart';

/// COMMUNITY_GROUP_CHAT_14B: models of the community group chat
/// (`/clans/{slug}/chat`, backend CommunityChatDtos). Media items and reaction
/// summaries share the private chat models because the JSON contract is
/// identical (ChatMediaItem / MessageReactionSummary on the backend).

const String communityMessageVisible = 'VISIBLE';
const String communityMessageDeletedByAuthor = 'DELETED_BY_AUTHOR';
const String communityMessageHiddenByModerator = 'HIDDEN_BY_MODERATOR';

int _int(dynamic value) => value is num ? value.toInt() : 0;

String _string(dynamic value) => value?.toString() ?? '';

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

class CommunityChatSender {
  const CommunityChatSender({
    required this.id,
    required this.displayName,
    this.username = '',
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;

  /// Name shown above a group of bubbles (displayName, else @username).
  String get label {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (username.trim().isNotEmpty) return '@${username.trim()}';
    return 'Hincha';
  }

  factory CommunityChatSender.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatarUrl']?.toString();
    return CommunityChatSender(
      id: _string(json['id']),
      displayName: _string(json['displayName']),
      username: _string(json['username']),
      avatarUrl: avatar == null || avatar.trim().isEmpty ? null : avatar,
    );
  }
}

class CommunityChatMessage {
  const CommunityChatMessage({
    required this.id,
    required this.seq,
    required this.version,
    required this.status,
    required this.sender,
    required this.mine,
    this.content,
    this.createdAt,
    this.media = const [],
    this.reactions = const [],
    this.myReaction,
  });

  final String id;
  final int seq;
  final int version;
  final String status;
  final CommunityChatSender sender;
  final bool mine;

  /// Null on tombstones; "" on photo-only messages.
  final String? content;
  final DateTime? createdAt;
  final List<ChatMediaItem> media;
  final List<ChatMessageReactionSummary> reactions;
  final String? myReaction;

  bool get isVisible => status == communityMessageVisible;
  bool get isDeletedByAuthor => status == communityMessageDeletedByAuthor;
  bool get isHiddenByModerator => status == communityMessageHiddenByModerator;
  bool get isTombstone => !isVisible;

  String get reactionSignature => chatReactionSignature(reactions);

  CommunityChatMessage copyWith({
    int? version,
    List<ChatMessageReactionSummary>? reactions,
    String? myReaction,
    bool clearMyReaction = false,
  }) {
    return CommunityChatMessage(
      id: id,
      seq: seq,
      version: version ?? this.version,
      status: status,
      sender: sender,
      mine: mine,
      content: content,
      createdAt: createdAt,
      media: media,
      reactions: reactions ?? this.reactions,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
    );
  }

  factory CommunityChatMessage.fromJson(Map<String, dynamic> json) {
    final status = _string(json['status']).isEmpty
        ? communityMessageVisible
        : _string(json['status']);
    final visible = status == communityMessageVisible;
    final rawMedia = json['media'];
    final sender = json['sender'];
    return CommunityChatMessage(
      id: _string(json['id']),
      seq: _int(json['seq']),
      version: _int(json['version']),
      status: status,
      sender: sender is Map
          ? CommunityChatSender.fromJson(Map<String, dynamic>.from(sender))
          : const CommunityChatSender(id: '', displayName: ''),
      mine: json['mine'] == true,
      // Tombstones never carry content, media or reactions (even if sent).
      content: visible ? json['content']?.toString() : null,
      createdAt: _date(json['createdAt']),
      media: !visible || rawMedia is! List
          ? const []
          : rawMedia
                .whereType<Map>()
                .map(
                  (item) =>
                      ChatMediaItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false),
      reactions: visible ? parseChatReactions(json['reactions']) : const [],
      myReaction: visible
          ? ReactionType.tryParse(json['myReaction']?.toString())?.apiValue
          : null,
    );
  }
}

class CommunityChatInfo {
  const CommunityChatInfo({
    required this.chatId,
    required this.clanSlug,
    required this.clanName,
    required this.status,
    required this.clanStatus,
    this.clanId = '',
    this.myRole = 'MEMBER',
    this.canModerate = false,
    this.memberCount = 0,
    this.lastSeq = 0,
    this.lastVersion = 0,
    this.unreadCount = 0,
    this.watermark = 0,
    this.lastReadSeq = 0,
    this.writable = false,
  });

  final String chatId;
  final String clanId;
  final String clanSlug;
  final String clanName;

  /// Chat status: ACTIVE, READ_ONLY or CLOSED.
  final String status;

  /// Clan status: ACTIVE, PENDING, SUSPENDED, REJECTED, ARCHIVED.
  final String clanStatus;
  final String myRole;
  final bool canModerate;
  final int memberCount;
  final int lastSeq;
  final int lastVersion;
  final int unreadCount;
  final int watermark;
  final int lastReadSeq;

  /// Backend decision (clan ACTIVE and chat ACTIVE). The only write gate.
  final bool writable;

  factory CommunityChatInfo.fromJson(Map<String, dynamic> json) {
    return CommunityChatInfo(
      chatId: _string(json['chatId']),
      clanId: _string(json['clanId']),
      clanSlug: _string(json['clanSlug']),
      clanName: _string(json['clanName']),
      status: _string(json['status']),
      clanStatus: _string(json['clanStatus']),
      myRole: _string(json['myRole']),
      canModerate: json['canModerate'] == true,
      memberCount: _int(json['memberCount']),
      lastSeq: _int(json['lastSeq']),
      lastVersion: _int(json['lastVersion']),
      unreadCount: _int(json['unreadCount']),
      watermark: _int(json['watermark']),
      lastReadSeq: _int(json['lastReadSeq']),
      writable: json['writable'] == true,
    );
  }
}

List<CommunityChatMessage> _messages(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (item) =>
            CommunityChatMessage.fromJson(Map<String, dynamic>.from(item)),
      )
      .where((message) => message.id.isNotEmpty)
      .toList(growable: false);
}

/// GET /chat/messages (latest or ?beforeSeq): items ascending by seq.
class CommunityChatMessagePage {
  const CommunityChatMessagePage({
    required this.items,
    this.hasMoreBefore = false,
    this.oldestSeq,
    this.latestSeq,
    this.lastSeq = 0,
    this.syncVersion = 0,
  });

  final List<CommunityChatMessage> items;
  final bool hasMoreBefore;
  final int? oldestSeq;
  final int? latestSeq;
  final int lastSeq;

  /// Safe first `sinceVersion` for /changes (read before the page query).
  final int syncVersion;

  factory CommunityChatMessagePage.fromJson(Map<String, dynamic> json) {
    return CommunityChatMessagePage(
      items: _messages(json['items']),
      hasMoreBefore: json['hasMoreBefore'] == true,
      oldestSeq: json['oldestSeq'] is num
          ? (json['oldestSeq'] as num).toInt()
          : null,
      latestSeq: json['latestSeq'] is num
          ? (json['latestSeq'] as num).toInt()
          : null,
      lastSeq: _int(json['lastSeq']),
      syncVersion: _int(json['syncVersion']),
    );
  }
}

/// GET /chat/changes: items ascending by version, each message at most once.
class CommunityChatChanges {
  const CommunityChatChanges({
    required this.items,
    required this.lastVersion,
    this.lastSeq = 0,
    this.hasMore = false,
    this.resyncRequired = false,
  });

  final List<CommunityChatMessage> items;
  final int lastVersion;
  final int lastSeq;
  final bool hasMore;
  final bool resyncRequired;

  factory CommunityChatChanges.fromJson(Map<String, dynamic> json) {
    return CommunityChatChanges(
      items: _messages(json['items']),
      lastVersion: _int(json['lastVersion']),
      lastSeq: _int(json['lastSeq']),
      hasMore: json['hasMore'] == true,
      resyncRequired: json['resyncRequired'] == true,
    );
  }
}

/// PUT/DELETE /chat/messages/{id}/reaction response.
class CommunityChatReactionsResult {
  const CommunityChatReactionsResult({
    required this.messageId,
    required this.version,
    this.reactions = const [],
    this.myReaction,
  });

  final String messageId;
  final int version;
  final List<ChatMessageReactionSummary> reactions;
  final String? myReaction;

  factory CommunityChatReactionsResult.fromJson(Map<String, dynamic> json) {
    return CommunityChatReactionsResult(
      messageId: _string(json['messageId']),
      version: _int(json['version']),
      reactions: parseChatReactions(json['reactions']),
      myReaction: ReactionType.tryParse(
        json['myReaction']?.toString(),
      )?.apiValue,
    );
  }
}

/// Merges [incoming] into [current] keyed by message id and ordered by seq.
/// A known message is only replaced by a state at least as new (version), so
/// an older page or a late response can never roll a message back.
List<CommunityChatMessage> mergeCommunityMessages(
  List<CommunityChatMessage> current,
  Iterable<CommunityChatMessage> incoming,
) {
  final byId = <String, CommunityChatMessage>{
    for (final message in current) message.id: message,
  };
  for (final message in incoming) {
    if (message.id.isEmpty) continue;
    final known = byId[message.id];
    if (known == null || message.version >= known.version) {
      byId[message.id] = message;
    }
  }
  final merged = byId.values.toList()..sort((a, b) => a.seq.compareTo(b.seq));
  return List.unmodifiable(merged);
}
