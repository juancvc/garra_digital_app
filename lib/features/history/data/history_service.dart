import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'history_models.dart';

class HistoryService {
  HistoryService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<HistoryPageResult> getMyHistory({
    String? cursor,
    int size = 20,
    int? year,
    String? type,
  }) async {
    final response = await _dio.get(
      '/history/me',
      queryParameters: {
        'cursor': ?(cursor != null && cursor.isNotEmpty ? cursor : null),
        'size': size,
        'year': ?year,
        'type': ?(type != null && type.isNotEmpty ? type : null),
      },
    );
    final data = response.data['data'];
    if (data is Map) {
      return HistoryPageResult.fromJson(Map<String, dynamic>.from(data));
    }
    return const HistoryPageResult(items: []);
  }

  Future<List<int>> getAvailableYears() async {
    final response = await _dio.get('/history/me/years');
    final data = response.data['data'];
    if (data is List) {
      return data
          .map((e) => (e as num).toInt())
          .toList();
    }
    return const [];
  }

  Future<YearRecapModel> getYearRecap(int year) async {
    final response = await _dio.get('/history/me/year/$year');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return YearRecapModel.fromJson(data);
  }
}
