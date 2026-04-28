class CreateWallPostRequest {
  const CreateWallPostRequest({
    required this.matchId,
    required this.content,
    required this.locationTag,
    this.imageUrl,
  });

  final String matchId;
  final String content;
  final String? imageUrl;
  final String locationTag;

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'content': content,
      'imageUrl': imageUrl,
      'locationTag': locationTag,
    };
  }
}