import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart' as core;
import 'package:garra_digital_app/features/marketplace/data/marketplace_media_service.dart' as market;
import 'package:image_picker/image_picker.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);
  final file = XFile.fromData(bytes, name: 'photo.jpg', mimeType: 'image/jpeg');

  test('core upload signs, PUTs, confirms and becomes READY', () async {
    final stages = <core.MediaUploadState>[];
    final calls = <String>[];
    final api = _api(calls);
    final storage = _storage(calls);
    final service = core.MediaUploadService(dio: api, binaryClient: storage);

    final draft = await service.uploadFile(
      file: file,
      purpose: core.MediaUploadPurpose.communityPost,
      onUpdate: (draft) => stages.add(draft.state),
    );

    expect(draft.isReady, isTrue);
    expect(draft.assetId, 'asset-1');
    expect(stages, containsAllInOrder([
      core.MediaUploadState.signing,
      core.MediaUploadState.uploading,
      core.MediaUploadState.confirming,
      core.MediaUploadState.ready,
    ]));
    expect(calls, ['sign', 'put', 'confirm']);
  });

  for (final failure in [DioExceptionType.sendTimeout, DioExceptionType.connectionError]) {
    test('core PUT $failure fails, retains draft, and only manual retry starts again', () async {
      final calls = <String>[];
      var failPut = true;
      final service = core.MediaUploadService(
        dio: _api(calls),
        binaryClient: _storage(calls, failure: () => failPut ? failure : null),
      );
      final failed = await service.uploadFile(
        file: file,
        purpose: core.MediaUploadPurpose.communityPost,
      );
      expect(failed.state, core.MediaUploadState.failed);
      expect(failed.localPath, file.path);
      expect(failed.bytes, bytes);
      expect(failed.progress, 0);
      expect(calls, ['sign', 'put']);
      failPut = false;
      final recovered = await service.uploadFile(
        file: file,
        purpose: core.MediaUploadPurpose.communityPost,
      );
      expect(recovered.isReady, isTrue);
      expect(calls, ['sign', 'put', 'sign', 'put', 'confirm']);
    });
  }

  test('confirm failure after PUT never marks READY', () async {
    final calls = <String>[];
    final service = core.MediaUploadService(
      dio: _api(calls, failConfirm: true),
      binaryClient: _storage(calls),
    );
    final draft = await service.uploadFile(
      file: file,
      purpose: core.MediaUploadPurpose.communityPost,
    );
    expect(draft.state, core.MediaUploadState.failed);
    expect(draft.isReady, isFalse);
    expect(draft.assetId, 'asset-1');
    expect(draft.bytes, bytes);
    expect(draft.progress, 0);
    expect(calls, ['sign', 'put', 'confirm']);
  });

  test('OFFLINE between sign and PUT stops the next stage', () async {
    final calls = <String>[];
    var checks = 0;
    final service = core.MediaUploadService(
      dio: _api(calls),
      binaryClient: _storage(calls),
    );
    final draft = await service.uploadFile(
      file: file,
      purpose: core.MediaUploadPurpose.communityPost,
      canStartRemote: () => ++checks == 1,
    );
    expect(draft.state, core.MediaUploadState.failed);
    expect(draft.bytes, bytes);
    expect(calls, ['sign']);
  });

  test('Marketplace PUT has explicit timeouts and recoverable draft', () async {
    final calls = <String>[];
    final draft = market.ListingImageDraft(localId: 'local', bytes: bytes);
    final service = market.MarketplaceMediaService(
      dio: _api(calls),
      binaryClient: _storage(calls, failure: () => DioExceptionType.sendTimeout),
    );
    await expectLater(
      service.uploadDraft(draft, purpose: market.MediaUploadPurpose.marketplaceListing),
      throwsA(isA<DioException>()),
    );
    expect(draft.state, market.ListingImageUploadState.failed);
    expect(draft.bytes, bytes);
    expect(draft.progress, 0);
    expect(calls, ['sign', 'put']);
  });

  test('Marketplace confirm failure keeps local image and never marks READY', () async {
    final calls = <String>[];
    final draft = market.ListingImageDraft(localId: 'local', bytes: bytes);
    final service = market.MarketplaceMediaService(
      dio: _api(calls, failConfirm: true),
      binaryClient: _storage(calls),
    );
    await expectLater(
      service.uploadDraft(draft, purpose: market.MediaUploadPurpose.marketplaceListing),
      throwsA(isA<DioException>()),
    );
    expect(draft.state, market.ListingImageUploadState.failed);
    expect(draft.isReady, isFalse);
    expect(draft.bytes, bytes);
    expect(draft.progress, 0);
    expect(calls, ['sign', 'put', 'confirm']);
  });
}

Dio _api(List<String> calls, {bool failConfirm = false}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
    if (request.path == '/media/uploads') {
      calls.add('sign');
      handler.resolve(Response(requestOptions: request, data: {'data': {
        'assetId': 'asset-1',
        'uploadUrl': 'https://storage.example/put',
        'method': 'PUT',
        'requiredHeaders': {'Content-Type': 'image/jpeg'},
      }}));
    } else {
      calls.add('confirm');
      if (failConfirm) {
        handler.reject(DioException(requestOptions: request, type: DioExceptionType.connectionError));
      } else {
        handler.resolve(Response(requestOptions: request, data: {'data': {'mediaUrl': 'https://cdn.example/a.jpg'}}));
      }
    }
  }));
  return dio;
}

Dio _storage(List<String> calls, {DioExceptionType? Function()? failure}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
    calls.add('put');
    expect(request.sendTimeout, const Duration(minutes: 2));
    expect(request.receiveTimeout, const Duration(seconds: 30));
    final type = failure?.call();
    if (type != null) {
      handler.reject(DioException(requestOptions: request, type: type));
    } else {
      handler.resolve(Response(requestOptions: request, data: ''));
    }
  }));
  return dio;
}
