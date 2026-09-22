/// Marketplace Crema models — discovery, listings, stores, seller (no cart/checkout).
library;

class MarketplaceCategory {
  const MarketplaceCategory({
    required this.id,
    required this.slug,
    required this.name,
  });

  final String id;
  final String slug;
  final String name;

  factory MarketplaceCategory.fromJson(Map<String, dynamic> json) {
    return MarketplaceCategory(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class MarketplaceStoreSummary {
  const MarketplaceStoreSummary({
    required this.slug,
    required this.name,
    this.city,
  });

  final String slug;
  final String name;
  final String? city;

  factory MarketplaceStoreSummary.fromJson(Map<String, dynamic> json) {
    return MarketplaceStoreSummary(
      slug: json['slug']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String?,
    );
  }
}

class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.slug,
    required this.title,
    this.description,
    this.price,
    this.priceOnRequest = false,
    this.currency = 'PEN',
    this.category,
    this.categorySlug,
    this.type = 'PRODUCT',
    this.status = 'PUBLISHED',
    this.isFavorite = false,
    this.store,
    this.createdAt,
    this.imageUrl,
    this.images = const [],
    this.featured = false,
    this.promotionId,
  });

  final String id;
  final String slug;
  final String title;
  final String? description;
  final double? price;
  final bool priceOnRequest;
  final String currency;
  final String? category;
  final String? categorySlug;
  final String type;
  final String status;
  final bool isFavorite;
  final MarketplaceStoreSummary? store;
  final DateTime? createdAt;
  final String? imageUrl;
  final List<MarketplaceListingImage> images;
  final bool featured;
  final String? promotionId;

  bool get isPublished =>
      status.toUpperCase() == 'PUBLISHED' || status.toUpperCase() == 'ACTIVE';
  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isPending =>
      status.toUpperCase() == 'PENDING' ||
      status.toUpperCase() == 'PENDING_REVIEW';

  String? get coverImageUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    if (images.isNotEmpty) return images.first.imageUrl;
    return null;
  }

  String get priceLabel {
    if (priceOnRequest || price == null) return 'Consultar';
    final formatted = price! % 1 == 0
        ? price!.toStringAsFixed(0)
        : price!.toStringAsFixed(2);
    return 'S/ $formatted';
  }

  MarketplaceListing copyWith({
    String? id,
    String? slug,
    String? title,
    String? description,
    double? price,
    bool? priceOnRequest,
    String? currency,
    String? category,
    String? categorySlug,
    String? type,
    String? status,
    bool? isFavorite,
    MarketplaceStoreSummary? store,
    DateTime? createdAt,
    String? imageUrl,
    List<MarketplaceListingImage>? images,
    bool? featured,
    String? promotionId,
  }) {
    return MarketplaceListing(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      priceOnRequest: priceOnRequest ?? this.priceOnRequest,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      categorySlug: categorySlug ?? this.categorySlug,
      type: type ?? this.type,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      store: store ?? this.store,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      featured: featured ?? this.featured,
      promotionId: promotionId ?? this.promotionId,
    );
  }

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    MarketplaceStoreSummary? store;
    if (json['store'] is Map) {
      store = MarketplaceStoreSummary.fromJson(
        Map<String, dynamic>.from(json['store'] as Map),
      );
    } else if (json['storeSlug'] != null || json['storeName'] != null) {
      store = MarketplaceStoreSummary(
        slug: json['storeSlug']?.toString() ?? '',
        name: json['storeName'] as String? ?? '',
        city: json['city'] as String?,
      );
    }

    String? categoryName;
    String? categorySlug;
    if (json['category'] is Map) {
      final cat = Map<String, dynamic>.from(json['category'] as Map);
      categoryName = cat['name'] as String?;
      categorySlug = cat['slug']?.toString();
    } else {
      categoryName = json['category'] as String? ?? json['categoryName'] as String?;
      categorySlug = json['categorySlug']?.toString();
    }

    final imagesRaw = json['images'];
    final images = <MarketplaceListingImage>[];
    if (imagesRaw is List) {
      for (final e in imagesRaw) {
        if (e is Map) {
          images.add(
            MarketplaceListingImage.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    final price = (json['price'] as num?)?.toDouble() ??
        (json['priceAmount'] as num?)?.toDouble();

    return MarketplaceListing(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      price: price,
      priceOnRequest: json['priceOnRequest'] as bool? ??
          json['consultar'] as bool? ??
          (price == null),
      currency: json['currency'] as String? ??
          json['currencyCode'] as String? ??
          'PEN',
      category: categoryName,
      categorySlug: categorySlug,
      type: json['type']?.toString() ?? 'PRODUCT',
      status: json['status']?.toString() ?? 'PUBLISHED',
      isFavorite: json['isFavorite'] as bool? ??
          json['favorited'] as bool? ??
          false,
      store: store,
      createdAt: _parseDateTime(json['createdAt']),
      imageUrl: json['imageUrl'] as String?,
      images: images,
      featured: json['featured'] as bool? ?? false,
      promotionId: json['promotionId']?.toString(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class MarketplaceListingImage {
  const MarketplaceListingImage({
    required this.id,
    this.imageUrl,
    this.mediaAssetId,
    this.sortOrder = 0,
    this.altText,
  });

  final String id;
  final String? imageUrl;
  final String? mediaAssetId;
  final int sortOrder;
  final String? altText;

  factory MarketplaceListingImage.fromJson(Map<String, dynamic> json) {
    return MarketplaceListingImage(
      id: json['id']?.toString() ?? '',
      imageUrl: json['imageUrl'] as String?,
      mediaAssetId: json['mediaAssetId']?.toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      altText: json['altText'] as String?,
    );
  }
}

class FeaturedDiscovery {
  const FeaturedDiscovery({
    this.featuredListings = const [],
    this.featuredStores = const [],
    this.heroListings = const [],
    this.heroStores = const [],
  });

  final List<MarketplaceListing> featuredListings;
  final List<FeaturedStoreCard> featuredStores;
  final List<MarketplaceListing> heroListings;
  final List<FeaturedStoreCard> heroStores;

  bool get hasHero => heroListings.isNotEmpty || heroStores.isNotEmpty;
  bool get hasFeatured =>
      featuredListings.isNotEmpty || featuredStores.isNotEmpty;

  factory FeaturedDiscovery.fromJson(Map<String, dynamic> json) {
    List<MarketplaceListing> parseFeaturedListings(dynamic raw) {
      if (raw is! List) return const [];
      return raw.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final listingJson = map['listing'] is Map
            ? Map<String, dynamic>.from(map['listing'] as Map)
            : map;
        final listing = MarketplaceListing.fromJson(listingJson);
        return listing.copyWith(
          featured: true,
          promotionId: map['promotionId']?.toString() ?? listing.promotionId,
        );
      }).toList();
    }

    List<FeaturedStoreCard> parseStores(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map(
            (e) => FeaturedStoreCard.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    return FeaturedDiscovery(
      featuredListings: parseFeaturedListings(json['featuredListings']),
      featuredStores: parseStores(json['featuredStores']),
      heroListings: parseFeaturedListings(json['heroListings']),
      heroStores: parseStores(json['heroStores']),
    );
  }
}

class FeaturedStoreCard {
  const FeaturedStoreCard({
    required this.promotionId,
    required this.storeSlug,
    required this.storeName,
    this.city,
    this.logoUrl,
    this.bannerUrl,
  });

  final String promotionId;
  final String storeSlug;
  final String storeName;
  final String? city;
  final String? logoUrl;
  final String? bannerUrl;

  factory FeaturedStoreCard.fromJson(Map<String, dynamic> json) {
    return FeaturedStoreCard(
      promotionId: json['promotionId']?.toString() ?? '',
      storeSlug: json['storeSlug']?.toString() ?? '',
      storeName: json['storeName'] as String? ?? '',
      city: json['city'] as String?,
      logoUrl: json['logoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
    );
  }
}

class MarketplaceStore {
  const MarketplaceStore({
    required this.slug,
    required this.name,
    this.description,
    this.city,
    this.whatsapp,
    this.listings = const [],
    this.status = 'ACTIVE',
    this.logoUrl,
    this.bannerUrl,
    this.cremaPointId,
  });

  final String slug;
  final String name;
  final String? description;
  final String? city;
  final String? whatsapp;
  final List<MarketplaceListing> listings;
  final String status;
  final String? logoUrl;
  final String? bannerUrl;
  final String? cremaPointId;

  bool get isCremaPointVerified =>
      cremaPointId != null && cremaPointId!.isNotEmpty;

  factory MarketplaceStore.fromJson(Map<String, dynamic> json) {
    final rawListings = json['listings'];
    List<MarketplaceListing> listings = const [];
    if (rawListings is List) {
      listings = rawListings
          .map(
            (e) => MarketplaceListing.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    return MarketplaceStore(
      slug: json['slug']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      city: json['city'] as String?,
      whatsapp: json['whatsapp'] as String?,
      listings: listings,
      status: json['status']?.toString() ?? 'ACTIVE',
      logoUrl: json['logoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      cremaPointId: json['cremaPointId']?.toString(),
    );
  }
}

class MarketplaceContactResult {
  const MarketplaceContactResult({required this.whatsappUri});

  final String whatsappUri;

  factory MarketplaceContactResult.fromJson(Map<String, dynamic> json) {
    return MarketplaceContactResult(
      whatsappUri: json['whatsappUri'] as String? ??
          json['whatsappUrl'] as String? ??
          '',
    );
  }
}

class MarketplaceReportRequest {
  const MarketplaceReportRequest({
    required this.listingSlug,
    required this.reason,
    this.details,
  });

  final String listingSlug;
  final String reason;
  final String? details;

  Map<String, dynamic> toJson() {
    return {
      'listingSlug': listingSlug,
      'reason': reason,
      if (details != null && details!.trim().isNotEmpty) 'details': details,
    };
  }
}

class SellerProfile {
  const SellerProfile({
    required this.status,
    this.storeName,
    this.storeSlug,
    this.whatsapp,
    this.ipAcknowledged = false,
  });

  final String status;
  final String? storeName;
  final String? storeSlug;
  final String? whatsapp;
  final bool ipAcknowledged;

  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isPending =>
      status.toUpperCase() == 'PENDING' ||
      status.toUpperCase() == 'PENDING_REVIEW';
  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isNone =>
      status.toUpperCase() == 'NONE' || status.toUpperCase() == 'NOT_REGISTERED';

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    return SellerProfile(
      status: json['status']?.toString() ?? 'NONE',
      storeName: json['storeName'] as String? ??
          (json['store'] is Map
              ? (json['store'] as Map)['name'] as String?
              : null),
      storeSlug: json['storeSlug'] as String? ??
          (json['store'] is Map
              ? (json['store'] as Map)['slug']?.toString()
              : null),
      whatsapp: json['whatsapp'] as String?,
      ipAcknowledged: json['ipAcknowledged'] as bool? ??
          json['intellectualPropertyAcknowledged'] as bool? ??
          false,
    );
  }
}

class SellerOnboardingRequest {
  const SellerOnboardingRequest({
    required this.whatsapp,
    required this.storeName,
    required this.ipAcknowledged,
    this.storeDescription,
    this.city,
  });

  final String whatsapp;
  final String storeName;
  final bool ipAcknowledged;
  final String? storeDescription;
  final String? city;

  Map<String, dynamic> toJson() {
    return {
      'whatsapp': whatsapp.trim(),
      'storeName': storeName.trim(),
      'ipAcknowledged': ipAcknowledged,
      if (storeDescription != null && storeDescription!.trim().isNotEmpty)
        'storeDescription': storeDescription!.trim(),
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
    };
  }
}

/// Seller dashboard metrics — contacts/favorites only (no sales/revenue).
class SellerSummary {
  const SellerSummary({
    required this.status,
    this.listingsCount = 0,
    this.favoritesCount = 0,
    this.contactsCount = 0,
    this.storeName,
    this.storeSlug,
  });

  final String status;
  final int listingsCount;
  final int favoritesCount;
  final int contactsCount;
  final String? storeName;
  final String? storeSlug;

  factory SellerSummary.fromJson(Map<String, dynamic> json) {
    return SellerSummary(
      status: json['status']?.toString() ?? 'NONE',
      listingsCount: (json['listingsCount'] as num?)?.toInt() ?? 0,
      favoritesCount: (json['favoritesCount'] as num?)?.toInt() ?? 0,
      contactsCount: (json['contactsCount'] as num?)?.toInt() ?? 0,
      storeName: json['storeName'] as String?,
      storeSlug: json['storeSlug']?.toString(),
    );
  }
}

class SellerPlan {
  const SellerPlan({
    required this.code,
    required this.name,
    this.description,
    this.startsAt,
    this.endsAt,
    this.source,
    required this.usage,
    required this.features,
  });

  final String code;
  final String name;
  final String? description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? source;
  final SellerPlanUsage usage;
  final SellerPlanFeatures features;

  bool get isPro => code.toUpperCase() == 'PRO';
  bool get isFree => code.toUpperCase() == 'FREE';
  bool get limitReached =>
      usage.maxActiveListings > 0 &&
      usage.activeListings >= usage.maxActiveListings;

  factory SellerPlan.fromJson(Map<String, dynamic> json) {
    return SellerPlan(
      code: json['code']?.toString() ?? 'FREE',
      name: json['name'] as String? ?? 'Free',
      description: json['description'] as String?,
      startsAt: _parseDate(json['startsAt']),
      endsAt: _parseDate(json['endsAt']),
      source: json['source']?.toString(),
      usage: SellerPlanUsage.fromJson(
        Map<String, dynamic>.from(json['usage'] as Map? ?? const {}),
      ),
      features: SellerPlanFeatures.fromJson(
        Map<String, dynamic>.from(json['features'] as Map? ?? const {}),
      ),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}

class SellerPlanUsage {
  const SellerPlanUsage({
    required this.activeListings,
    required this.maxActiveListings,
    required this.activeStores,
    required this.maxActiveStores,
  });

  final int activeListings;
  final int maxActiveListings;
  final int activeStores;
  final int maxActiveStores;

  factory SellerPlanUsage.fromJson(Map<String, dynamic> json) {
    return SellerPlanUsage(
      activeListings: (json['activeListings'] as num?)?.toInt() ?? 0,
      maxActiveListings: (json['maxActiveListings'] as num?)?.toInt() ?? 0,
      activeStores: (json['activeStores'] as num?)?.toInt() ?? 0,
      maxActiveStores: (json['maxActiveStores'] as num?)?.toInt() ?? 0,
    );
  }
}

class SellerPlanFeatures {
  const SellerPlanFeatures({
    required this.advancedAnalytics,
    required this.featuredEligible,
    this.analyticsRetentionDays = 30,
  });

  final bool advancedAnalytics;
  final bool featuredEligible;
  final int analyticsRetentionDays;

  factory SellerPlanFeatures.fromJson(Map<String, dynamic> json) {
    return SellerPlanFeatures(
      advancedAnalytics: json['advancedAnalytics'] as bool? ?? false,
      featuredEligible: json['featuredEligible'] as bool? ?? false,
      analyticsRetentionDays:
          (json['analyticsRetentionDays'] as num?)?.toInt() ?? 30,
    );
  }
}

class SellerAdvancedAnalytics {
  const SellerAdvancedAnalytics({
    required this.favorites,
    required this.contacts,
    this.listings = const [],
    this.featuredImpressions = 0,
    this.featuredOpens = 0,
  });

  final int favorites;
  final int contacts;
  final List<SellerListingPerformance> listings;
  final int featuredImpressions;
  final int featuredOpens;

  factory SellerAdvancedAnalytics.fromJson(Map<String, dynamic> json) {
    final raw = json['listings'] as List? ?? const [];
    return SellerAdvancedAnalytics(
      favorites: (json['favoritesReceived'] as num?)?.toInt() ??
          (json['favorites'] as num?)?.toInt() ??
          0,
      contacts: (json['contactLeads'] as num?)?.toInt() ??
          (json['contacts'] as num?)?.toInt() ??
          0,
      listings: raw
          .map(
            (e) => SellerListingPerformance.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      featuredImpressions: (json['featuredImpressions'] as num?)?.toInt() ?? 0,
      featuredOpens: (json['featuredOpens'] as num?)?.toInt() ?? 0,
    );
  }
}

class SellerListingPerformance {
  const SellerListingPerformance({
    required this.listingId,
    required this.slug,
    required this.title,
    required this.favorites,
    required this.contacts,
  });

  final String listingId;
  final String slug;
  final String title;
  final int favorites;
  final int contacts;

  factory SellerListingPerformance.fromJson(Map<String, dynamic> json) {
    return SellerListingPerformance(
      listingId: json['listingId']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      favorites: (json['favoriteCount'] as num?)?.toInt() ??
          (json['favorites'] as num?)?.toInt() ??
          0,
      contacts: (json['contactCount'] as num?)?.toInt() ??
          (json['contacts'] as num?)?.toInt() ??
          0,
    );
  }
}

class SellerListingRequest {
  const SellerListingRequest({
    required this.title,
    required this.description,
    required this.categorySlug,
    this.price,
    this.priceOnRequest = false,
    this.type = 'PRODUCT',
  });

  final String title;
  final String description;
  final String categorySlug;
  final double? price;
  final bool priceOnRequest;
  final String type;

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'categorySlug': categorySlug,
      'priceOnRequest': priceOnRequest,
      if (!priceOnRequest && price != null) 'price': price,
      'type': type,
    };
  }
}

class MarketplacePageResult<T> {
  const MarketplacePageResult({
    required this.items,
    this.page = 0,
    this.size = 20,
    this.totalElements,
    this.hasNext = false,
  });

  final List<T> items;
  final int page;
  final int size;
  final int? totalElements;
  final bool hasNext;
}
