import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_brand_visual.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/marketplace_models.dart';
import '../widgets/garra_marketplace_card.dart';
import 'providers/marketplace_provider.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String? _categorySlug;
  final Set<String> _impressedPromotions = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  MarketplaceDiscoveryQuery get _query =>
      MarketplaceDiscoveryQuery(search: _search, category: _categorySlug);

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(marketplaceCategoriesProvider);
    ref.invalidate(marketplaceListingsProvider(_query));
    ref.invalidate(marketplaceFeaturedProvider);
    await Future.wait([
      ref.read(marketplaceCategoriesProvider.future),
      ref.read(marketplaceListingsProvider(_query).future),
      ref.read(marketplaceFeaturedProvider.future),
    ]);
  }

  void _trackImpression(String? promotionId) {
    if (promotionId == null || promotionId.isEmpty) return;
    if (_impressedPromotions.contains(promotionId)) return;
    _impressedPromotions.add(promotionId);
    ref.read(marketplaceServiceProvider).trackPromotionImpression(promotionId);
  }

  Future<void> _openFeaturedListing(MarketplaceListing listing) async {
    final promoId = listing.promotionId;
    if (promoId != null && promoId.isNotEmpty) {
      // Fire-and-forget; never block navigation.
      unawaited(
        ref.read(marketplaceServiceProvider).trackPromotionOpen(promoId),
      );
    }
    if (!mounted) return;
    final path = promoId == null || promoId.isEmpty
        ? '/marketplace/listings/${listing.slug}'
        : '/marketplace/listings/${listing.slug}?promotionId=$promoId';
    context.push(path);
  }

  Future<void> _toggleFavorite(MarketplaceListing listing) async {
    final service = ref.read(marketplaceServiceProvider);
    final wasFavorite = listing.isFavorite;
    try {
      if (wasFavorite) {
        await service.removeFavorite(listing.slug);
      } else {
        await service.addFavorite(listing.slug);
      }
      ref.invalidate(marketplaceListingsProvider(_query));
      ref.invalidate(marketplaceFavoritesProvider);
      ref.invalidate(marketplaceFeaturedProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos actualizar el favorito. Inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(marketplaceCategoriesProvider);
    final listingsAsync = ref.watch(marketplaceListingsProvider(_query));
    final featuredAsync = ref.watch(marketplaceFeaturedProvider);

    final isLoading = categoriesAsync.isLoading || listingsAsync.isLoading;
    final hasError = categoriesAsync.hasError && listingsAsync.hasError;

    final sellerAsync = ref.watch(sellerMeProvider);
    final isSeller = sellerAsync.asData?.value != null;

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Marketplace Crema'),
        actions: [
          IconButton(
            tooltip: 'Favoritos',
            onPressed: () => context.push('/marketplace/favorites'),
            icon: const Icon(Icons.favorite_border),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          isSeller ? '/marketplace/seller/dashboard' : '/marketplace/seller',
        ),
        backgroundColor: const Color(GarraColors.garnet),
        foregroundColor: const Color(GarraColors.cream),
        icon: const Icon(Icons.storefront_outlined),
        label: Text(isSeller ? 'Mi negocio' : 'Publica tu emprendimiento'),
      ),
      body: hasError
          ? GarraErrorState(onRetry: _refresh)
          : isLoading && !listingsAsync.hasValue && !categoriesAsync.hasValue
          ? const _MarketplaceSkeleton()
          : RefreshIndicator(
              color: const Color(GarraColors.gold),
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  GarraSpacing.lg,
                  GarraSpacing.md,
                  GarraSpacing.lg,
                  100,
                ),
                children: [
                  GarraAtmosphericHero(
                    height: 196,
                    alignment: const Alignment(0.3, -0.2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GarraEditorialEyebrow(
                          label: 'Hecho con garra',
                          icon: Icons.storefront_outlined,
                        ),
                        const SizedBox(height: GarraSpacing.sm),
                        Text(
                          'Compra crema.\nImpulsa a los nuestros.',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(GarraColors.cream),
                                fontWeight: FontWeight.w900,
                                height: 1.02,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: GarraSpacing.sm),
                        Text(
                          'Productos e historias de emprendimientos de la hinchada.',
                          maxLines: 2,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(GarraColors.creamMuted),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.lg),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    onSubmitted: (value) {
                      _debounce?.cancel();
                      setState(() => _search = value.trim());
                    },
                    decoration: const InputDecoration(
                      hintText: 'Buscar emprendimientos…',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.lg),
                  categoriesAsync.when(
                    loading: () => const GarraSkeleton(height: 40),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (categories) => _CategoryChips(
                      categories: categories,
                      selectedSlug: _categorySlug,
                      onSelected: (slug) {
                        setState(() {
                          _categorySlug = _categorySlug == slug ? null : slug;
                        });
                      },
                    ),
                  ),
                  featuredAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (featured) {
                      if (!featured.hasHero && !featured.hasFeatured) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (featured.hasHero) ...[
                            const SizedBox(height: GarraSpacing.xl),
                            const GarraSectionHeader(title: 'Destacados'),
                            const SizedBox(height: GarraSpacing.md),
                            for (final listing in featured.heroListings) ...[
                              GarraMarketplaceCard(
                                listing: listing,
                                showFavorite: false,
                                onVisible: () =>
                                    _trackImpression(listing.promotionId),
                                onTap: () => _openFeaturedListing(listing),
                              ),
                              const SizedBox(height: GarraSpacing.md),
                            ],
                          ],
                          if (featured.hasFeatured) ...[
                            const SizedBox(height: GarraSpacing.xl),
                            const GarraSectionHeader(title: 'Destacados'),
                            const SizedBox(height: GarraSpacing.md),
                            for (final listing
                                in featured.featuredListings) ...[
                              GarraMarketplaceCard(
                                listing: listing,
                                onVisible: () =>
                                    _trackImpression(listing.promotionId),
                                onTap: () => _openFeaturedListing(listing),
                                onFavoriteTap: () => _toggleFavorite(listing),
                              ),
                              const SizedBox(height: GarraSpacing.md),
                            ],
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: GarraSpacing.lg),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push(
                        isSeller
                            ? '/marketplace/seller/dashboard'
                            : '/marketplace/seller',
                      ),
                      borderRadius: BorderRadius.circular(GarraRadius.lg),
                      child: GarraSectionAtmosphere(
                        padding: const EdgeInsets.all(GarraSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(GarraColors.gold),
                                borderRadius: BorderRadius.circular(
                                  GarraRadius.sm,
                                ),
                              ),
                              child: const Icon(
                                Icons.storefront_outlined,
                                color: Color(GarraColors.burgundyDeep),
                              ),
                            ),
                            const SizedBox(width: GarraSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSeller
                                        ? 'Tu vitrina crema'
                                        : 'Pon tu talento en vitrina',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: const Color(GarraColors.cream),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: GarraSpacing.xs),
                                  Text(
                                    isSeller
                                        ? 'Entra a tu negocio'
                                        : 'Publica tu emprendimiento',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(
                                            GarraColors.creamMuted,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              color: Color(GarraColors.gold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.xxl),
                  GarraSectionHeader(title: 'Publicaciones recientes'),
                  const SizedBox(height: GarraSpacing.md),
                  listingsAsync.when(
                    loading: () => const GarraSkeleton(height: 140),
                    error: (_, _) => GarraErrorState(onRetry: _refresh),
                    data: (listings) {
                      if (listings.isEmpty) {
                        return const GarraEmptyState(
                          title: 'Marketplace Crema',
                          message: 'Los emprendimientos crema aparecerán aquí.',
                        );
                      }
                      return Column(
                        children: [
                          for (final listing in listings) ...[
                            GarraMarketplaceCard(
                              listing: listing,
                              onTap: () => context.push(
                                '/marketplace/listings/${listing.slug}',
                              ),
                              onFavoriteTap: () => _toggleFavorite(listing),
                            ),
                            const SizedBox(height: GarraSpacing.md),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedSlug,
    required this.onSelected,
  });

  final List<MarketplaceCategory> categories;
  final String? selectedSlug;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: GarraSpacing.sm),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category.slug == selectedSlug;
          return FilterChip(
            label: Text(category.name),
            selected: selected,
            onSelected: (_) => onSelected(category.slug),
            selectedColor: const Color(
              GarraColors.garnet,
            ).withValues(alpha: 0.35),
            checkmarkColor: const Color(GarraColors.gold),
            labelStyle: TextStyle(
              color: selected
                  ? const Color(GarraColors.cream)
                  : const Color(GarraColors.textSecondary),
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: selected
                  ? const Color(GarraColors.gold)
                  : const Color(GarraColors.borderSubtle),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GarraRadius.pill),
            ),
            backgroundColor: const Color(GarraColors.surface),
          );
        },
      ),
    );
  }
}

class _MarketplaceSkeleton extends StatelessWidget {
  const _MarketplaceSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: const [
        GarraSkeleton(height: 52),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 40),
        SizedBox(height: GarraSpacing.lg),
        GarraSkeleton(height: 72),
        SizedBox(height: GarraSpacing.xxl),
        GarraSkeleton(height: 100),
        SizedBox(height: GarraSpacing.md),
        GarraSkeleton(height: 100),
      ],
    );
  }
}
