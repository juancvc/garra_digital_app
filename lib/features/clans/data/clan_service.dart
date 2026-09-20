import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'clan_models.dart';

class ClanService {
  ClanService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<ClanPage<ClanModel>> discoverClans({
    String? search,
    String? city,
    String? countryCode,
    String? cursor,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/clans',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (countryCode != null && countryCode.trim().isNotEmpty)
          'countryCode': countryCode.trim(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'size': size,
      },
    );
    return _parseClanPage(response.data, ClanModel.fromJson);
  }

  Future<ClanModel> getClan(String slug) async {
    final response = await _dio.get('/clans/$slug');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return ClanModel.fromJson(data);
  }

  Future<ClanModel> createClan(CreateClanRequest request) async {
    final response = await _dio.post('/clans', data: request.toJson());
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return ClanModel.fromJson(data);
  }

  Future<ClanModel> updateClan(String slug, UpdateClanRequest request) async {
    final response = await _dio.patch(
      '/clans/$slug',
      data: request.toJson(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return ClanModel.fromJson(data);
  }

  Future<List<MyClanMembership>> getMyClans() async {
    final response = await _dio.get('/clans/me');
    final raw = response.data['data'];
    if (raw is List) {
      return raw
          .map(
            (e) => MyClanMembership.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
    if (raw is Map) {
      final items = raw['items'] as List? ?? const [];
      return items
          .map(
            (e) => MyClanMembership.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
    return const [];
  }

  Future<void> setPrimaryClan(String slug) async {
    await _dio.patch('/clans/me/primary', data: {'slug': slug});
  }

  Future<ClanModel> joinClan(String slug) async {
    final response = await _dio.post('/clans/$slug/join');
    final data = response.data['data'];
    if (data is Map) {
      return ClanModel.fromJson(Map<String, dynamic>.from(data));
    }
    return getClan(slug);
  }

  Future<void> leaveClan(String slug) async {
    try {
      await _dio.delete('/clans/$slug/membership');
    } on DioException catch (e) {
      throw ClanServiceException(_friendlyLeaveError(e));
    }
  }

  Future<ClanPage<ClanMemberModel>> getMembers(
    String slug, {
    String? cursor,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/clans/$slug/members',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'size': size,
      },
    );
    return _parsePage(response.data, ClanMemberModel.fromJson);
  }

  Future<List<ClanJoinRequestModel>> getJoinRequests(String slug) async {
    final response = await _dio.get('/clans/$slug/join-requests');
    final raw = response.data['data'];
    final List items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      items = raw['items'] as List? ?? const [];
    } else {
      items = const [];
    }
    return items
        .map(
          (e) => ClanJoinRequestModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> approveJoinRequest(String slug, String requestId) async {
    await _dio.post('/clans/$slug/join-requests/$requestId/approve');
  }

  Future<void> rejectJoinRequest(String slug, String requestId) async {
    await _dio.post('/clans/$slug/join-requests/$requestId/reject');
  }

  Future<List<ClanInvitationModel>> getMyInvitations() async {
    final response = await _dio.get('/clans/me/invitations');
    final raw = response.data['data'];
    final List items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      items = raw['items'] as List? ?? const [];
    } else {
      items = const [];
    }
    return items
        .map(
          (e) => ClanInvitationModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> acceptInvitation(String invitationId) async {
    await _dio.post('/clans/invitations/$invitationId/accept');
  }

  Future<void> declineInvitation(String invitationId) async {
    await _dio.post('/clans/invitations/$invitationId/decline');
  }

  Future<void> inviteMember(String slug, String username) async {
    await _dio.post(
      '/clans/$slug/invitations',
      data: {'username': username},
    );
  }

  Future<void> transferOwnership(String slug, String username) async {
    await _dio.post(
      '/clans/$slug/ownership-transfer',
      data: {'username': username},
    );
  }

  Future<void> updateMemberRole(
    String slug,
    String username,
    String role,
  ) async {
    await _dio.patch(
      '/clans/$slug/members/$username/role',
      data: {'role': role},
    );
  }

  Future<void> removeMember(String slug, String username) async {
    await _dio.delete('/clans/$slug/members/$username');
  }

  ClanPage<ClanModel> _parseClanPage(
    dynamic responseData,
    ClanModel Function(Map<String, dynamic>) mapper,
  ) {
    return _parsePage(responseData, mapper);
  }

  ClanPage<T> _parsePage<T>(
    dynamic responseData,
    T Function(Map<String, dynamic>) mapper,
  ) {
    final envelope = responseData is Map
        ? Map<String, dynamic>.from(responseData)
        : <String, dynamic>{};
    final data = envelope['data'];

    if (data is List) {
      return ClanPage(
        items: data
            .map((e) => mapper(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final items = map['items'] as List? ?? const [];
      final page = map['page'] is Map
          ? Map<String, dynamic>.from(map['page'] as Map)
          : map;
      return ClanPage(
        items: items
            .map((e) => mapper(Map<String, dynamic>.from(e as Map)))
            .toList(),
        nextCursor: (page['nextCursor'] ?? map['nextCursor'])?.toString(),
        hasNext: page['hasNext'] as bool? ?? map['hasNext'] as bool? ?? false,
      );
    }

    return ClanPage(items: const []);
  }

  String _friendlyLeaveError(DioException e) {
    final status = e.response?.statusCode;
    final message = _extractMessage(e);
    final lower = message.toLowerCase();
    if (status == 409 ||
        lower.contains('owner') ||
        lower.contains('ownership') ||
        lower.contains('propiet')) {
      return 'Para salir del clan, primero debes transferir la propiedad '
          'a otro miembro.';
    }
    if (message.isNotEmpty) return message;
    return 'No pudimos procesar tu salida del clan. Inténtalo de nuevo.';
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['message']?.toString() ?? '';
    }
    return '';
  }
}

class ClanServiceException implements Exception {
  ClanServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
