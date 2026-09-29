import 'reaction_type.dart';

class WallPostModel {
  const WallPostModel({
    required this.id,
    this.matchId = '',
    required this.username,
    required this.fullName,
    required this.content,
    required this.imageUrl,
    required this.locationTag,
    required this.status,
    required this.reportCount,
    required this.createdAt,
    this.reactionSummary = const {},
    this.reactionCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.myReaction,
    this.contextType = 'MATCH',
    this.clanSlug,
    this.clanName,
    this.authorId,
    this.savedByMe = false,
    this.isMine = false,
    this.media = const [],
    this.shareCount = 0,
    this.sharedByMe = false,
    this.originalPost,
  });

  final String id;
  final String matchId;
  final String username;
  final String fullName;
  final String content;
  final String? imageUrl;
  final String locationTag;
  final String status;
  final int reportCount;
  final String createdAt;
  final Map<String, int> reactionSummary;
  final int reactionCount;
  final int commentCount;

  /// ANALYTICS_12: unique views (viewer+post, rolling 24h), backend-counted.
  final int viewCount;
  final String? myReaction;
  final String contextType;
  final String? clanSlug;
  final String? clanName;
  final String? authorId;
  final bool savedByMe;
  final bool isMine;
  final List<WallPostMediaItem> media;
  final int shareCount;
  final bool sharedByMe;
  final SharedOriginalPostModel? originalPost;

  bool get isShare => originalPost != null;

  bool get isClanContext => contextType.toUpperCase() == 'CLAN';

  factory WallPostModel.fromJson(Map<String, dynamic> json) {
    final context = json['context'] is Map
        ? Map<String, dynamic>.from(json['context'] as Map)
        : const <String, dynamic>{};
    final contextType =
        (json['contextType'] ?? context['type'] ?? 'MATCH')?.toString() ??
            'MATCH';
    final mediaRaw = json['media'];
    final media = <WallPostMediaItem>[];
    if (mediaRaw is List) {
      for (final item in mediaRaw) {
        if (item is Map) {
          media.add(WallPostMediaItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return WallPostModel(
      id: json['id']?.toString() ?? '',
      matchId: (json['matchId'] ?? context['matchId'])?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ??
          (media.isNotEmpty ? media.first.url : null),
      locationTag: json['locationTag']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
      reactionSummary: parseReactionSummary(json['reactionSummary']),
      reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      myReaction: json['myReaction']?.toString(),
      contextType: contextType,
      clanSlug: (json['clanSlug'] ?? context['clanSlug'])?.toString(),
      clanName: (json['clanName'] ?? context['clanName'])?.toString(),
      authorId: (json['authorId'] ?? json['fanUserId'] ?? json['userId'])
          ?.toString(),
      savedByMe: json['savedByMe'] == true,
      isMine: json['isMine'] == true,
      media: media,
      shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
      sharedByMe: json['sharedByMe'] == true,
      originalPost: json['originalPost'] is Map
          ? SharedOriginalPostModel.fromJson(Map<String, dynamic>.from(json['originalPost'] as Map))
          : null,
    );
  }

  WallPostModel copyWith({
    String? id,
    String? matchId,
    String? username,
    String? fullName,
    String? content,
    String? imageUrl,
    String? locationTag,
    String? status,
    int? reportCount,
    String? createdAt,
    Map<String, int>? reactionSummary,
    int? reactionCount,
    int? commentCount,
    int? viewCount,
    String? myReaction,
    bool clearMyReaction = false,
    String? contextType,
    String? clanSlug,
    String? clanName,
    String? authorId,
    bool? savedByMe,
    bool? isMine,
    List<WallPostMediaItem>? media,
    int? shareCount,
    bool? sharedByMe,
    SharedOriginalPostModel? originalPost,
  }) {
    return WallPostModel(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      locationTag: locationTag ?? this.locationTag,
      status: status ?? this.status,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt ?? this.createdAt,
      reactionSummary: reactionSummary ?? this.reactionSummary,
      reactionCount: reactionCount ?? this.reactionCount,
      commentCount: commentCount ?? this.commentCount,
      viewCount: viewCount ?? this.viewCount,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      contextType: contextType ?? this.contextType,
      clanSlug: clanSlug ?? this.clanSlug,
      clanName: clanName ?? this.clanName,
      authorId: authorId ?? this.authorId,
      savedByMe: savedByMe ?? this.savedByMe,
      isMine: isMine ?? this.isMine,
      media: media ?? this.media,
      shareCount: shareCount ?? this.shareCount,
      sharedByMe: sharedByMe ?? this.sharedByMe,
      originalPost: originalPost ?? this.originalPost,
    );
  }
}

class SharedOriginalPostModel {
  const SharedOriginalPostModel({required this.id, required this.authorId,
    required this.username, required this.fullName, required this.content,
    this.imageUrl, this.media = const [], this.shareCount = 0,
    this.createdAt = '', this.reactionSummary = const {}, this.reactionCount = 0,
    this.commentCount = 0, this.myReaction, this.viewCount = 0,
    this.sharedByMe = false});

  final String id;
  final String authorId;
  final String username;
  final String fullName;
  final String content;
  final String? imageUrl;
  final List<WallPostMediaItem> media;
  final int shareCount;
  final String createdAt;
  final Map<String, int> reactionSummary;
  final int reactionCount;
  final int commentCount;
  final String? myReaction;
  final int viewCount;
  final bool sharedByMe;

  WallPostModel asPost() => WallPostModel(
    id: id, username: username, fullName: fullName, content: content,
    imageUrl: imageUrl, locationTag: 'HOME', status: 'ACTIVE', reportCount: 0,
    createdAt: createdAt, authorId: authorId, media: media,
    shareCount: shareCount, sharedByMe: sharedByMe,
    reactionSummary: reactionSummary, reactionCount: reactionCount,
    commentCount: commentCount, myReaction: myReaction, viewCount: viewCount,
  );

  factory SharedOriginalPostModel.fromJson(Map<String, dynamic> json) =>
      SharedOriginalPostModel(
        id: json['id']?.toString() ?? '',
        authorId: json['authorId']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
        media: (json['media'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => WallPostMediaItem.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt']?.toString() ?? '',
        reactionSummary: parseReactionSummary(json['reactionSummary']),
        reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        myReaction: json['myReaction']?.toString(),
        viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
        sharedByMe: json['sharedByMe'] == true,
      );

  SharedOriginalPostModel copyWith({int? shareCount, bool? sharedByMe,
    Map<String, int>? reactionSummary, int? reactionCount, int? commentCount,
    String? myReaction, bool clearMyReaction = false}) => SharedOriginalPostModel(
      id: id, authorId: authorId, username: username, fullName: fullName,
      content: content, imageUrl: imageUrl, media: media,
      shareCount: shareCount ?? this.shareCount,
      sharedByMe: sharedByMe ?? this.sharedByMe,
      createdAt: createdAt,
      reactionSummary: reactionSummary ?? this.reactionSummary,
      reactionCount: reactionCount ?? this.reactionCount,
      commentCount: commentCount ?? this.commentCount,
      myReaction: clearMyReaction ? null : myReaction ?? this.myReaction,
      viewCount: viewCount,
    );
}

class WallPostMediaItem {
  const WallPostMediaItem({
    required this.id,
    required this.url,
    this.sortOrder = 0,
    this.mediaAssetId,
  });

  final String id;
  final String url;
  final int sortOrder;
  final String? mediaAssetId;

  factory WallPostMediaItem.fromJson(Map<String, dynamic> json) {
    return WallPostMediaItem(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      mediaAssetId: json['mediaAssetId']?.toString(),
    );
  }
}
