import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
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
  bool Function()? canUpload,
  CancelToken? cancelToken,
}) async {
  if (drafts.length >= chatMaxImages) return;
  final files = await media.pickMultiImage(max: chatMaxImages - drafts.length);
  for (var index = 0; index < files.length; index++) {
    if (drafts.length >= chatMaxImages) break;
    if (canUpload != null && !canUpload()) {
      update(() {
        for (final file in files.skip(index)) {
          if (drafts.length >= chatMaxImages) break;
          drafts.add(
            MediaDraft(
              localId: file.path,
              localPath: file.path,
              state: MediaUploadState.failed,
            ),
          );
        }
      });
      return;
    }
    final file = files[index];
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
      canStartRemote: canUpload,
      cancelToken: cancelToken,
    );
    track(result);
  }
}

/// Retries only when the user taps a failed photo; keeps its composer slot.
Future<void> retryChatImage({
  required MediaUploadService media,
  required List<MediaDraft> drafts,
  required MediaDraft failed,
  required void Function(void Function() change) update,
  bool Function()? canUpload,
  CancelToken? cancelToken,
}) async {
  final path = failed.localPath;
  if (path == null || (canUpload != null && !canUpload())) return;
  var current = failed;
  void track(MediaDraft next) {
    update(() {
      final index = drafts.indexOf(current);
      if (index >= 0) drafts[index] = next;
      current = next;
    });
  }
  final result = await media.uploadFile(
    file: XFile(path),
    purpose: MediaUploadPurpose.chatImage,
    onUpdate: track,
    canStartRemote: canUpload,
    cancelToken: cancelToken,
  );
  track(result);
}
