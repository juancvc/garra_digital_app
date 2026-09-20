import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
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

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  MarketplaceDiscoveryQuery get _query => MarketplaceDiscoveryQuery(
        search: _search,
        category: _categorySlug,
      );

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
    await Future.wait([
      ref.read(marketplaceCategoriesProvider.future),
      ref.read(marketplaceListingsProvider(_query).future),
    ]);
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos actualizar el favorito. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(marketplaceCategoriesProvider);
    final listingsAsync = ref.watch(marketplaceListingsProvider(_query));

    final isLoading = categoriesAsync.isLoading || listingsAsync.isLoading;
    final hasError = categoriesAsync.hasError && listingsAsync.hasError;

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
                      GarraSpacing.section,
                    ),
                    children: [
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
                              _categorySlug =
                                  _categorySlug == slug ? null : slug;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: GarraSpacing.lg),
                      GarraCard(
                        onTap: () => context.push('/marketplace/seller'),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              color: Color(GarraColors.gold),
                            ),
                            const SizedBox(width: GarraSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quiero vender',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: GarraSpacing.xs),
                                  Text(
                                    'Publica tu emprendimiento crema',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(GarraColors.gold),
                            ),
                          ],
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
                              message:
                                  'Los emprendimientos crema aparecerán aquí.',
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
                                  onFavoriteTap: () =>
                                      _toggleFavorite(listing),
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
            selectedColor:
                const Color(GarraColors.garnet).withValues(alpha: 0.35),
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
