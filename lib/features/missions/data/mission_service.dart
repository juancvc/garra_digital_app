import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'mission_models.dart';

class MissionService {
  MissionService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<MissionModel>> getMyMissions({
    String? matchId,
    bool active = true,
  }) async {
    final response = await _dio.get(
      '/missions/me',
      queryParameters: {
        if (matchId != null && matchId.isNotEmpty) 'matchId': matchId,
        'active': active,
      },
    );
    final List data = response.data['data'] as List? ?? const [];
    return data
        .map((e) => MissionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<MissionModel>> getMyMissionsForMatch(
    String matchId, {
    bool active = true,
  }) async {
    final response = await _dio.get(
      '/matches/$matchId/missions/me',
      queryParameters: {'active': active},
    );
    final List data = response.data['data'] as List? ?? const [];
    return data
        .map((e) => MissionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
