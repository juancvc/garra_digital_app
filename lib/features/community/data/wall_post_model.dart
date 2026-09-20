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
    this.myReaction,
    this.contextType = 'MATCH',
    this.clanSlug,
    this.clanName,
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
  final String? myReaction;
  final String contextType;
  final String? clanSlug;
  final String? clanName;

  bool get isClanContext => contextType.toUpperCase() == 'CLAN';

  factory WallPostModel.fromJson(Map<String, dynamic> json) {
    final context = json['context'] is Map
        ? Map<String, dynamic>.from(json['context'] as Map)
        : const <String, dynamic>{};
    final contextType =
        (json['contextType'] ?? context['type'] ?? 'MATCH')?.toString() ??
            'MATCH';
    return WallPostModel(
      id: json['id']?.toString() ?? '',
      matchId: (json['matchId'] ?? context['matchId'])?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      locationTag: json['locationTag']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
      reactionSummary: parseReactionSummary(json['reactionSummary']),
      reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      myReaction: json['myReaction']?.toString(),
      contextType: contextType,
      clanSlug: (json['clanSlug'] ?? context['clanSlug'])?.toString(),
      clanName: (json['clanName'] ?? context['clanName'])?.toString(),
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
    String? myReaction,
    bool clearMyReaction = false,
    String? contextType,
    String? clanSlug,
    String? clanName,
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
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      contextType: contextType ?? this.contextType,
      clanSlug: clanSlug ?? this.clanSlug,
      clanName: clanName ?? this.clanName,
    );
  }
}
