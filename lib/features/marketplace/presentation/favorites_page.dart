import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_states.dart';
import '../widgets/garra_marketplace_card.dart';
import 'providers/marketplace_provider.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceFavoritesProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Favoritos')),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (_, _) => GarraErrorState(
          onRetry: () => ref.invalidate(marketplaceFavoritesProvider),
        ),
        data: (listings) {
          if (listings.isEmpty) {
            return const GarraEmptyState(
              title: 'Sin favoritos',
              message: 'Guarda publicaciones crema para verlas aquí.',
            );
          }
          return RefreshIndicator(
            color: const Color(GarraColors.gold),
            onRefresh: () async {
              ref.invalidate(marketplaceFavoritesProvider);
              await ref.read(marketplaceFavoritesProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.lg,
                GarraSpacing.md,
                GarraSpacing.lg,
                GarraSpacing.section,
              ),
              itemCount: listings.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: GarraSpacing.md),
              itemBuilder: (context, index) {
                final listing = listings[index];
                return GarraMarketplaceCard(
                  listing: listing.copyWith(isFavorite: true),
                  onTap: () => context.push(
                    '/marketplace/listings/${listing.slug}',
                  ),
                  onFavoriteTap: () async {
                    try {
                      await ref
                          .read(marketplaceServiceProvider)
                          .removeFavorite(listing.slug);
                      ref.invalidate(marketplaceFavoritesProvider);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No pudimos actualizar el favorito. Inténtalo de nuevo.',
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
