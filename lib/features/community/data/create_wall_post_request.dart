import 'post_location.dart';

class CreateWallPostRequest {
  const CreateWallPostRequest({
    required this.matchId,
    required this.content,
    required this.locationTag,
    this.imageUrl,
    this.mediaAssetId,
    this.postLocation,
  });

  final String matchId;
  final String content;
  final String? imageUrl;
  final String? mediaAssetId;
  final String locationTag;
  final PostLocation? postLocation;

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (mediaAssetId != null) 'mediaAssetId': mediaAssetId,
      'locationTag': locationTag,
      if (postLocation != null) 'postLocation': postLocation!.toJson(),
    };
  }
}
