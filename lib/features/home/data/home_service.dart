import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'home_models.dart';

class HomeService {
  HomeService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<HomeModel> getHome() async {
    final response = await _dio.get('/home/me');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return HomeModel.fromJson(data);
  }
}
