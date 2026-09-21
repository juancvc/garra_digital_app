import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'marketplace_models.dart';
import 'marketplace_media_service.dart';

class MarketplaceService {
  MarketplaceService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<MarketplaceCategory>> getCategories() async {
    final response = await _dio.get('/marketplace/categories');
    final raw = response.data['data'];
    if (raw is List) {
      return raw
          .map(
            (e) => MarketplaceCategory.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
    if (raw is Map) {
      final items = raw['items'] as List? ?? const [];
      return items
          .map(
            (e) => MarketplaceCategory.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
    return const [];
  }

  Future<MarketplacePageResult<MarketplaceListing>> getListings({
    String? search,
    String? category,
    String? type,
    int page = 0,
    int size = 20,
    String? sort,
  }) async {
    final response = await _dio.get(
      '/marketplace/listings',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
        'page': page,
        'size': size,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
      },
    );
    return _parseListingPage(response.data);
  }

  Future<MarketplaceListing> getListing(String slug) async {
    final response = await _dio.get('/marketplace/listings/$slug');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceListing.fromJson(data);
  }

  Future<MarketplaceStore> getStore(String slug) async {
    final response = await _dio.get('/marketplace/stores/$slug');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceStore.fromJson(data);
  }

  Future<void> addFavorite(String slug) async {
    await _dio.put('/marketplace/listings/$slug/favorite');
  }

  Future<void> removeFavorite(String slug) async {
    await _dio.delete('/marketplace/listings/$slug/favorite');
  }

  Future<List<MarketplaceListing>> getFavorites() async {
    final response = await _dio.get('/marketplace/favorites');
    final raw = response.data['data'];
    if (raw is List) {
      return raw
          .map(
            (e) => MarketplaceListing.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
    if (raw is Map) {
      final items = raw['items'] as List? ?? const [];
      return items
          .map(
            (e) => MarketplaceListing.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
    return const [];
  }

  Future<MarketplaceContactResult> contactListing(
    String slug, {
    String? promotionId,
  }) async {
    try {
      final response = await _dio.post(
        '/marketplace/listings/$slug/contact',
        queryParameters: {
          if (promotionId != null && promotionId.isNotEmpty)
            'promotionId': promotionId,
        },
      );
      final data = response.data['data'];
      if (data is Map) {
        return MarketplaceContactResult.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      throw MarketplaceServiceException(
        'No pudimos obtener el contacto de WhatsApp.',
      );
    } on DioException catch (e) {
      throw MarketplaceServiceException(_friendlyContactError(e));
    }
  }

  Future<FeaturedDiscovery> getFeatured() async {
    final response = await _dio.get('/marketplace/featured');
    final data = response.data['data'];
    if (data is Map) {
      return FeaturedDiscovery.fromJson(Map<String, dynamic>.from(data));
    }
    return const FeaturedDiscovery();
  }

  Future<void> trackPromotionImpression(String promotionId) async {
    try {
      await _dio.post(
        '/marketplace/promotions/$promotionId/impression',
        data: {
          'sessionId': MarketplaceMediaService.analyticsSessionId(),
        },
      );
    } catch (_) {
      // Analytics must never block UX.
    }
  }

  Future<void> trackPromotionOpen(String promotionId) async {
    try {
      await _dio.post(
        '/marketplace/promotions/$promotionId/open',
        data: {
          'sessionId': MarketplaceMediaService.analyticsSessionId(),
        },
      );
    } catch (_) {
      // Analytics must never block navigation.
    }
  }

  Future<void> reportListing(MarketplaceReportRequest request) async {
    try {
      await _dio.post('/marketplace/reports', data: request.toJson());
    } on DioException catch (e) {
      throw MarketplaceServiceException(_extractMessage(e).isNotEmpty
          ? _extractMessage(e)
          : 'No pudimos enviar el reporte. Inténtalo de nuevo.');
    }
  }

  Future<SellerProfile?> getSellerMe() async {
    try {
      final response = await _dio.get('/marketplace/seller/me');
      final data = response.data['data'];
      if (data == null) return null;
      if (data is Map) {
        return SellerProfile.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<SellerProfile> submitSeller(SellerOnboardingRequest request) async {
    final response = await _dio.post(
      '/marketplace/seller/submit',
      data: request.toJson(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return SellerProfile.fromJson(data);
  }

  Future<SellerSummary> getSellerSummary() async {
    final response = await _dio.get('/marketplace/seller/summary');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return SellerSummary.fromJson(data);
  }

  Future<SellerPlan> getSellerPlan() async {
    final response = await _dio.get('/marketplace/seller/me/plan');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return SellerPlan.fromJson(data);
  }

  Future<SellerAdvancedAnalytics?> getSellerAdvancedAnalytics() async {
    try {
      final response =
          await _dio.get('/marketplace/seller/me/analytics/advanced');
      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      return SellerAdvancedAnalytics.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) return null;
      rethrow;
    }
  }

  Future<MarketplaceStore> getSellerStore() async {
    final response = await _dio.get('/marketplace/seller/store');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceStore.fromJson(data);
  }

  Future<MarketplaceStore> updateSellerStore(Map<String, dynamic> body) async {
    final response = await _dio.put('/marketplace/seller/store', data: body);
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceStore.fromJson(data);
  }

  Future<List<MarketplaceListing>> getSellerListings() async {
    final response = await _dio.get('/marketplace/seller/listings');
    final raw = response.data['data'];
    if (raw is List) {
      return raw
          .map(
            (e) => MarketplaceListing.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
    if (raw is Map) {
      final items = raw['items'] as List? ?? const [];
      return items
          .map(
            (e) => MarketplaceListing.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
    return const [];
  }

  Future<MarketplaceListing> createSellerListing(
    SellerListingRequest request,
  ) async {
    final response = await _dio.post(
      '/marketplace/seller/listings',
      data: request.toJson(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceListing.fromJson(data);
  }

  Future<MarketplaceListing> updateSellerListing(
    String slug,
    SellerListingRequest request,
  ) async {
    final response = await _dio.put(
      '/marketplace/seller/listings/$slug',
      data: request.toJson(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceListing.fromJson(data);
  }

  Future<void> deleteSellerListing(String slug) async {
    await _dio.delete('/marketplace/seller/listings/$slug');
  }

  Future<MarketplaceListing> submitSellerListing(String slug) async {
    final response =
        await _dio.post('/marketplace/seller/listings/$slug/submit');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceListing.fromJson(data);
  }

  MarketplacePageResult<MarketplaceListing> _parseListingPage(
    dynamic responseData,
  ) {
    final envelope = responseData is Map
        ? Map<String, dynamic>.from(responseData)
        : <String, dynamic>{};
    final data = envelope['data'];

    if (data is List) {
      return MarketplacePageResult(
        items: data
            .map(
              (e) => MarketplaceListing.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final items = map['items'] as List? ?? const [];
      final pageMeta = map['page'] is Map
          ? Map<String, dynamic>.from(map['page'] as Map)
          : map;
      return MarketplacePageResult(
        items: items
            .map(
              (e) => MarketplaceListing.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        page: (pageMeta['number'] as num?)?.toInt() ??
            (pageMeta['page'] as num?)?.toInt() ??
            0,
        size: (pageMeta['size'] as num?)?.toInt() ?? 20,
        totalElements: (pageMeta['totalElements'] as num?)?.toInt() ??
            (map['totalElements'] as num?)?.toInt(),
        hasNext: pageMeta['hasNext'] as bool? ??
            map['hasNext'] as bool? ??
            false,
      );
    }

    return const MarketplacePageResult(items: []);
  }

  String _friendlyContactError(DioException e) {
    final message = _extractMessage(e);
    if (message.isNotEmpty) return message;
    return 'No pudimos abrir WhatsApp. Inténtalo de nuevo.';
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['message']?.toString() ?? '';
    }
    return '';
  }
}

class MarketplaceServiceException implements Exception {
  MarketplaceServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
