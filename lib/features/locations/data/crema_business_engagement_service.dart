import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'crema_business_offer_models.dart';

class CremaBusinessEngagementService {
  CremaBusinessEngagementService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<void> follow(String pointId) async {
    await _dio.post('/locations/points/$pointId/follow');
  }

  Future<void> unfollow(String pointId) async {
    await _dio.delete('/locations/points/$pointId/follow');
  }

  Future<List<String>> followingIds() async {
    final response = await _dio.get('/locations/points/following/me');
    final List data = response.data['data'] ?? [];
    return data.map((e) => e.toString()).toList();
  }

  Future<List<CremaBusinessOffer>> listOffers({
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final response = await _dio.get(
      '/locations/offers',
      queryParameters: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusKm != null) 'radiusKm': radiusKm,
      },
    );
    final List data = response.data['data'] ?? [];
    return data
        .map((e) => CremaBusinessOffer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Owner manage list (DRAFT / ACTIVE / EXPIRED / CANCELLED) for one point.
  Future<List<CremaBusinessOffer>> listPointOffers(String pointId) async {
    final response = await _dio.get('/locations/points/$pointId/offers');
    final List data = response.data['data'] ?? [];
    return data
        .map((e) => CremaBusinessOffer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Owner manage list (DRAFT / ACTIVE / EXPIRED / CANCELLED) for one point.
  Future<List<CremaBusinessOffer>> listOwnedOffers(String pointId) async {
    final response = await _dio.get('/locations/points/$pointId/offers/manage');
    final List data = response.data['data'] ?? [];
    return data
        .map((e) => CremaBusinessOffer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CremaBusinessOffer> createOffer({
    required String pointId,
    required String title,
    required String description,
    DateTime? startsAt,
    DateTime? endsAt,
    String? mediaAssetId,
  }) async {
    final response = await _dio.post(
      '/locations/points/$pointId/offers',
      data: {
        'title': title,
        'description': description,
        if (startsAt != null) 'startsAt': startsAt.toUtc().toIso8601String(),
        if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
        if (mediaAssetId != null) 'mediaAssetId': mediaAssetId,
      },
    );
    return CremaBusinessOffer.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<CremaBusinessOffer> publishOffer(String offerId) async {
    final response = await _dio.post('/locations/offers/$offerId/publish');
    return CremaBusinessOffer.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<CremaBusinessOffer> cancelOffer(String offerId) async {
    final response = await _dio.post('/locations/offers/$offerId/cancel');
    return CremaBusinessOffer.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<CremaBusinessOffer> updateDraftOffer({
    required String offerId,
    required String title,
    required String description,
    DateTime? startsAt,
    DateTime? endsAt,
    String? mediaAssetId,
  }) async {
    final response = await _dio.put(
      '/locations/offers/$offerId',
      data: {
        'title': title,
        'description': description,
        if (startsAt != null) 'startsAt': startsAt.toUtc().toIso8601String(),
        if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
        if (mediaAssetId != null) 'mediaAssetId': mediaAssetId,
      },
    );
    return CremaBusinessOffer.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }
}
