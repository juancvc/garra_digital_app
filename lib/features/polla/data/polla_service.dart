import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../predictions/data/create_prediction_request.dart';
import '../../predictions/data/prediction_service.dart';
import 'matchday_poll_models.dart';
import 'polla_models.dart';

class PollaService {
  PollaService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<PollaResponse> getPolla(String matchId) async {
    final response = await _dio.get('/matches/$matchId/polla');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return PollaResponse.fromJson(data);
  }

  Future<CreatePredictionResult> upsertPrediction(
    CreatePredictionRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/predictions',
        data: request.toJson(),
      );

      return CreatePredictionResult.success(
        response.data['message']?.toString() ?? 'Predicción registrada',
      );
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;

      return CreatePredictionResult.failure(
        message ?? 'No se pudo registrar la predicción',
      );
    } catch (_) {
      return CreatePredictionResult.failure('Ocurrió un error inesperado');
    }
  }

  Future<MatchdaySummary> getMatchday(String matchId) async {
    final response = await _dio.get('/matchday/$matchId');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MatchdaySummary.fromJson(data);
  }

  Future<List<MatchPoll>> listPolls(String matchId) async {
    final response = await _dio.get('/matchday/matches/$matchId/polls');
    final List data = response.data['data'] as List? ?? const [];
    return data
        .map((e) => MatchPoll.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<MatchPollResults> getPollResults(String pollId) async {
    final response = await _dio.get('/matchday/polls/$pollId/results');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MatchPollResults.fromJson(data);
  }

  Future<MatchPollResults> vote({
    required String pollId,
    required String optionId,
  }) async {
    final response = await _dio.put(
      '/matchday/polls/$pollId/vote',
      data: {'optionId': optionId},
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MatchPollResults.fromJson(data);
  }
}
