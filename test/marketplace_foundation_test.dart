import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_models.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_service.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_url_launcher.dart';
import 'package:garra_digital_app/features/marketplace/presentation/favorites_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/listing_detail_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/marketplace_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/providers/marketplace_provider.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_dashboard_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_onboarding_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/store_page.dart';
import 'package:garra_digital_app/features/marketplace/widgets/garra_marketplace_card.dart';
import 'package:go_router/go_router.dart';

/// Widget-test fixtures only — not production seed data (no FAKE_PRODUCTS).
MarketplaceCategory sampleCategory({
  String id = 'cat-1',
  String slug = 'merch',
  String name = 'Merch',
}) {
  return MarketplaceCategory(id: id, slug: slug, name: name);
}

MarketplaceListing sampleListing({
  String id = 'list-1',
  String slug = 'bandera-crema',
  String title = 'Bandera Crema',
  String? description = 'Bandera oficial de la hinchada.',
  double? price = 45,
  bool priceOnRequest = false,
  String? category = 'Merch',
  String? categorySlug = 'merch',
  bool isFavorite = false,
  MarketplaceStoreSummary? store,
  String status = 'PUBLISHED',
}) {
  return MarketplaceListing(
    id: id,
    slug: slug,
    title: title,
    description: description,
    price: price,
    priceOnRequest: priceOnRequest,
    category: category,
    categorySlug: categorySlug,
    isFavorite: isFavorite,
    store: store ??
        const MarketplaceStoreSummary(
          slug: 'tienda-sur',
          name: 'Tienda Sur',
          city: 'Lima',
        ),
    status: status,
  );
}

MarketplaceStore sampleStore({
  String slug = 'tienda-sur',
  String name = 'Tienda Sur',
  List<MarketplaceListing>? listings,
}) {
  return MarketplaceStore(
    slug: slug,
    name: name,
    description: 'Emprendimiento crema del sur.',
    city: 'Lima',
    listings: listings ?? [sampleListing()],
  );
}

HomeModel sampleHome() {
  return const HomeModel(
    fan: HomeFanSummary(
      displayName: 'Hincha Crema',
      username: 'cremafan',
      levelNumber: 2,
      levelName: 'Hincha Fiel',
      points: 1840,
      globalRank: 428,
    ),
    matchdayState: 'NO_MATCH',
    match: null,
    prediction: HomePrediction(
      state: 'NOT_PREDICTED',
      predictionsOpen: false,
    ),
    checkIn: HomeCheckIn(
      showCheckInCta: false,
      hasActiveStadiumPoint: false,
      recentlyCheckedIn: false,
    ),
    community: HomeCommunityPreview(posts: []),
    notifications: HomeNotifications(unreadCount: 0),
    clan: null,
  );
}

class FakeMarketplaceService extends MarketplaceService {
  FakeMarketplaceService({
    this.categories = const [],
    this.listings = const [],
    this.favorites = const [],
    this.detail,
    this.store,
    this.seller,
    this.summary,
    this.sellerListings = const [],
    this.failFavorite = false,
    this.contactUri = 'https://wa.me/51999999999',
  }) : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost')));

  List<MarketplaceCategory> categories;
  List<MarketplaceListing> listings;
  List<MarketplaceListing> favorites;
  MarketplaceListing? detail;
  MarketplaceStore? store;
  SellerProfile? seller;
  SellerSummary? summary;
  List<MarketplaceListing> sellerListings;
  bool failFavorite;
  String contactUri;

  int favoritePutCalls = 0;
  int favoriteDeleteCalls = 0;
  int contactCalls = 0;
  int reportCalls = 0;
  int sellerSubmitCalls = 0;
  String? lastFavoriteSlug;
  String? lastContactSlug;
  String? lastReportSlug;

  @override
  Future<List<MarketplaceCategory>> getCategories() async => categories;

  @override
  Future<MarketplacePageResult<MarketplaceListing>> getListings({
    String? search,
    String? category,
    String? type,
    int page = 0,
    int size = 20,
    String? sort,
  }) async {
    final q = search?.toLowerCase() ?? '';
    var items = listings.where((l) {
      if (q.isNotEmpty &&
          !l.title.toLowerCase().contains(q) &&
          !(l.description?.toLowerCase().contains(q) ?? false)) {
        return false;
      }
      if (category != null &&
          category.isNotEmpty &&
          l.categorySlug != category) {
        return false;
      }
      return true;
    }).toList();
    return MarketplacePageResult(items: items);
  }

  @override
  Future<MarketplaceListing> getListing(String slug) async {
    if (detail != null && detail!.slug == slug) return detail!;
    return listings.firstWhere(
      (l) => l.slug == slug,
      orElse: () => sampleListing(slug: slug),
    );
  }

  @override
  Future<MarketplaceStore> getStore(String slug) async {
    if (store != null && store!.slug == slug) return store!;
    return sampleStore(slug: slug);
  }

  @override
  Future<void> addFavorite(String slug) async {
    favoritePutCalls++;
    lastFavoriteSlug = slug;
    if (failFavorite) {
      throw MarketplaceServiceException('fail');
    }
    final listing = await getListing(slug);
    favorites = [
      ...favorites.where((f) => f.slug != slug),
      listing.copyWith(isFavorite: true),
    ];
    if (detail?.slug == slug) {
      detail = detail!.copyWith(isFavorite: true);
    }
    listings = listings
        .map((l) => l.slug == slug ? l.copyWith(isFavorite: true) : l)
        .toList();
  }

  @override
  Future<void> removeFavorite(String slug) async {
    favoriteDeleteCalls++;
    lastFavoriteSlug = slug;
    if (failFavorite) {
      throw MarketplaceServiceException('fail');
    }
    favorites = favorites.where((f) => f.slug != slug).toList();
    if (detail?.slug == slug) {
      detail = detail!.copyWith(isFavorite: false);
    }
    listings = listings
        .map((l) => l.slug == slug ? l.copyWith(isFavorite: false) : l)
        .toList();
  }

  @override
  Future<List<MarketplaceListing>> getFavorites() async => favorites;

  @override
  Future<MarketplaceContactResult> contactListing(String slug) async {
    contactCalls++;
    lastContactSlug = slug;
    return MarketplaceContactResult(whatsappUri: contactUri);
  }

  @override
  Future<void> reportListing(MarketplaceReportRequest request) async {
    reportCalls++;
    lastReportSlug = request.listingSlug;
  }

  @override
  Future<SellerProfile?> getSellerMe() async => seller;

  @override
  Future<SellerProfile> submitSeller(SellerOnboardingRequest request) async {
    sellerSubmitCalls++;
    seller = SellerProfile(
      status: 'PENDING',
      storeName: request.storeName,
      whatsapp: request.whatsapp,
      ipAcknowledged: request.ipAcknowledged,
    );
    summary = SellerSummary(
      status: 'PENDING',
      storeName: request.storeName,
      listingsCount: 0,
      favoritesCount: 0,
      contactsCount: 0,
    );
    return seller!;
  }

  @override
  Future<SellerSummary> getSellerSummary() async {
    return summary ??
        const SellerSummary(
          status: 'APPROVED',
          listingsCount: 1,
          favoritesCount: 2,
          contactsCount: 3,
          storeName: 'Tienda Sur',
        );
  }

  @override
  Future<List<MarketplaceListing>> getSellerListings() async => sellerListings;
}

Widget pumpMarketplace(FakeMarketplaceService service, {String initial = '/marketplace'}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/marketplace',
        builder: (_, _) => const MarketplacePage(),
      ),
      GoRoute(
        path: '/marketplace/favorites',
        builder: (_, _) => const FavoritesPage(),
      ),
      GoRoute(
        path: '/marketplace/listings/:slug',
        builder: (_, state) =>
            ListingDetailPage(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/marketplace/stores/:slug',
        builder: (_, state) =>
            StorePage(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/marketplace/seller',
        builder: (_, _) => const SellerOnboardingPage(),
      ),
      GoRoute(
        path: '/marketplace/seller/dashboard',
        builder: (_, _) => const SellerDashboardPage(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      marketplaceServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp.router(
      theme: AppTheme.darkTheme,
      routerConfig: router,
    ),
  );
}

void main() {
  test('82_MARKETPLACE_MODEL_PARSES_LISTING', () {
    final listing = MarketplaceListing.fromJson({
      'id': '1',
      'slug': 'polera-u',
      'title': 'Polera U',
      'price': 80,
      'priceOnRequest': false,
      'isFavorite': true,
      'category': {'slug': 'ropa', 'name': 'Ropa'},
      'store': {'slug': 'crema-shop', 'name': 'Crema Shop'},
    });
    expect(listing.slug, 'polera-u');
    expect(listing.priceLabel, 'S/ 80');
    expect(listing.isFavorite, isTrue);
    expect(listing.category, 'Ropa');
    expect(listing.store?.name, 'Crema Shop');
  });

  test('82_MARKETPLACE_PRICE_CONSULTAR', () {
    final listing = sampleListing(price: null, priceOnRequest: true);
    expect(listing.priceLabel, 'Consultar');
  });

  testWidgets('82_MARKETPLACE_DISCOVERY_EMPTY', (tester) async {
    final service = FakeMarketplaceService(
      categories: [sampleCategory()],
    );
    await tester.pumpWidget(pumpMarketplace(service));
    await tester.pumpAndSettle();
    expect(find.text('Marketplace Crema'), findsWidgets);
    expect(
      find.text('Los emprendimientos crema aparecerán aquí.'),
      findsOneWidget,
    );
    expect(find.text('Quiero vender'), findsOneWidget);
  });

  testWidgets('82_MARKETPLACE_DISCOVERY_RENDER', (tester) async {
    final service = FakeMarketplaceService(
      categories: [sampleCategory(), sampleCategory(slug: 'comida', name: 'Comida')],
      listings: [
        sampleListing(),
        sampleListing(slug: 'llavero', title: 'Llavero Garra', price: 15),
      ],
    );
    await tester.pumpWidget(pumpMarketplace(service));
    await tester.pumpAndSettle();
    expect(find.text('Bandera Crema'), findsOneWidget);
    expect(find.text('Llavero Garra'), findsOneWidget);
    expect(find.text('Merch'), findsWidgets);
    expect(find.byType(GarraMarketplaceCard), findsNWidgets(2));
  });

  testWidgets('82_MARKETPLACE_CATEGORY_FILTER', (tester) async {
    final service = FakeMarketplaceService(
      categories: [
        sampleCategory(),
        sampleCategory(slug: 'comida', name: 'Comida'),
      ],
      listings: [
        sampleListing(),
        sampleListing(
          slug: 'anticucho',
          title: 'Anticucho Crema',
          category: 'Comida',
          categorySlug: 'comida',
        ),
      ],
    );
    await tester.pumpWidget(pumpMarketplace(service));
    await tester.pumpAndSettle();
    expect(find.text('Bandera Crema'), findsOneWidget);
    expect(find.text('Anticucho Crema'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Comida'));
    await tester.pumpAndSettle();
    expect(find.text('Anticucho Crema'), findsOneWidget);
    expect(find.text('Bandera Crema'), findsNothing);
  });

  testWidgets('82_MARKETPLACE_LISTING_DETAIL', (tester) async {
    final service = FakeMarketplaceService(
      detail: sampleListing(),
    );
    await tester.pumpWidget(
      pumpMarketplace(service, initial: '/marketplace/listings/bandera-crema'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bandera Crema'), findsWidgets);
    expect(find.text('S/ 45'), findsOneWidget);
    expect(find.text('Contactar por WhatsApp'), findsOneWidget);
    expect(find.text('Fotos disponibles próximamente'), findsOneWidget);
    expect(find.textContaining('Sin compra'), findsOneWidget);
    expect(find.text('Comprar'), findsNothing);
  });

  testWidgets('82_MARKETPLACE_FAVORITE_OPTIMISTIC', (tester) async {
    final service = FakeMarketplaceService(
      detail: sampleListing(isFavorite: false),
    );
    await tester.pumpWidget(
      pumpMarketplace(service, initial: '/marketplace/listings/bandera-crema'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar a favoritos'));
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    await tester.pumpAndSettle();
    expect(service.favoritePutCalls, 1);
    expect(service.lastFavoriteSlug, 'bandera-crema');
  });

  testWidgets('82_MARKETPLACE_FAVORITE_ROLLBACK', (tester) async {
    final service = FakeMarketplaceService(
      detail: sampleListing(isFavorite: false),
      failFavorite: true,
    );
    await tester.pumpWidget(
      pumpMarketplace(service, initial: '/marketplace/listings/bandera-crema'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar a favoritos'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(
      find.textContaining('No pudimos actualizar el favorito'),
      findsOneWidget,
    );
  });

  testWidgets('82_MARKETPLACE_CONTACT_WHATSAPP', (tester) async {
    Uri? launchedUri;
    marketplaceUrlLauncher = (uri) async {
      launchedUri = uri;
      return true;
    };
    addTearDown(() {
      marketplaceUrlLauncher = (uri) =>
          launchUrl(uri, mode: LaunchMode.externalApplication);
    });

    final service = FakeMarketplaceService(detail: sampleListing());
    await tester.pumpWidget(
      pumpMarketplace(service, initial: '/marketplace/listings/bandera-crema'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contactar por WhatsApp'));
    await tester.pumpAndSettle();
    expect(service.contactCalls, 1);
    expect(service.lastContactSlug, 'bandera-crema');
    expect(launchedUri.toString(), 'https://wa.me/51999999999');
  });

  testWidgets('82_MARKETPLACE_REPORT', (tester) async {
    final service = FakeMarketplaceService(detail: sampleListing());
    await tester.pumpWidget(
      pumpMarketplace(service, initial: '/marketplace/listings/bandera-crema'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reportar'));
    await tester.pumpAndSettle();
    expect(find.text('Reportar publicación'), findsOneWidget);
    await tester.tap(find.text('Spam o engaño'));
    await tester.pumpAndSettle();
    expect(service.reportCalls, 1);
    expect(service.lastReportSlug, 'bandera-crema');
    expect(find.textContaining('Gracias'), findsOneWidget);
  });

  testWidgets('82_MARKETPLACE_STORE_RENDER', (tester) async {
    final service = FakeMarketplaceService(
      store: sampleStore(),
    );
    await tester.pumpWidget(
      pumpMarketplace(service, initial: '/marketplace/stores/tienda-sur'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tienda Sur'), findsWidgets);
    expect(find.text('Bandera Crema'), findsOneWidget);
  });

  testWidgets('82_MARKETPLACE_FAVORITES_EMPTY', (tester) async {
    final service = FakeMarketplaceService();
    await tester.pumpWidget(
      pumpMarketplace(service, initial: '/marketplace/favorites'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GarraEmptyState), findsOneWidget);
    expect(find.text('Sin favoritos'), findsOneWidget);
  });

  testWidgets('82_MARKETPLACE_FAVORITES_RENDER', (tester) async {
    final service = FakeMarketplaceService(
      favorites: [sampleListing(isFavorite: true)],
    );
    await tester.pumpWidget(
      pumpMarketplace(service, initial: '/marketplace/favorites'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bandera Crema'), findsOneWidget);
    expect(find.byType(GarraMarketplaceCard), findsOneWidget);
  });

  testWidgets('82_MARKETPLACE_SELLER_ONBOARDING', (tester) async {
    final service = FakeMarketplaceService(seller: null);
    await tester.pumpWidget(
      pumpMarketplace(service, initial: '/marketplace/seller'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quiero vender'), findsWidgets);
    expect(find.textContaining('propiedad intelectual'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Nombre de la tienda'), findsOneWidget);
  });

  testWidgets('82_MARKETPLACE_SELLER_DASHBOARD', (tester) async {
    final service = FakeMarketplaceService(
      summary: const SellerSummary(
        status: 'APPROVED',
        listingsCount: 2,
        favoritesCount: 5,
        contactsCount: 8,
        storeName: 'Tienda Sur',
      ),
      sellerListings: [sampleListing()],
    );
    await tester.pumpWidget(
      pumpMarketplace(service, initial: '/marketplace/seller/dashboard'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tienda Sur'), findsWidgets);
    expect(find.text('Estado: Aprobado'), findsOneWidget);
    expect(find.text('Publicaciones'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Contactos'), findsOneWidget);
    expect(find.text('Ventas'), findsNothing);
    expect(find.text('Ingresos'), findsNothing);
    expect(find.text('Bandera Crema'), findsOneWidget);
  });

  testWidgets('82_MARKETPLACE_HOME_CTA', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        GoRoute(
          path: '/marketplace',
          builder: (_, _) => const Scaffold(body: Text('MARKETPLACE_ROUTE')),
        ),
        GoRoute(
          path: '/clans',
          builder: (_, _) => const Scaffold(body: Text('CLANS')),
        ),
        GoRoute(
          path: '/passport',
          builder: (_, _) => const Scaffold(body: Text('PASSPORT')),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const Scaffold(body: Text('NOTIF')),
        ),
        GoRoute(
          path: '/muro-crema',
          builder: (_, _) => const Scaffold(body: Text('MURO')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProvider.overrideWith((ref) async => sampleHome()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Marketplace Crema'), findsOneWidget);
    await tester.tap(find.text('Marketplace Crema'));
    await tester.pumpAndSettle();
    expect(find.text('MARKETPLACE_ROUTE'), findsOneWidget);
  });

  testWidgets('82_MARKETPLACE_QUIERO_VENDER_NAV', (tester) async {
    final service = FakeMarketplaceService(
      categories: [sampleCategory()],
      listings: [sampleListing()],
    );
    await tester.pumpWidget(pumpMarketplace(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiero vender'));
    await tester.pumpAndSettle();
    expect(find.textContaining('emprendimiento crema'), findsOneWidget);
  });
}
