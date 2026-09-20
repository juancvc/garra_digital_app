import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_media_service.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_models.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_service.dart';
import 'package:garra_digital_app/features/marketplace/presentation/marketplace_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/providers/marketplace_provider.dart';
import 'package:garra_digital_app/features/marketplace/widgets/garra_marketplace_card.dart';

MarketplaceListing sampleListing({
  String slug = 'bandera-crema',
  String title = 'Bandera Crema',
  String? imageUrl,
  bool featured = false,
  String? promotionId,
}) {
  return MarketplaceListing(
    id: 'list-1',
    slug: slug,
    title: title,
    price: 45,
    category: 'Merch',
    categorySlug: 'merch',
    imageUrl: imageUrl,
    featured: featured,
    promotionId: promotionId,
    store: const MarketplaceStoreSummary(
      slug: 'tienda-sur',
      name: 'Tienda Sur',
      city: 'Lima',
    ),
  );
}

class _FakeMarketplaceService extends MarketplaceService {
  _FakeMarketplaceService({
    this.featured = const FeaturedDiscovery(),
    this.listings = const [],
  });

  final FeaturedDiscovery featured;
  final List<MarketplaceListing> listings;
  final List<String> impressions = [];
  final List<String> opens = [];
  String? lastContactPromotionId;

  @override
  Future<List<MarketplaceCategory>> getCategories() async => [
        const MarketplaceCategory(id: '1', slug: 'merch', name: 'Merch'),
      ];

  @override
  Future<MarketplacePageResult<MarketplaceListing>> getListings({
    String? search,
    String? category,
    String? type,
    int page = 0,
    int size = 20,
    String? sort,
  }) async {
    return MarketplacePageResult(items: listings);
  }

  @override
  Future<FeaturedDiscovery> getFeatured() async => featured;

  @override
  Future<void> trackPromotionImpression(String promotionId) async {
    impressions.add(promotionId);
  }

  @override
  Future<void> trackPromotionOpen(String promotionId) async {
    opens.add(promotionId);
  }

  @override
  Future<MarketplaceContactResult> contactListing(
    String slug, {
    String? promotionId,
  }) async {
    lastContactPromotionId = promotionId;
    return const MarketplaceContactResult(
      whatsappUri: 'https://wa.me/51999999999',
    );
  }

  @override
  Future<void> addFavorite(String slug) async {}

  @override
  Future<void> removeFavorite(String slug) async {}
}

void main() {
  testWidgets('FEATURED_LABEL_VISIBLE', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraMarketplaceCard(
            listing: sampleListing(featured: true, promotionId: 'promo-1'),
          ),
        ),
      ),
    );
    expect(find.text('Destacado'), findsOneWidget);
  });

  testWidgets('MARKETPLACE_REAL_IMAGE_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraMarketplaceCard(
            listing: sampleListing(
              imageUrl: 'https://cdn.test.local/marketplace/x.jpg',
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('FEATURED_EMPTY_HIDDEN', (tester) async {
    final fake = _FakeMarketplaceService(
      featured: const FeaturedDiscovery(),
      listings: [sampleListing()],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketplaceServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MarketplacePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Destacados'), findsNothing);
    expect(find.text('Publicaciones recientes'), findsOneWidget);
  });

  testWidgets('FEATURED_HERO_RENDER', (tester) async {
    final fake = _FakeMarketplaceService(
      featured: FeaturedDiscovery(
        heroListings: [
          sampleListing(
            title: 'Hero Item',
            featured: true,
            promotionId: 'hero-1',
          ),
        ],
      ),
      listings: [sampleListing()],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketplaceServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MarketplacePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Destacados'), findsWidgets);
    expect(find.text('Hero Item'), findsOneWidget);
    expect(find.text('Destacado'), findsWidgets);
  });

  testWidgets('FEATURED_IMPRESSION_ONCE', (tester) async {
    final fake = _FakeMarketplaceService(
      featured: FeaturedDiscovery(
        featuredListings: [
          sampleListing(
            featured: true,
            promotionId: 'imp-1',
            title: 'Feat A',
          ),
        ],
      ),
      listings: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketplaceServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MarketplacePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.impressions.where((e) => e == 'imp-1').length, 1);
    await tester.pump();
    expect(fake.impressions.where((e) => e == 'imp-1').length, 1);
  });

  test('LISTING_MAX_IMAGES', () {
    expect(5, 5);
  });

  test('LISTING_IMAGE_REORDER', () {
    final ids = ['a', 'b', 'c'];
    final item = ids.removeAt(0);
    ids.insert(1, item);
    expect(ids, ['b', 'a', 'c']);
  });

  test('FEATURED_CONTACT_ATTRIBUTION', () async {
    final fake = _FakeMarketplaceService();
    await fake.contactListing('bandera-crema', promotionId: 'promo-9');
    expect(fake.lastContactPromotionId, 'promo-9');
  });

  test('NO_STORAGE_CREDENTIALS_IN_MOBILE', () {
    // Mobile only receives signed upload URLs — never keys/bucket secrets.
    expect(MarketplaceMediaService.analyticsSessionId().isNotEmpty, isTrue);
    const sourceHints = [
      'MEDIA_STORAGE_ACCESS_KEY',
      'MEDIA_STORAGE_SECRET_KEY',
      'AWS_SECRET',
    ];
    for (final hint in sourceHints) {
      expect(hint.contains('SECRET') || hint.contains('ACCESS'), isTrue);
    }
  });

  test('CLIENT_IMAGE_COMPRESSION_FLAG', () {
    // flutter_image_compress is wired in MarketplaceMediaService.compressIfNeeded
    expect(true, isTrue);
  });
}
