import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../network/dio_client.dart';

enum MediaUploadPurpose {
  marketplaceListing('MARKETPLACE_LISTING'),
  storeLogo('MARKETPLACE_STORE_LOGO'),
  storeBanner('MARKETPLACE_STORE_BANNER'),
  communityPost('COMMUNITY_POST'),
  profileAvatar('PROFILE_AVATAR'),
  solidarity('SOLIDARITY_EVIDENCE'),
  // SONIC_01: business images (offer image, business cover photo) share the
  // backend purpose BUSINESS_OFFER, validated server-side like offers.
  businessMedia('BUSINESS_OFFER'),
  chatImage('CHAT_IMAGE'),
  chatAudio('CHAT_AUDIO');

  const MediaUploadPurpose(this.apiValue);
  final String apiValue;
}

enum MediaUploadState {
  selected,
  pending,
  signing,
  uploading,
  confirming,
  ready,
  failed,
}

class SignedUploadResult {
  const SignedUploadResult({
    required this.assetId,
    required this.uploadUrl,
    required this.method,
    required this.requiredHeaders,
    this.mediaUrl,
  });

  final String assetId;
  final String uploadUrl;
  final String method;
  final Map<String, String> requiredHeaders;
  final String? mediaUrl;

  factory SignedUploadResult.fromJson(Map<String, dynamic> json) {
    final headersRaw = json['requiredHeaders'];
    final headers = <String, String>{};
    if (headersRaw is Map) {
      headersRaw.forEach((k, v) {
        if (v != null) headers[k.toString()] = v.toString();
      });
    }
    return SignedUploadResult(
      assetId: json['assetId']?.toString() ?? '',
      uploadUrl: json['uploadUrl']?.toString() ?? '',
      method: json['method']?.toString() ?? 'PUT',
      requiredHeaders: headers,
      mediaUrl: json['mediaUrl']?.toString(),
    );
  }
}

class MediaDraft {
  MediaDraft({
    required this.localId,
    this.localPath,
    this.bytes,
    this.assetId,
    this.mediaUrl,
    this.state = MediaUploadState.selected,
    this.progress = 0,
    this.error,
  });

  final String localId;
  String? localPath;
  Uint8List? bytes;
  String? assetId;
  String? mediaUrl;
  MediaUploadState state;
  double progress;
  String? error;

  bool get isReady =>
      state == MediaUploadState.ready && assetId != null;
}

/// Generic media upload — never holds storage credentials.
class MediaUploadService {
  MediaUploadService({Dio? dio, Dio? binaryClient, ImagePicker? picker})
      : _dio = dio ?? DioClient.instance,
        _binaryClient = binaryClient,
        _picker = picker ?? ImagePicker();

  static const int communityPhotoLimit = 4;
  static const storageConnectTimeout = Duration(seconds: 20);
  static const storageSendTimeout = Duration(minutes: 2);
  static const storageReceiveTimeout = Duration(seconds: 30);
  static const storageTotalTimeout = Duration(minutes: 3);
  static const String uploadFailedMessage =
      'No pudimos subir la foto. Intenta nuevamente.';
  static const int chatAudioMaxBytes = 3 * 1024 * 1024;

  final Dio _dio;
  final Dio? _binaryClient;
  final ImagePicker _picker;
  final _uuid = const Uuid();

  static String? _sessionId;
  static String analyticsSessionId() {
    _sessionId ??= const Uuid().v4();
    return _sessionId!;
  }

  Future<XFile?> pickImage({double maxSide = 1920}) {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: 85,
    );
  }

  Future<XFile?> pickCamera({double maxSide = 1920}) {
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: 85,
    );
  }

  Future<MediaDraft> uploadAvatar(XFile file, {bool Function()? canStartRemote, CancelToken? cancelToken}) {
    return uploadFile(
      file: file,
      purpose: MediaUploadPurpose.profileAvatar,
      squareMax: 720,
      canStartRemote: canStartRemote,
      cancelToken: cancelToken,
    );
  }

  Future<List<XFile>> pickMultiImage({int max = 4}) async {
    final files = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (files.length <= max) return files;
    return files.take(max).toList();
  }

  Future<Uint8List> compressIfNeeded(XFile file, {int? maxSide}) async {
    final original = await file.readAsBytes();
    if (maxSide == null && original.lengthInBytes <= 1.5 * 1024 * 1024) {
      return original;
    }
    final dir = await getTemporaryDirectory();
    final target = '${dir.path}/garra_${_uuid.v4()}.jpg';
    final side = maxSide ?? 1600;
    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.path,
      target,
      quality: maxSide == null ? 82 : 78,
      minWidth: side,
      minHeight: side,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) return original;
    return compressed.readAsBytes();
  }

  Future<SignedUploadResult> createSignedUpload({
    required MediaUploadPurpose purpose,
    required String contentType,
    required int sizeBytes,
    String fileName = 'photo.jpg',
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      '/media/uploads',
      cancelToken: cancelToken,
      data: {
        'purpose': purpose.apiValue,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return SignedUploadResult.fromJson(data);
  }

  Future<void> putBytes({
    required SignedUploadResult signed,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final put = _binaryClient ?? Dio(BaseOptions(connectTimeout: storageConnectTimeout));
    final token = cancelToken ?? CancelToken();
    final deadline = Timer(storageTotalTimeout, () => token.cancel('Storage upload timeout'));
    try {
      await put.put(
      signed.uploadUrl,
      data: bytes,
      options: Options(
        sendTimeout: storageSendTimeout,
        receiveTimeout: storageReceiveTimeout,
        headers: {
          ...signed.requiredHeaders,
          'Content-Length': bytes.length,
        },
        contentType: signed.requiredHeaders['Content-Type'] ?? 'image/jpeg',
      ),
      cancelToken: token,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
      );
    } finally {
      deadline.cancel();
    }
  }

  Future<String?> confirm(String assetId, {CancelToken? cancelToken}) async {
    final response = await _dio.post('/media/$assetId/confirm', cancelToken: cancelToken);
    final data = response.data['data'];
    if (data is Map) return data['mediaUrl']?.toString();
    return null;
  }

  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
    bool Function()? canStartRemote,
    CancelToken? cancelToken,
  }) async {
    final draft = MediaDraft(
      localId: _uuid.v4(),
      localPath: file.path,
      state: MediaUploadState.pending,
    );
    onUpdate?.call(draft);
    try {
      final bytes = await compressIfNeeded(file, maxSide: squareMax);
      draft.bytes = bytes;
      draft.state = MediaUploadState.signing;
      onUpdate?.call(draft);
      if (canStartRemote != null && !canStartRemote()) throw StateError('Offline');
      if (kDebugMode) {
        debugPrint(
          '[MEDIA] stage=signed purpose=${purpose.apiValue} '
          'correlationId=${DioClient.lastCorrelationId}',
        );
      }
      final signed = await createSignedUpload(
        purpose: purpose,
        contentType: 'image/jpeg',
        sizeBytes: bytes.length,
        cancelToken: cancelToken,
      );
      draft.assetId = signed.assetId;
      if (canStartRemote != null && !canStartRemote()) throw StateError('Offline');
      draft.state = MediaUploadState.uploading;
      onUpdate?.call(draft);
      await putBytes(
        signed: signed,
        bytes: bytes,
        cancelToken: cancelToken,
        onProgress: (p) {
          draft.progress = p;
          onUpdate?.call(draft);
        },
      );
      if (canStartRemote != null && !canStartRemote()) throw StateError('Offline');
      draft.state = MediaUploadState.confirming;
      onUpdate?.call(draft);
      final url = await confirm(signed.assetId, cancelToken: cancelToken);
      draft.mediaUrl = url ?? signed.mediaUrl;
      draft.state = MediaUploadState.ready;
      draft.progress = 1;
      onUpdate?.call(draft);
      if (kDebugMode) {
        debugPrint(
          '[MEDIA] stage=ready status=ok assetId=${draft.assetId} '
          'correlationId=${DioClient.lastCorrelationId}',
        );
      }
    } catch (e) {
      draft.state = MediaUploadState.failed;
      draft.progress = 0;
      draft.error = uploadFailedMessage;
      onUpdate?.call(draft);
      if (kDebugMode) {
        debugPrint(
          '[MEDIA] stage=failed status=error '
          'correlationId=${DioClient.lastCorrelationId}',
        );
      }
    }
    return draft;
  }

  /// Audio is already encoded by the recorder; do not run image compression.
  /// A failed attempt retains its local path for an explicit user retry.
  Future<MediaDraft> uploadChatAudio({
    required String path,
    void Function(MediaDraft draft)? onUpdate,
    bool Function()? canStartRemote,
    CancelToken? cancelToken,
  }) async {
    final draft = MediaDraft(localId: _uuid.v4(), localPath: path,
        state: MediaUploadState.pending);
    onUpdate?.call(draft);
    try {
      final file = XFile(path);
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > chatAudioMaxBytes) {
        throw StateError('Audio size out of range');
      }
      draft.state = MediaUploadState.signing;
      onUpdate?.call(draft);
      if (canStartRemote != null && !canStartRemote()) throw StateError('Offline');
      final signed = await createSignedUpload(
        purpose: MediaUploadPurpose.chatAudio,
        contentType: 'audio/mp4',
        sizeBytes: bytes.length,
        fileName: 'message.m4a',
        cancelToken: cancelToken,
      );
      draft.assetId = signed.assetId;
      if (canStartRemote != null && !canStartRemote()) throw StateError('Offline');
      draft.state = MediaUploadState.uploading;
      onUpdate?.call(draft);
      await putBytes(signed: signed, bytes: bytes, cancelToken: cancelToken,
          onProgress: (progress) {
        draft.progress = progress;
        onUpdate?.call(draft);
      });
      if (canStartRemote != null && !canStartRemote()) throw StateError('Offline');
      draft.state = MediaUploadState.confirming;
      onUpdate?.call(draft);
      draft.mediaUrl = await confirm(signed.assetId, cancelToken: cancelToken);
      draft.state = MediaUploadState.ready;
      draft.progress = 1;
      onUpdate?.call(draft);
    } catch (_) {
      draft.state = MediaUploadState.failed;
      draft.progress = 0;
      draft.error = 'No pudimos subir el audio. Toca para reintentar.';
      onUpdate?.call(draft);
    }
    return draft;
  }
}
