import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/marketplace_models.dart';
import '../widgets/garra_marketplace_card.dart';
import 'providers/marketplace_provider.dart';

/// Labels for the real backend StoreStatus values (an admin rejection returns
/// the store to DRAFT; there is no REJECTED store status).
String marketplaceStoreStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT':
      return 'Borrador';
    case 'PENDING_REVIEW':
      return 'En revisi\u00f3n';
    case 'ACTIVE':
      return 'Activo';
    case 'SUSPENDED':
      return 'Suspendido';
    case 'ARCHIVED':
      return 'Archivado';
    default:
      return status;
  }
}

/// MARKETPLACE_V2_A1: manage one business. Every call uses the explicit
/// [storeId] (never the legacy singular /seller/me/store aliases).
class SellerStorePage extends ConsumerWidget {
  const SellerStorePage({super.key, required this.storeId});

  final String storeId;

  String _hint(MarketplaceStore store, bool sellerActive) {
    switch (store.status.toUpperCase()) {
      case 'DRAFT':
        return sellerActive
            ? 'Tu negocio est\u00e1 en borrador. Al enviarlo confirmas la '
                  'declaraci\u00f3n de propiedad intelectual.'
            : 'Podr\u00e1s enviarlo a revisi\u00f3n cuando tu perfil de '
                  'vendedor est\u00e9 aprobado.';
      case 'PENDING_REVIEW':
        return 'En revisi\u00f3n: te avisaremos cuando sea aprobado.';
      case 'ACTIVE':
        return 'Negocio activo: sus publicaciones aprobadas son visibles.';
      case 'SUSPENDED':
        return 'Negocio suspendido por moderaci\u00f3n.';
      case 'ARCHIVED':
        return 'Negocio archivado: solo queda como historial.';
      default:
        return '';
    }
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(marketplaceServiceProvider).submitSellerStoreById(storeId);
      ref.invalidate(sellerStoreProvider(storeId));
      ref.invalidate(sellerStoresProvider);
      ref.invalidate(sellerSummaryProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Negocio enviado a revisi\u00f3n.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(sellerStoreProvider(storeId));
    final listingsAsync = ref.watch(sellerStoreListingsProvider(storeId));
    final sellerActive =
        ref.watch(sellerSummaryProvider).asData?.value.sellerActive ?? false;

    return Scaffold(
      backgroundColor: context.garraColors.background,
      appBar: AppBar(title: const Text('Mi negocio')),
      body: storeAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: context.garraColors.brandPrestige,
          ),
        ),
        error: (_, _) => GarraErrorState(
          onRetry: () => ref.invalidate(sellerStoreProvider(storeId)),
        ),
        data: (store) {
          final editable =
              !store.isArchived && store.status.toUpperCase() != 'SUSPENDED';
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.md,
              GarraSpacing.lg,
              GarraSpacing.section,
            ),
            children: [
              GarraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: GarraSpacing.xs),
                    Text(
                      'Estado: ${marketplaceStoreStatusLabel(store.status)}',
                      key: const Key('seller-store-status'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: GarraSpacing.sm),
                    Text(
                      _hint(store, sellerActive),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (editable) ...[
                      const SizedBox(height: GarraSpacing.md),
                      Wrap(
                        spacing: GarraSpacing.sm,
                        runSpacing: GarraSpacing.sm,
                        children: [
                          OutlinedButton(
                            key: const Key('seller-store-edit'),
                            onPressed: () => context.push(
                              '/marketplace/seller/stores/$storeId/edit',
                            ),
                            child: const Text('Editar negocio'),
                          ),
                          if (store.isDraft && sellerActive)
                            FilledButton(
                              key: const Key('seller-store-submit'),
                              onPressed: () => _submit(context, ref),
                              child: const Text('Enviar a revisi\u00f3n'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: GarraSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Publicaciones',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!store.isArchived)
                    TextButton(
                      key: const Key('seller-store-new-listing'),
                      onPressed: () => context.push(
                        '/marketplace/seller/stores/$storeId/listings/new',
                      ),
                      child: const Text('Nueva'),
                    ),
                ],
              ),
              const SizedBox(height: GarraSpacing.md),
              listingsAsync.when(
                loading: () => const GarraSkeleton(height: 100),
                error: (_, _) => GarraErrorState(
                  onRetry: () =>
                      ref.invalidate(sellerStoreListingsProvider(storeId)),
                ),
                data: (listings) {
                  if (listings.isEmpty) {
                    return const GarraEmptyState(
                      title: 'Sin publicaciones',
                      message: 'Este negocio a\u00fan no tiene publicaciones.',
                    );
                  }
                  return Column(
                    children: [
                      for (final listing in listings) ...[
                        GarraMarketplaceCard(
                          listing: listing,
                          showFavorite: false,
                          onTap: () => context.push(
                            '/marketplace/seller/listings/${listing.slug}/edit',
                          ),
                        ),
                        const SizedBox(height: GarraSpacing.md),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
