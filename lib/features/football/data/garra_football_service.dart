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
    // SONIC_01: "today" is the Lima day, whatever the device time zone.
    final now = limaWallClock(DateTime.now());
    final response = await _dio.get('/football/matches', queryParameters: {
      'view': view.wire,
      'date': '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'offsetMinutes': limaUtcOffset.inMinutes,
      'competition': ?competition,
    });
    return FootballPage.fromJson(response.data['data'] as Map<String, dynamic>, FootballMatch.fromJson);
  }

  /// SONIC_04: featured team hero (live / next / last). Null when not configured or unavailable.
  Future<FootballFeatured?> featured() async {
    return (await featuredResult()).featured;
  }

  /// Preserves the backend snapshot state for surfaces that must not claim stale LIVE data.
  Future<FootballFeaturedResult> featuredResult() async {
    final response = await _dio.get('/football/featured');
    return FootballFeaturedResult.fromEnvelope(response.data['data']);
  }

  /// SONIC_05: Team Center for any provider team id (backend reads cached calendars only).
  Future<FootballTeamCenterResult> team(int teamId) async {
    final response = await _dio.get('/football/teams/$teamId');
    final envelope = response.data['data'];
    if (envelope is! Map<String, dynamic>) return const FootballTeamCenterResult(unavailable: true);
    final item = envelope['item'];
    return FootballTeamCenterResult(
      center: item is Map<String, dynamic> ? FootballTeamCenter.fromJson(item) : null,
      unavailable: envelope['unavailable'] == true,
      stale: envelope['stale'] == true,
      reason: envelope['reason'] is String ? envelope['reason'] as String : null,
    );
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
