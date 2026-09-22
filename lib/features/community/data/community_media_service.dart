import '../../../core/media/media_upload_service.dart';

/// Community-scoped wrapper over [MediaUploadService].
class CommunityMediaService {
  CommunityMediaService({MediaUploadService? media})
      : _media = media ?? MediaUploadService();

  final MediaUploadService _media;

  MediaUploadService get core => _media;

  Future<MediaDraft> uploadCommunityPhoto({
    required dynamic file,
    void Function(MediaDraft draft)? onUpdate,
  }) {
    return _media.uploadFile(
      file: file,
      purpose: MediaUploadPurpose.communityPost,
      onUpdate: onUpdate,
    );
  }
}
