import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import 'ranking_model.dart';

class RankingService {
  final Dio _dio = DioClient.instance;

  Future<List<RankingModel>> getTopRanking() async {
    final response = await _dio.get('/rankings/top');

    final List data = response.data['data'];

    return data.map((e) => RankingModel.fromJson(e)).toList();
  }
}