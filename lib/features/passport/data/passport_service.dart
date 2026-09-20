import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'passport_models.dart';

class PassportService {
  PassportService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<PassportModel> getMyPassport() async {
    final response = await _dio.get('/passport/me');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return PassportModel.fromJson(data);
  }

  Future<PassportModel> updateMyProfile(ProfileUpdateRequest request) async {
    await _dio.patch('/profile/me', data: request.toJson());
    return getMyPassport();
  }
}
