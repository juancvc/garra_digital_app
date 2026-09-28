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
    try {
      final displayName = request.storeName.trim();
      final businessWhatsApp = request.whatsapp.trim();
      final sellerBody = <String, dynamic>{
        'businessWhatsApp': businessWhatsApp,
        'displayName': displayName,
      };

      final existing = await getSellerMe();
      if (existing != null &&
          (existing.isDraft || existing.isRejected)) {
        final response = await _dio.patch(
          '/marketplace/seller/me',
          data: sellerBody,
        );
        // Validates the envelope (throws a friendly error otherwise).
        _parseSellerProfile(response.data);
      } else if (existing == null || existing.isNone) {
        final response = await _dio.post(
          '/marketplace/seller/me',
          data: sellerBody,
        );
        // Validates the envelope (throws a friendly error otherwise).
        _parseSellerProfile(response.data);
      } else if (existing.isPending || existing.isApproved) {
        throw MarketplaceServiceException(
          existing.isPending
              ? 'Tu solicitud ya está en revisión.'
              : 'Ya tienes un perfil de vendedor activo.',
        );
      } else {
        final response = await _dio.patch(
          '/marketplace/seller/me',
          data: sellerBody,
        );
        // Validates the envelope (throws a friendly error otherwise).
        _parseSellerProfile(response.data);
      }

      // MARKETPLACE_V2_A0: SellerResponse carries no store; the real source is
      // GET /marketplace/seller/me/store (404 = no store yet).
      final hasStore = await _hasSellerStore();
      if (!hasStore) {
        final slug = _storeSlugFromName(displayName);
        await _dio.post(
          '/marketplace/seller/me/store',
          data: {
            'slug': slug,
            'name': displayName,
            if (request.storeDescription != null &&
                request.storeDescription!.trim().isNotEmpty)
              'description': request.storeDescription!.trim(),
            if (request.city != null && request.city!.trim().isNotEmpty)
              'city': request.city!.trim(),
            'countryCode': 'PE',
          },
        );
      } else {
        await updateSellerStore({
          'name': displayName,
          if (request.storeDescription != null &&
              request.storeDescription!.trim().isNotEmpty)
            'description': request.storeDescription!.trim(),
          if (request.city != null && request.city!.trim().isNotEmpty)
            'city': request.city!.trim(),
          'countryCode': 'PE',
        });
      }

      final logoId = request.logoMediaAssetId;
      if (logoId != null && logoId.isNotEmpty) {
        // Existing store media endpoint (single logo image).
        await _dio.put(
          '/marketplace/seller/me/store/media',
          data: {
            'logoMediaAssetId': logoId,
            'clearLogo': false,
            'clearBanner': false,
          },
        );
      }

      final response = await _dio.post('/marketplace/seller/me/submit');
      return _parseSellerProfile(response.data);
    } on MarketplaceServiceException {
      rethrow;
    } on DioException catch (e) {
      throw MarketplaceServiceException(_friendlySellerError(e));
    }
  }

  Future<bool> _hasSellerStore() async {
    try {
      final response = await _dio.get('/marketplace/seller/me/store');
      final data = response.data is Map ? response.data['data'] : null;
      return data is Map;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      rethrow;
    }
  }

  SellerProfile _parseSellerProfile(dynamic responseData) {
    final envelope = responseData is Map
        ? Map<String, dynamic>.from(responseData)
        : <String, dynamic>{};
    final data = envelope['data'];
    if (data is Map) {
      return SellerProfile.fromJson(Map<String, dynamic>.from(data));
    }
    throw MarketplaceServiceException(
      'No pudimos registrar tu tienda. Inténtalo de nuevo.',
    );
  }

  String _storeSlugFromName(String name) {
    var slug = name.trim().toLowerCase();
    slug = slug.replaceAll(RegExp(r'\s+'), '-');
    slug = slug.replaceAll(RegExp(r'[^a-z0-9\-]'), '');
    slug = slug.replaceAll(RegExp(r'-{2,}'), '-');
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) {
      slug = 'tienda-${DateTime.now().millisecondsSinceEpoch}';
    }
    return slug;
  }

  String _friendlySellerError(DioException e) {
    final message = _extractMessage(e);
    final lower = message.toLowerCase();
    if (lower.contains('pending') ||
        lower.contains('en revisión') ||
        lower.contains('already submitted') ||
        lower.contains('ya envi')) {
      return 'Tu solicitud ya está en revisión.';
    }
    if (lower.contains('already') || lower.contains('ya registr')) {
      return 'Ya tienes un emprendimiento registrado.';
    }
    if (lower.contains('slug')) {
      return 'Ese nombre de tienda no está disponible. Prueba otro.';
    }
    if (message.isNotEmpty) return message;
    return 'No pudimos registrar tu tienda. Inténtalo de nuevo.';
  }

  Future<SellerSummary> getSellerSummary() async {
    final response = await _dio.get('/marketplace/seller/me/summary');
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
    final response = await _dio.get('/marketplace/seller/me/store');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceStore.fromJson(data);
  }

  Future<MarketplaceStore> updateSellerStore(Map<String, dynamic> body) async {
    final response = await _dio.patch(
      '/marketplace/seller/me/store',
      data: body,
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceStore.fromJson(data);
  }

  /// POST /marketplace/seller/me/store/submit (backend requires an ACTIVE
  /// seller and `ipAcknowledged: true`, the declaration accepted during
  /// onboarding).
  Future<MarketplaceStore> submitSellerStore() async {
    final response = await _dio.post(
      '/marketplace/seller/me/store/submit',
      data: const {'ipAcknowledged': true},
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceStore.fromJson(data);
  }

  // --- MARKETPLACE_V2_A1: multi-business, every store call carries storeId ---

  /// GET /marketplace/seller/me/stores: all my stores incl. ARCHIVED, ordered
  /// createdAt ASC (single request, no per-store calls).
  Future<List<MarketplaceStore>> getSellerStores() async {
    final response = await _dio.get('/marketplace/seller/me/stores');
    final raw = response.data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => MarketplaceStore.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// POST /marketplace/seller/me/stores (canonical). The backend enforces the
  /// platform limit and answers 409 with a user-facing message beyond it.
  Future<MarketplaceStore> createSellerStore({
    required String name,
    String? description,
    String? city,
  }) async {
    try {
      final response = await _dio.post(
        '/marketplace/seller/me/stores',
        data: {
          'slug': marketplaceStoreSlug(name),
          'name': name.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
          'countryCode': 'PE',
        },
      );
      return _parseStore(response.data);
    } on DioException catch (e) {
      throw MarketplaceServiceException(_friendlyStoreError(e));
    }
  }

  Future<MarketplaceStore> getSellerStoreById(String storeId) async {
    final response = await _dio.get('/marketplace/seller/me/stores/$storeId');
    return _parseStore(response.data);
  }

  Future<MarketplaceStore> updateSellerStoreById(
    String storeId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.patch(
        '/marketplace/seller/me/stores/$storeId',
        data: body,
      );
      return _parseStore(response.data);
    } on DioException catch (e) {
      throw MarketplaceServiceException(_friendlyStoreError(e));
    }
  }

  /// POST /marketplace/seller/me/stores/{storeId}/submit (IP declaration
  /// accepted during onboarding; seller must be ACTIVE).
  Future<MarketplaceStore> submitSellerStoreById(String storeId) async {
    try {
      final response = await _dio.post(
        '/marketplace/seller/me/stores/$storeId/submit',
        data: const {'ipAcknowledged': true},
      );
      return _parseStore(response.data);
    } on DioException catch (e) {
      throw MarketplaceServiceException(_friendlyStoreError(e));
    }
  }

  /// POST /marketplace/seller/me/stores/{storeId}/archive (no hard delete;
  /// 409 while the store still has non-archived listings).
  Future<MarketplaceStore> archiveSellerStore(String storeId) async {
    try {
      final response = await _dio.post(
        '/marketplace/seller/me/stores/$storeId/archive',
      );
      return _parseStore(response.data);
    } on DioException catch (e) {
      throw MarketplaceServiceException(_friendlyStoreError(e));
    }
  }

  Future<List<MarketplaceListing>> getSellerStoreListings(
    String storeId,
  ) async {
    final response = await _dio.get(
      '/marketplace/seller/me/stores/$storeId/listings',
    );
    final raw = response.data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => MarketplaceListing.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// POST /marketplace/seller/me/stores/{storeId}/listings: a listing is
  /// always created in an explicit store.
  Future<MarketplaceListing> createSellerListingInStore(
    String storeId,
    SellerListingRequest request,
  ) async {
    final response = await _dio.post(
      '/marketplace/seller/me/stores/$storeId/listings',
      data: request.toCreateJson(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceListing.fromJson(data);
  }

  MarketplaceStore _parseStore(dynamic responseData) {
    final data = responseData is Map ? responseData['data'] : null;
    if (data is Map) {
      return MarketplaceStore.fromJson(Map<String, dynamic>.from(data));
    }
    throw MarketplaceServiceException(
      'No pudimos cargar el negocio. Int\u00e9ntalo de nuevo.',
    );
  }

  String _friendlyStoreError(DioException e) {
    final message = _extractMessage(e);
    if (e.response?.statusCode == 409 && message.isNotEmpty) return message;
    if (message.toLowerCase().contains('slug')) {
      return 'Ese nombre de negocio no est\u00e1 disponible. Prueba otro.';
    }
    return 'No pudimos guardar el negocio. Int\u00e9ntalo de nuevo.';
  }

  Future<List<MarketplaceListing>> getSellerListings() async {
    final response = await _dio.get('/marketplace/seller/me/listings');
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
      '/marketplace/seller/me/listings',
      data: request.toCreateJson(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceListing.fromJson(data);
  }

  /// PATCH /marketplace/seller/me/listings/{listingId} (UUID, not slug).
  Future<MarketplaceListing> updateSellerListing(
    String listingId,
    SellerListingRequest request,
  ) async {
    final response = await _dio.patch(
      '/marketplace/seller/me/listings/$listingId',
      data: request.toJson(),
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceListing.fromJson(data);
  }

  /// POST /marketplace/seller/me/listings/{listingId}/archive (no hard
  /// delete in the backend).
  Future<MarketplaceListing> archiveSellerListing(String listingId) async {
    final response = await _dio.post(
      '/marketplace/seller/me/listings/$listingId/archive',
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return MarketplaceListing.fromJson(data);
  }

  /// POST /marketplace/seller/me/listings/{listingId}/submit with the
  /// `ipAcknowledged` body the backend requires (declaration accepted during
  /// onboarding).
  Future<MarketplaceListing> submitSellerListing(String listingId) async {
    final response = await _dio.post(
      '/marketplace/seller/me/listings/$listingId/submit',
      data: const {'ipAcknowledged': true},
    );
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
