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

  factory WallCommentModel.fromJson(Map<String, dynamic> json) {
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
