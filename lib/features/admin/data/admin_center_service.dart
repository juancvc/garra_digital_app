import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

/// Admin-only operations. Backend enforces ADMIN role.
class AdminCenterService {
  AdminCenterService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<StagingShowcasePreview> stagingShowcasePreview() async {
    final response = await _dio.get('/admin/staging-showcase/preview');
    return StagingShowcasePreview.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<StagingShowcaseResult> activateStagingShowcase() async {
    final response = await _dio.post('/admin/staging-showcase/activate');
    return StagingShowcaseResult.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<List<Map<String, dynamic>>> moderationQueue({String? type}) async {
    final response = await _dio.get(
      '/admin/moderation/queue',
      queryParameters: {if (type != null && type.isNotEmpty) 'type': type},
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

class StagingShowcasePreview {
  const StagingShowcasePreview({
    required this.communities,
    required this.sellers,
    required this.stores,
    required this.listings,
    required this.mojibakeRecords,
  });

  final int communities;
  final int sellers;
  final int stores;
  final int listings;
  final int mojibakeRecords;

  int get totalPending => communities + sellers + stores + listings;

  factory StagingShowcasePreview.fromJson(Map<String, dynamic> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return StagingShowcasePreview(
      communities: read('communities'),
      sellers: read('sellers'),
      stores: read('stores'),
      listings: read('listings'),
      mojibakeRecords: read('mojibakeRecords'),
    );
  }
}

class StagingShowcaseResult {
  const StagingShowcaseResult({
    required this.communitiesActivated,
    required this.sellersActivated,
    required this.storesActivated,
    required this.listingsActivated,
    required this.mojibakeRecordsRepaired,
    required this.failures,
  });

  final int communitiesActivated;
  final int sellersActivated;
  final int storesActivated;
  final int listingsActivated;
  final int mojibakeRecordsRepaired;
  final List<Map<String, dynamic>> failures;

  int get activated =>
      communitiesActivated +
      sellersActivated +
      storesActivated +
      listingsActivated;

  factory StagingShowcaseResult.fromJson(Map<String, dynamic> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    final rawFailures = json['failures'];
    return StagingShowcaseResult(
      communitiesActivated: read('communitiesActivated'),
      sellersActivated: read('sellersActivated'),
      storesActivated: read('storesActivated'),
      listingsActivated: read('listingsActivated'),
      mojibakeRecordsRepaired: read('mojibakeRecordsRepaired'),
      failures: rawFailures is List
          ? rawFailures
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const [],
    );
  }
}
