import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'checkin_model.dart';
import 'crema_point_model.dart';
import 'create_checkin_request.dart';

class LocationService {
  LocationService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<CremaPointModel>> getActivePoints() async {
    final response = await _dio.get('/locations/points');
    final List data = response.data['data'] ?? [];

    return data
        .map((e) => CremaPointModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CremaPointModel>> getPointsByType(String type) async {
    final response = await _dio.get('/locations/points/type/$type');
    final List data = response.data['data'] ?? [];

    return data
        .map((e) => CremaPointModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CheckInResult> createCheckIn(CreateCheckInRequest request) async {
    try {
      final response = await _dio.post(
        '/checkins',
        data: request.toJson(),
      );

      final data = response.data['data'];

      return CheckInResult.success(
        message: response.data['message']?.toString() ?? 'Check-in registrado',
        checkIn: data is Map<String, dynamic>
            ? CheckInModel.fromJson(data)
            : null,
      );
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;

      return CheckInResult.failure(
        message ?? 'No se pudo registrar el check-in',
      );
    } catch (_) {
      return CheckInResult.failure('Ocurrió un error inesperado');
    }
  }
  

  Future<List<CheckInModel>> getMyCheckIns() async {
    final response = await _dio.get('/checkins/my');

    final List data = response.data['data'] ?? [];

    return data
        .map((e) => CheckInModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}



class CheckInResult {
  const CheckInResult({
    required this.success,
    required this.message,
    this.checkIn,
  });

  final bool success;
  final String message;
  final CheckInModel? checkIn;

  factory CheckInResult.success({
    required String message,
    CheckInModel? checkIn,
  }) {
    return CheckInResult(
      success: true,
      message: message,
      checkIn: checkIn,
    );
  }

  factory CheckInResult.failure(String message) {
    return CheckInResult(
      success: false,
      message: message,
    );
  }
}

