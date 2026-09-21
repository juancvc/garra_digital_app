import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'retention_models.dart';

class RetentionService {
  RetentionService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<SeasonModel?> currentSeason() async {
    final response = await _dio.get('/seasons/current');
    final data = response.data['data'];
    if (data == null) return null;
    return SeasonModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<SeasonProgressModel?> mySeasonProgress() async {
    final response = await _dio.get('/seasons/current/me');
    final data = response.data['data'];
    if (data == null) return null;
    return SeasonProgressModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<SeasonRecapModel?> seasonRecap(String seasonId) async {
    final response = await _dio.get('/seasons/$seasonId/recap/me');
    final data = response.data['data'];
    if (data == null) return null;
    return SeasonRecapModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<AchievementModel>> myAchievements() async {
    final response = await _dio.get('/achievements/me');
    final data = response.data['data'] as List? ?? const [];
    return data
        .map((e) => AchievementModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<CollectionItemModel>> myCollection({String? filter}) async {
    final response = await _dio.get(
      '/retention/collection/me',
      queryParameters: {
        if (filter != null && filter.isNotEmpty) 'filter': filter,
      },
    );
    final data = response.data['data'] as List? ?? const [];
    return data
        .map((e) =>
            CollectionItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DailyGarraModel> dailySummary() async {
    final response = await _dio.get('/retention/daily');
    final data = response.data['data'];
    return DailyGarraModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<GarraEventModel>> discoverEvents({String filter = 'WEEK'}) async {
    final response = await _dio.get(
      '/events',
      queryParameters: {'filter': filter},
    );
    final data = response.data['data'] as List? ?? const [];
    return data
        .map((e) => GarraEventModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<GarraEventModel> createEvent(Map<String, dynamic> body) async {
    final response = await _dio.post('/events', data: body);
    return GarraEventModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<GarraEventModel> markInterested(String eventId) async {
    final response = await _dio.post('/events/$eventId/interested');
    return GarraEventModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<GarraEventModel> markGoing(String eventId) async {
    final response = await _dio.post('/events/$eventId/going');
    return GarraEventModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<GarraEventModel> checkInEvent(
    String eventId, {
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.post(
      '/events/$eventId/checkin',
      data: {'latitude': latitude, 'longitude': longitude},
    );
    return GarraEventModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<InterestPreferencesModel> getInterests() async {
    final response = await _dio.get('/me/interests');
    final data = response.data['data'];
    return InterestPreferencesModel.fromJson(
        Map<String, dynamic>.from(data as Map));
  }

  Future<InterestPreferencesModel> updateInterests({
    String? city,
    String? region,
    required List<String> interests,
    bool onboardingCompleted = true,
  }) async {
    final response = await _dio.put(
      '/me/interests',
      data: {
        if (city != null) 'city': city,
        if (region != null) 'region': region,
        'interests': interests,
        'onboardingCompleted': onboardingCompleted,
      },
    );
    return InterestPreferencesModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<BusinessRatingSummary> businessReviews(String pointId) async {
    final response = await _dio.get('/locations/points/$pointId/reviews');
    return BusinessRatingSummary.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<void> upsertBusinessReview(
    String pointId, {
    required int rating,
    String? comment,
  }) async {
    await _dio.put(
      '/locations/points/$pointId/reviews/me',
      data: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
  }

  // Admin
  Future<List<SeasonModel>> adminListSeasons() async {
    final response = await _dio.get('/admin/seasons');
    final data = response.data['data'] as List? ?? const [];
    return data
        .map((e) => SeasonModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SeasonModel> adminCreateSeason({
    required String code,
    required String name,
    required String startsAt,
    required String endsAt,
    String? description,
    String? themeKey,
  }) async {
    final response = await _dio.post(
      '/admin/seasons',
      queryParameters: {
        'code': code,
        'name': name,
        'startsAt': startsAt,
        'endsAt': endsAt,
        if (description != null) 'description': description,
        if (themeKey != null) 'themeKey': themeKey,
      },
    );
    return SeasonModel.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<void> adminActivateSeason(String id) async {
    await _dio.post('/admin/seasons/$id/activate');
  }

  Future<void> adminCloseSeason(String id) async {
    await _dio.post('/admin/seasons/$id/close');
  }

  Future<List<Map<String, dynamic>>> adminListAchievements() async {
    final response = await _dio.get('/admin/achievements');
    final data = response.data['data'] as List? ?? const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> adminSetAchievementActive(String id, bool active) async {
    await _dio.post(
      '/admin/achievements/$id/active',
      queryParameters: {'active': active},
    );
  }

  Future<List<GarraEventModel>> adminPendingEvents() async {
    final response = await _dio.get('/admin/events/pending');
    final data = response.data['data'] as List? ?? const [];
    return data
        .map((e) => GarraEventModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> adminVerifyEvent(String id) async {
    await _dio.post('/admin/events/$id/verify');
  }

  Future<void> adminRejectEvent(String id, {String? reason}) async {
    await _dio.post(
      '/admin/events/$id/reject',
      queryParameters: {
        if (reason != null) 'reason': reason,
      },
    );
  }

  Future<void> adminCancelEvent(String id) async {
    await _dio.post('/admin/events/$id/cancel');
  }
}
