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

  bool get isPublished => status.toUpperCase() == 'PUBLISHED';
  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isPending => status.toUpperCase() == 'PENDING';

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
    );
  }

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    MarketplaceStoreSummary? store;
    if (json['store'] is Map) {
      store = MarketplaceStoreSummary.fromJson(
        Map<String, dynamic>.from(json['store'] as Map),
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

    return MarketplaceListing(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      priceOnRequest: json['priceOnRequest'] as bool? ??
          json['consultar'] as bool? ??
          (json['price'] == null),
      currency: json['currency'] as String? ?? 'PEN',
      category: categoryName,
      categorySlug: categorySlug,
      type: json['type']?.toString() ?? 'PRODUCT',
      status: json['status']?.toString() ?? 'PUBLISHED',
      isFavorite: json['isFavorite'] as bool? ??
          json['favorited'] as bool? ??
          false,
      store: store,
      createdAt: _parseDateTime(json['createdAt']),
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

class MarketplaceStore {
  const MarketplaceStore({
    required this.slug,
    required this.name,
    this.description,
    this.city,
    this.whatsapp,
    this.listings = const [],
    this.status = 'ACTIVE',
  });

  final String slug;
  final String name;
  final String? description;
  final String? city;
  final String? whatsapp;
  final List<MarketplaceListing> listings;
  final String status;

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
  bool get isPending => status.toUpperCase() == 'PENDING';
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
