import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

/// Admin-only operations. Backend enforces ADMIN role.
class AdminCenterService {
  AdminCenterService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<Map<String, dynamic>>> moderationQueue({String? type}) async {
    final response = await _dio.get(
      '/admin/moderation/queue',
      queryParameters: {
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    final List data = response.data['data'] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> hidePost(String queueItemId, {String? note}) async {
    await _dio.post(
      '/admin/moderation/queue/$queueItemId/hide-post',
      queryParameters: {if (note != null) 'note': note},
    );
  }

  Future<void> dismissReport(String queueItemId, {String? note}) async {
    await _dio.post(
      '/admin/moderation/queue/$queueItemId/dismiss',
      queryParameters: {if (note != null) 'note': note},
    );
  }

  Future<List<Map<String, dynamic>>> pendingBusinesses() async {
    final response = await _dio.get(
      '/admin/locations/business-applications',
      queryParameters: {'status': 'PENDING'},
    );
    final List data = response.data['data'] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> verifyBusiness(String id) async {
    await _dio.post('/admin/locations/business-applications/$id/verify');
  }

  Future<void> rejectBusiness(String id, String reason) async {
    await _dio.post(
      '/admin/locations/business-applications/$id/reject',
      data: {'reason': reason},
    );
  }

  Future<List<Map<String, dynamic>>> pendingSolidarity() async {
    final response = await _dio.get('/admin/solidarity/campaigns/pending');
    final List data = response.data['data'] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> verifySolidarity(String id) async {
    await _dio.post('/admin/solidarity/campaigns/$id/verify');
  }

  Future<void> rejectSolidarity(String id, String reason) async {
    await _dio.post(
      '/admin/solidarity/campaigns/$id/reject',
      data: {'reason': reason},
    );
  }

  Future<List<Map<String, dynamic>>> pendingSellers() async {
    final response = await _dio.get('/admin/marketplace/sellers/pending');
    final List data = response.data['data'] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> pendingStores() async {
    final response = await _dio.get('/admin/marketplace/stores/pending');
    final List data = response.data['data'] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> pendingListings() async {
    final response = await _dio.get('/admin/marketplace/listings/pending');
    final List data = response.data['data'] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> approveSeller(String id) async {
    await _dio.post('/admin/marketplace/sellers/$id/approve');
  }

  Future<void> rejectSeller(String id, String reason) async {
    await _dio.post(
      '/admin/marketplace/sellers/$id/reject',
      data: {'reason': reason, 'note': reason},
    );
  }

  Future<void> approveStore(String id) async {
    await _dio.post('/admin/marketplace/stores/$id/approve');
  }

  Future<void> rejectStore(String id, String reason) async {
    await _dio.post(
      '/admin/marketplace/stores/$id/reject',
      data: {'reason': reason, 'note': reason},
    );
  }

  Future<void> approveListing(String id) async {
    await _dio.post('/admin/marketplace/listings/$id/approve');
  }

  Future<void> rejectListing(String id, String reason) async {
    await _dio.post(
      '/admin/marketplace/listings/$id/reject',
      data: {'reason': reason, 'note': reason},
    );
  }
}
