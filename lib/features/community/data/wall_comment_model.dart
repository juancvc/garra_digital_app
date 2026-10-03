import 'reaction_type.dart';
import '../../../core/widgets/garra_official_badge.dart';
import '../../../core/widgets/mention_span.dart';

class WallCommentModel {
  const WallCommentModel({
    required this.id,
    required this.postId,
    required this.username,
    required this.fullName,
    required this.content,
    required this.createdAt,
    this.isMine = false,
    this.avatarUrl,
    this.authorId,
    this.updatedAt,
    this.editedAt,
    this.reactionCount = 0,
    this.reactionSummary = const {},
    this.myReaction,
    this.parentCommentId,
    this.replyCount = 0,
    this.replyToUsername,
    this.mentions = const [],
    this.accountType = 'STANDARD',
  });

  final String id;
  final String postId;
  final String username;
  final String fullName;
  final String content;
  final String createdAt;
  final bool isMine;
  final String? avatarUrl;
  final String? authorId;
  final String? updatedAt;

  /// Non-null once the author edited the comment.
  final String? editedAt;
  final int reactionCount;
  final Map<String, int> reactionSummary;
  final String? myReaction;

  /// Root comment of the thread (null for root comments). Threads are one
  /// level deep: the backend always stores the root here.
  final String? parentCommentId;

  /// Visible replies of a root comment (0 for replies and older payloads).
  final int replyCount;

  /// Author being answered when replying to a reply (rendered as "@usuario",
  /// never part of [content]).
  final String? replyToUsername;
  final List<MentionSpan> mentions;
  final String accountType;

  bool get isOfficial => isPlatformOfficialAccount(accountType);

  bool get isEdited => editedAt != null && editedAt!.isNotEmpty;

  bool get isReply => parentCommentId != null && parentCommentId!.isNotEmpty;

  factory WallCommentModel.fromJson(Map<String, dynamic> json) {
    final rawReaction = json['myReaction']?.toString().trim();
    return WallCommentModel(
      id: json['id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      username:
          json['username']?.toString() ??
          json['authorUsername']?.toString() ??
          '',
      fullName:
          json['fullName']?.toString() ??
          json['authorFullName']?.toString() ??
          json['displayName']?.toString() ??
          '',
      content: json['content']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      isMine: json['isMine'] as bool? ?? json['mine'] as bool? ?? false,
      avatarUrl: json['avatarUrl']?.toString(),
      authorId: json['authorId']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      editedAt: json['editedAt']?.toString(),
      reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
      reactionSummary: json['reactionSummary'] is Map
          ? parseReactionSummary(json['reactionSummary'])
          : const {},
      myReaction: rawReaction == null || rawReaction.isEmpty
          ? null
          : rawReaction.toUpperCase(),
      parentCommentId: _nonEmpty(json['parentCommentId']),
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      replyToUsername: _nonEmpty(json['replyToUsername']),
      mentions: parseMentionSpans(json['mentions']),
      accountType: json['accountType']?.toString() ?? 'STANDARD',
    );
  }

  static String? _nonEmpty(Object? raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  WallCommentModel copyWith({
    String? content,
    bool? isMine,
    String? avatarUrl,
    String? authorId,
    String? updatedAt,
    String? editedAt,
    int? reactionCount,
    Map<String, int>? reactionSummary,
    String? myReaction,
    bool clearMyReaction = false,
    int? replyCount,
    List<MentionSpan>? mentions,
  }) {
    return WallCommentModel(
      id: id,
      postId: postId,
      username: username,
      fullName: fullName,
      content: content ?? this.content,
      createdAt: createdAt,
      isMine: isMine ?? this.isMine,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authorId: authorId ?? this.authorId,
      updatedAt: updatedAt ?? this.updatedAt,
      editedAt: editedAt ?? this.editedAt,
      reactionCount: reactionCount ?? this.reactionCount,
      reactionSummary: reactionSummary ?? this.reactionSummary,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      parentCommentId: parentCommentId,
      replyCount: replyCount ?? this.replyCount,
      replyToUsername: replyToUsername,
      mentions: mentions ?? this.mentions,
      accountType: accountType,
    );
  }
}

class CommentsPageResult {
  const CommentsPageResult({
    required this.items,
    required this.size,
    required this.hasNext,
    this.nextCursor,
  });

  final List<WallCommentModel> items;
  final int size;
  final bool hasNext;
  final String? nextCursor;

  factory CommentsPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    final page = json['page'] is Map
        ? Map<String, dynamic>.from(json['page'] as Map)
        : <String, dynamic>{};

    return CommentsPageResult(
      items: rawItems
          .map(
            (e) =>
                WallCommentModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      size: (page['size'] as num?)?.toInt() ?? rawItems.length,
      hasNext: page['hasNext'] as bool? ?? false,
      nextCursor: page['nextCursor']?.toString(),
    );
  }
}
