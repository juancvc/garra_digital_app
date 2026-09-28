import '../../../core/media/media_upload_service.dart';

/// Max photos per chat message (backend + V1 product rule).
const int chatMaxImages = 4;

/// CHAT_V2_A: the single chat photo pipeline, shared by the canonical
/// conversation screen and the floating panel: gallery multi-pick, then
/// sequential upload with [MediaUploadPurpose.chatImage].
///
/// Each draft is appended to [drafts] as soon as its upload starts so the
/// composer can show progress; [update] must wrap `setState` (and ignore calls
/// after dispose). Failed uploads stay visible as failed drafts.
Future<void> pickAndUploadChatImages({
  required MediaUploadService media,
  required List<MediaDraft> drafts,
  required void Function(void Function() change) update,
}) async {
  if (drafts.length >= chatMaxImages) return;
  final files = await media.pickMultiImage(max: chatMaxImages - drafts.length);
  for (final file in files) {
    if (drafts.length >= chatMaxImages) break;
    var added = false;
    void track(MediaDraft draft) {
      update(() {
        if (!added) {
          added = true;
          if (drafts.length < chatMaxImages) drafts.add(draft);
        }
      });
    }

    final result = await media.uploadFile(
      file: file,
      purpose: MediaUploadPurpose.chatImage,
      onUpdate: track,
    );
    track(result);
  }
}
