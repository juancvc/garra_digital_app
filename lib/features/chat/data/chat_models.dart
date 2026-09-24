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

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.mine,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool mine;
  final DateTime? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      mine: json['mine'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
