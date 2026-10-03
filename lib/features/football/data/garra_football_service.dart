import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'garra_football_models.dart';

class GarraFootballService {
  GarraFootballService({Dio? dio}) : _dio = dio ?? DioClient.instance;
  final Dio _dio;

  Future<List<FootballCompetition>> competitions() async {
    final response = await _dio.get('/football/competitions');
    return ((response.data['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FootballCompetition.fromJson).toList();
  }

  Future<FootballPage<FootballMatch>> matches(FootballView view, {String? competition}) async {
    final now = DateTime.now();
    final response = await _dio.get('/football/matches', queryParameters: {
      'view': view.wire,
      'date': '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'offsetMinutes': now.timeZoneOffset.inMinutes,
      'competition': ?competition,
    });
    return FootballPage.fromJson(response.data['data'] as Map<String, dynamic>, FootballMatch.fromJson);
  }

  Future<FootballPage<Map<String, dynamic>>> standings(String competition) async {
    final response = await _dio.get('/football/competitions/$competition/standings');
    return FootballPage.fromJson(response.data['data'] as Map<String, dynamic>, (json) => json);
  }

  Future<FootballDetail?> detail(FootballMatch match, {String? section}) async {
    final response = await _dio.get('/football/matches/${match.id}',
        queryParameters: {'competition': match.competitionId, 'section': ?section});
    final envelope = response.data['data'] as Map<String, dynamic>;
    if (envelope['unavailable'] == true || envelope['item'] == null) return null;
    return FootballDetail.fromEnvelope(envelope);
  }
}
