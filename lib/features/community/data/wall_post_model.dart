import 'reaction_type.dart';

class WallPostModel {
  const WallPostModel({
    required this.id,
    required this.matchId,
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

  factory WallPostModel.fromJson(Map<String, dynamic> json) {
    return WallPostModel(
      id: json['id']?.toString() ?? '',
      matchId: json['matchId']?.toString() ?? '',
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
    );
  }
}
