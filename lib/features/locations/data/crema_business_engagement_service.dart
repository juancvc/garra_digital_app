import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

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

  Future<List<Map<String, dynamic>>> listOffers({
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
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
