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

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      otherUserId: json['otherUserId']?.toString() ?? '',
      otherDisplayName: json['otherDisplayName']?.toString() ?? '',
      otherUsername: json['otherUsername']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      outgoing: json['outgoing'] == true,
      lastMessagePreview: json['lastMessagePreview']?.toString(),
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? ''),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
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
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool mine;
  final DateTime? createdAt;
  final List<ChatMediaItem> media;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      mine: json['mine'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      media: (json['media'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ChatMediaItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}
