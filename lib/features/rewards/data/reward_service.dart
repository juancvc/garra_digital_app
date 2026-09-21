import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/dio_client.dart';
import '../../marketplace/data/marketplace_media_service.dart';
import 'reward_models.dart';

class RewardService {
  RewardService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<RewardOffer>> catalog({bool? available}) async {
    final response = await _dio.get(
      '/rewards',
      queryParameters: {
        if (available != null) 'available': available,
      },
    );
    final data = response.data['data'];
    final items = data is Map ? data['items'] as List? ?? const [] : const [];
    return items
        .map((e) => RewardOffer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RewardOffer> detail(String slug) async {
    final response = await _dio.get('/rewards/$slug');
    final data = response.data['data'];
    return RewardOffer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<RewardRedemption> redeem(String slug, {String? idempotencyKey}) async {
    final key = idempotencyKey ?? const Uuid().v4();
    final response = await _dio.post(
      '/rewards/$slug/redeem',
      options: Options(headers: {'Idempotency-Key': key}),
    );
    final data = response.data['data'];
    return RewardRedemption.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<RewardRedemption>> myRedemptions() async {
    final response = await _dio.get('/rewards/me');
    final data = response.data['data'];
    final items = data is Map ? data['items'] as List? ?? const [] : const [];
    return items
        .map((e) =>
            RewardRedemption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> trackImpression(String rewardId, {String? activationId}) async {
    try {
      await _dio.post(
        '/rewards/$rewardId/impression',
        queryParameters: {
          if (activationId != null && activationId.isNotEmpty)
            'activationId': activationId,
        },
        data: {'sessionId': MarketplaceMediaService.analyticsSessionId()},
      );
    } catch (_) {}
  }

  Future<void> trackOpen(String rewardId, {String? activationId}) async {
    try {
      await _dio.post(
        '/rewards/$rewardId/open',
        queryParameters: {
          if (activationId != null && activationId.isNotEmpty)
            'activationId': activationId,
        },
        data: {'sessionId': MarketplaceMediaService.analyticsSessionId()},
      );
    } catch (_) {}
  }
}
