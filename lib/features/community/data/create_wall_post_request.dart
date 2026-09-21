class CreateWallPostRequest {
  const CreateWallPostRequest({
    required this.matchId,
    required this.content,
    required this.locationTag,
    this.imageUrl,
    this.mediaAssetId,
  });

  final String matchId;
  final String content;
  final String? imageUrl;
  final String? mediaAssetId;
  final String locationTag;

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (mediaAssetId != null) 'mediaAssetId': mediaAssetId,
      'locationTag': locationTag,
    };
  }
}
