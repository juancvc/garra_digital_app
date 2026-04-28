import 'package:dio/dio.dart';
import 'package:garra_digital_app/features/predictions/data/prediction_model.dart';

import '../../../core/network/dio_client.dart';
import 'create_prediction_request.dart';

class PredictionService {
  PredictionService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<CreatePredictionResult> createPrediction(
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

  Future<List<PredictionModel>> getMyPredictions() async {
    final response = await _dio.get('/predictions/my');

    final List data = response.data['data'];

    return data.map((e) => PredictionModel.fromJson(e)).toList();
  }
}

class CreatePredictionResult {
  const CreatePredictionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;

  factory CreatePredictionResult.success(String message) {
    return CreatePredictionResult(
      success: true,
      message: message,
    );
  }

  factory CreatePredictionResult.failure(String message) {
    return CreatePredictionResult(
      success: false,
      message: message,
    );
  }
}