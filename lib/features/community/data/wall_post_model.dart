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
    );
  }
}