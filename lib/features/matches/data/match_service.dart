import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'match_model.dart';

class MatchService {
  MatchService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<MatchModel>> getUpcomingMatches() async {
    final response = await _dio.get('/matches/upcoming');

    final List<dynamic> data = response.data['data'] as List<dynamic>;

    return data
        .map((item) => MatchModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}