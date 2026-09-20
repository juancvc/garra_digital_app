import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/dio_client.dart';

enum MediaUploadPurpose {
  marketplaceListing('MARKETPLACE_LISTING'),
  storeLogo('MARKETPLACE_STORE_LOGO'),
  storeBanner('MARKETPLACE_STORE_BANNER');

  const MediaUploadPurpose(this.apiValue);
  final String apiValue;
}

enum ListingImageUploadState {
  selected,
  pending,
  uploading,
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

class ListingImageDraft {
  ListingImageDraft({
    required this.localId,
    this.localPath,
    this.bytes,
    this.assetId,
    this.mediaUrl,
    this.state = ListingImageUploadState.selected,
    this.progress = 0,
    this.error,
  });

  final String localId;
  String? localPath;
  Uint8List? bytes;
  String? assetId;
  String? mediaUrl;
  ListingImageUploadState state;
  double progress;
  String? error;

  bool get isReady =>
      state == ListingImageUploadState.ready && assetId != null;
}

/// Client-side media helper — never holds storage credentials.
class MarketplaceMediaService {
  MarketplaceMediaService({Dio? dio, ImagePicker? picker})
      : _dio = dio ?? DioClient.instance,
        _picker = picker ?? ImagePicker();

  final Dio _dio;
  final ImagePicker _picker;
  final _uuid = const Uuid();

  /// Analytics session id (ephemeral, not a device fingerprint).
  static String? _sessionId;
  static String analyticsSessionId() {
    _sessionId ??= const Uuid().v4();
    return _sessionId!;
  }

  Future<XFile?> pickImage() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
  }

  Future<Uint8List> compressIfNeeded(XFile file) async {
    final original = await file.readAsBytes();
    if (original.lengthInBytes <= 1.5 * 1024 * 1024) {
      return original;
    }
    final dir = await getTemporaryDirectory();
    final target = '${dir.path}/garra_${_uuid.v4()}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.path,
      target,
      quality: 78,
      minWidth: 1280,
      minHeight: 1280,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) return original;
    return compressed.readAsBytes();
  }

  Future<ListingImageDraft> pickAndPrepareDraft() async {
    final file = await pickImage();
    if (file == null) {
      throw MarketplaceMediaException('Selección cancelada');
    }
    final bytes = await compressIfNeeded(file);
    return ListingImageDraft(
      localId: _uuid.v4(),
      localPath: file.path,
      bytes: bytes,
      state: ListingImageUploadState.selected,
    );
  }

  Future<SignedUploadResult> requestSignedUpload({
    required MediaUploadPurpose purpose,
    required String fileName,
    required String contentType,
    required int sizeBytes,
  }) async {
    final response = await _dio.post(
      '/media/uploads',
      data: {
        'purpose': purpose.apiValue,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
      },
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return SignedUploadResult.fromJson(data);
  }

  Future<String> confirmUpload(String assetId) async {
    final response = await _dio.post('/media/$assetId/confirm');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return data['mediaUrl']?.toString() ?? data['id']?.toString() ?? assetId;
  }

  Future<ListingImageDraft> uploadDraft(
    ListingImageDraft draft, {
    required MediaUploadPurpose purpose,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = draft.bytes;
    if (bytes == null) {
      throw MarketplaceMediaException('No hay bytes para subir');
    }
    draft.state = ListingImageUploadState.pending;
    draft.progress = 0;
    draft.error = null;

    try {
      draft.state = ListingImageUploadState.uploading;
      final signed = await requestSignedUpload(
        purpose: purpose,
        fileName: 'image.jpg',
        contentType: 'image/jpeg',
        sizeBytes: bytes.lengthInBytes,
      );
      draft.assetId = signed.assetId;

      final uploadDio = Dio();
      await uploadDio.put(
        signed.uploadUrl,
        data: bytes,
        options: Options(
          headers: {
            ...signed.requiredHeaders,
            Headers.contentLengthHeader: bytes.lengthInBytes,
          },
          contentType: signed.requiredHeaders['Content-Type'] ?? 'image/jpeg',
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            draft.progress = sent / total;
            onProgress?.call(draft.progress);
          }
        },
      );

      final mediaUrl = await confirmUpload(signed.assetId);
      draft.mediaUrl = mediaUrl;
      draft.state = ListingImageUploadState.ready;
      draft.progress = 1;
      return draft;
    } catch (e) {
      draft.state = ListingImageUploadState.failed;
      draft.error = e.toString();
      rethrow;
    }
  }

  Future<void> attachListingImage({
    required String listingId,
    required String mediaAssetId,
    int? sortOrder,
  }) async {
    await _dio.post(
      '/marketplace/seller/me/listings/$listingId/images',
      data: {
        'mediaAssetId': mediaAssetId,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
    );
  }

  Future<void> reorderListingImages({
    required String listingId,
    required List<String> imageIds,
  }) async {
    await _dio.put(
      '/marketplace/seller/me/listings/$listingId/images/order',
      data: {'imageIds': imageIds},
    );
  }

  Future<void> removeListingImage({
    required String listingId,
    required String imageId,
  }) async {
    await _dio.delete(
      '/marketplace/seller/me/listings/$listingId/images/$imageId',
    );
  }

  Future<void> updateStoreMedia({
    String? logoMediaAssetId,
    String? bannerMediaAssetId,
    bool clearLogo = false,
    bool clearBanner = false,
  }) async {
    await _dio.put(
      '/marketplace/seller/me/store/media',
      data: {
        if (logoMediaAssetId != null) 'logoMediaAssetId': logoMediaAssetId,
        if (bannerMediaAssetId != null) 'bannerMediaAssetId': bannerMediaAssetId,
        'clearLogo': clearLogo,
        'clearBanner': clearBanner,
      },
    );
  }
}

class MarketplaceMediaException implements Exception {
  MarketplaceMediaException(this.message);
  final String message;
  @override
  String toString() => message;
}
