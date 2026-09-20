import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/marketplace_models.dart';
import '../../data/marketplace_service.dart';

final marketplaceServiceProvider = Provider<MarketplaceService>((ref) {
  return MarketplaceService();
});

class MarketplaceDiscoveryQuery {
  const MarketplaceDiscoveryQuery({
    this.search = '',
    this.category,
    this.type,
    this.sort,
  });

  final String search;
  final String? category;
  final String? type;
  final String? sort;

  @override
  bool operator ==(Object other) {
    return other is MarketplaceDiscoveryQuery &&
        other.search == search &&
        other.category == category &&
        other.type == type &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(search, category, type, sort);
}

final marketplaceCategoriesProvider =
    FutureProvider.autoDispose<List<MarketplaceCategory>>((ref) {
  return ref.watch(marketplaceServiceProvider).getCategories();
});

final marketplaceListingsProvider = FutureProvider.autoDispose
    .family<List<MarketplaceListing>, MarketplaceDiscoveryQuery>(
        (ref, query) async {
  final page = await ref.watch(marketplaceServiceProvider).getListings(
        search: query.search,
        category: query.category,
        type: query.type,
        sort: query.sort,
      );
  return page.items;
});

final marketplaceListingDetailProvider = FutureProvider.autoDispose
    .family<MarketplaceListing, String>((ref, slug) {
  return ref.watch(marketplaceServiceProvider).getListing(slug);
});

final marketplaceStoreProvider =
    FutureProvider.autoDispose.family<MarketplaceStore, String>((ref, slug) {
  return ref.watch(marketplaceServiceProvider).getStore(slug);
});

final marketplaceFavoritesProvider =
    FutureProvider.autoDispose<List<MarketplaceListing>>((ref) {
  return ref.watch(marketplaceServiceProvider).getFavorites();
});

final sellerMeProvider =
    FutureProvider.autoDispose<SellerProfile?>((ref) {
  return ref.watch(marketplaceServiceProvider).getSellerMe();
});

final sellerSummaryProvider =
    FutureProvider.autoDispose<SellerSummary>((ref) {
  return ref.watch(marketplaceServiceProvider).getSellerSummary();
});

final sellerListingsProvider =
    FutureProvider.autoDispose<List<MarketplaceListing>>((ref) {
  return ref.watch(marketplaceServiceProvider).getSellerListings();
});
