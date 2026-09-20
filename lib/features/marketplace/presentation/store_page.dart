import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../widgets/garra_marketplace_card.dart';
import 'providers/marketplace_provider.dart';

class StorePage extends ConsumerWidget {
  const StorePage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceStoreProvider(slug));

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Tienda crema')),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (_, _) => GarraErrorState(
          onRetry: () => ref.invalidate(marketplaceStoreProvider(slug)),
        ),
        data: (store) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.md,
              GarraSpacing.lg,
              GarraSpacing.section,
            ),
            children: [
              Text(
                store.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (store.city != null && store.city!.isNotEmpty) ...[
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  store.city!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (store.description != null &&
                  store.description!.trim().isNotEmpty) ...[
                const SizedBox(height: GarraSpacing.lg),
                Text(
                  store.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: GarraSpacing.xxl),
              const GarraSectionHeader(title: 'Publicaciones'),
              const SizedBox(height: GarraSpacing.md),
              if (store.listings.isEmpty)
                const GarraEmptyState(
                  title: 'Sin publicaciones',
                  message: 'Esta tienda aún no tiene publicaciones activas.',
                )
              else
                for (final listing in store.listings) ...[
                  GarraMarketplaceCard(
                    listing: listing,
                    showFavorite: false,
                    onTap: () => context.push(
                      '/marketplace/listings/${listing.slug}',
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.md),
                ],
            ],
          );
        },
      ),
    );
  }
}
