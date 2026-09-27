import 'reaction_type.dart';

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

  bool get isEdited => editedAt != null && editedAt!.isNotEmpty;

  factory WallCommentModel.fromJson(Map<String, dynamic> json) {
    final rawReaction = json['myReaction']?.toString().trim();
    return WallCommentModel(
      id: json['id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      username: json['username']?.toString() ??
          json['authorUsername']?.toString() ??
          '',
      fullName: json['fullName']?.toString() ??
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
    );
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
            (e) => WallCommentModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      size: (page['size'] as num?)?.toInt() ?? rawItems.length,
      hasNext: page['hasNext'] as bool? ?? false,
      nextCursor: page['nextCursor']?.toString(),
    );
  }
}
