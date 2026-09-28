import '../../../core/utils/date_utils.dart';
import '../../community/data/reaction_type.dart';

class ChatRelationship {
  const ChatRelationship({
    this.conversationId,
    required this.status,
    this.outgoing = false,
    this.blocked = false,
  });

  final String? conversationId;
  final String status;
  final bool outgoing;
  final bool blocked;

  bool get isActive => status == 'ACTIVE';
  bool get isPending => status == 'PENDING';

  factory ChatRelationship.none() => const ChatRelationship(status: 'NONE');

  factory ChatRelationship.fromJson(Map<String, dynamic> json) {
    return ChatRelationship(
      conversationId: json['conversationId']?.toString(),
      status: json['status']?.toString() ?? 'NONE',
      outgoing: json['outgoing'] == true,
      blocked: json['blocked'] == true,
    );
  }
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.otherUserId,
    required this.otherDisplayName,
    this.otherUsername = '',
    required this.status,
    this.outgoing = false,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.context = 'SOCIAL',
    this.listingTitle,
    this.listingPriceLabel,
    this.otherAvatarUrl,
  });

  final String id;
  final String otherUserId;
  final String otherDisplayName;
  final String otherUsername;
  final String status;
  final bool outgoing;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String context;
  final String? listingTitle;
  final String? listingPriceLabel;
  final String? otherAvatarUrl;

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Pendiente';
      case 'ACTIVE':
        return 'Activo';
      case 'REJECTED':
        return 'Rechazado';
      default:
        return '';
    }
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      otherUserId: json['otherUserId']?.toString() ?? '',
      otherDisplayName: json['otherDisplayName']?.toString() ?? '',
      otherUsername: json['otherUsername']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      outgoing: json['outgoing'] == true,
      lastMessagePreview: json['lastMessagePreview']?.toString(),
      lastMessageAt: parseGarraInstant(json['lastMessageAt']?.toString() ?? ''),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      context: json['context']?.toString() ?? 'SOCIAL',
      listingTitle: json['listingTitle']?.toString(),
      listingPriceLabel: json['listingPriceLabel']?.toString(),
      otherAvatarUrl: json['otherAvatarUrl']?.toString(),
    );
  }
}

class ChatMediaItem {
  const ChatMediaItem({
    required this.assetId,
    required this.url,
    required this.contentType,
    required this.kind,
  });

  final String assetId;
  final String url;
  final String contentType;
  final String kind;

  bool get isVideo => kind == 'VIDEO';

  factory ChatMediaItem.fromJson(Map<String, dynamic> json) {
    return ChatMediaItem(
      assetId: json['assetId']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'IMAGE',
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.mine,
    this.createdAt,
    this.media = const [],
    this.read = false,
    this.reactions = const [],
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool mine;
  final DateTime? createdAt;
  final List<ChatMediaItem> media;

  /// Backend `MessageResponse.read` (recipient opened the thread). Shown as
  /// the Enviado / read receipt on own messages only; there is no read time.
  final bool read;

  /// CHAT_REACTIONS_13: per-type summary (count > 0 only, no user ids).
  final List<ChatMessageReactionSummary> reactions;

  /// Deterministic per-message reaction state, used by the polling diff.
  String get reactionSignature => chatReactionSignature(reactions);

  ChatMessage copyWith({List<ChatMessageReactionSummary>? reactions}) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      mine: mine,
      createdAt: createdAt,
      media: media,
      read: read,
      reactions: reactions ?? this.reactions,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      mine: json['mine'] == true,
      createdAt: parseGarraInstant(json['createdAt']?.toString() ?? ''),
      read: json['read'] == true,
      media: (json['media'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ChatMediaItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      reactions: parseChatReactions(json['reactions']),
    );
  }
}

/// CHAT_REACTIONS_13: one reaction type on a message. [type] is the backend
/// API value of a global [ReactionType]; the chat picker only offers six, but
/// any valid global type received from the server is shown read-only.
class ChatMessageReactionSummary {
  const ChatMessageReactionSummary({
    required this.type,
    required this.count,
    this.reactedByMe = false,
  });

  final String type;
  final int count;
  final bool reactedByMe;

  ReactionType? get reactionType => ReactionType.tryParse(type);
}

/// Parses `reactions` safely: unknown types, non-positive counts, malformed
/// entries and duplicates are skipped (never throws).
List<ChatMessageReactionSummary> parseChatReactions(dynamic raw) {
  if (raw is! List) return const [];
  final seen = <String>{};
  final out = <ChatMessageReactionSummary>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final type = ReactionType.tryParse(item['type']?.toString());
    final count = item['count'];
    if (type == null || count is! num || count.toInt() <= 0) continue;
    if (!seen.add(type.apiValue)) continue;
    out.add(
      ChatMessageReactionSummary(
        type: type.apiValue,
        count: count.toInt(),
        reactedByMe: item['reactedByMe'] == true,
      ),
    );
  }
  return List.unmodifiable(out);
}

/// Stable signature (sorted by type) of a reaction summary.
String chatReactionSignature(List<ChatMessageReactionSummary> reactions) {
  if (reactions.isEmpty) return '';
  final parts = [
    for (final r in reactions) '${r.type}:${r.count}:${r.reactedByMe ? 1 : 0}',
  ]..sort();
  return parts.join('|');
}

/// The viewer's current reaction (API value), if any.
String? myChatReaction(List<ChatMessageReactionSummary> reactions) {
  for (final r in reactions) {
    if (r.reactedByMe) return r.type;
  }
  return null;
}

/// Local (optimistic) result of setting the viewer's reaction to [next]
/// (`null` removes it). Other people's reactions are kept as they are.
List<ChatMessageReactionSummary> withMyChatReaction(
  List<ChatMessageReactionSummary> current,
  String? next,
) {
  final out = <ChatMessageReactionSummary>[];
  var placed = false;
  for (final r in current) {
    var count = r.count;
    var mine = r.reactedByMe;
    if (mine) {
      count -= 1;
      mine = false;
    }
    if (next != null && r.type == next) {
      count += 1;
      mine = true;
      placed = true;
    }
    if (count > 0) {
      out.add(
        ChatMessageReactionSummary(
          type: r.type,
          count: count,
          reactedByMe: mine,
        ),
      );
    }
  }
  if (next != null && !placed) {
    out.add(
      ChatMessageReactionSummary(type: next, count: 1, reactedByMe: true),
    );
  }
  return List.unmodifiable(out);
}

/// Small PUT/DELETE reaction response.
class ChatMessageReactionsResult {
  const ChatMessageReactionsResult({
    required this.messageId,
    this.reactions = const [],
    this.myReaction,
  });

  final String messageId;
  final List<ChatMessageReactionSummary> reactions;
  final String? myReaction;

  factory ChatMessageReactionsResult.fromJson(Map<String, dynamic> json) {
    return ChatMessageReactionsResult(
      messageId: json['messageId']?.toString() ?? '',
      reactions: parseChatReactions(json['reactions']),
      myReaction: ReactionType.tryParse(
        json['myReaction']?.toString(),
      )?.apiValue,
    );
  }
}

/// COMMUNITY_GROUP_CHAT_14C: `GET /chat/unread-count`. [unreadCount] is the
/// backend total (private + community) and the only value the global badge
/// shows; the split is informative (inbox segment badges). Older backends
/// without the split count everything as private.
class ChatUnreadSummary {
  const ChatUnreadSummary({
    this.unreadCount = 0,
    int? directUnreadCount,
    this.communityUnreadCount = 0,
  }) : directUnreadCount = directUnreadCount ?? unreadCount;

  static const ChatUnreadSummary zero = ChatUnreadSummary();

  final int unreadCount;
  final int directUnreadCount;
  final int communityUnreadCount;

  factory ChatUnreadSummary.fromJson(Map<String, dynamic> json) {
    int? read(String key) {
      final value = json[key];
      return value is num ? value.toInt() : null;
    }

    return ChatUnreadSummary(
      unreadCount: read('unreadCount') ?? 0,
      directUnreadCount: read('directUnreadCount'),
      communityUnreadCount: read('communityUnreadCount') ?? 0,
    );
  }
}
