import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../widgets/garra_marketplace_card.dart';
import '../widgets/garra_plan_usage_card.dart';
import 'providers/marketplace_provider.dart';

class SellerDashboardPage extends ConsumerWidget {
  const SellerDashboardPage({super.key});

  /// MARKETPLACE_V2_A0: a DRAFT store never reaches the admin queue until it
  /// is submitted (POST /marketplace/seller/me/store/submit).
  Future<void> _submitStore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(marketplaceServiceProvider).submitSellerStore();
      ref.invalidate(sellerSummaryProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Tienda enviada a revisi\u00f3n.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No pudimos enviar tu tienda. Int\u00e9ntalo de nuevo.'),
        ),
      );
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'ACTIVE':
        return 'Aprobado';
      case 'DRAFT':
        return 'Borrador';
      case 'PENDING_REVIEW':
      case 'PENDING':
        return 'En revisión';
      case 'REJECTED':
        return 'Rechazado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(sellerSummaryProvider);
    final listingsAsync = ref.watch(sellerListingsProvider);
    final planAsync = ref.watch(sellerPlanProvider);

    return Scaffold(
      backgroundColor: context.garraColors.background,
      appBar: AppBar(
        title: const Text('Mi tienda'),
        actions: [
          IconButton(
            tooltip: 'Plan',
            onPressed: () => context.push('/marketplace/seller/plan'),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
          IconButton(
            tooltip: 'Nueva publicación',
            onPressed: () => context.push('/marketplace/seller/listings/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.garraColors.brandPrestige),
        ),
        error: (_, _) => GarraErrorState(
          onRetry: () {
            ref.invalidate(sellerSummaryProvider);
            ref.invalidate(sellerListingsProvider);
            ref.invalidate(sellerPlanProvider);
          },
        ),
        data: (summary) {
          return RefreshIndicator(
            color: context.garraColors.brandPrestige,
            onRefresh: () async {
              ref.invalidate(sellerSummaryProvider);
              ref.invalidate(sellerListingsProvider);
              ref.invalidate(sellerPlanProvider);
              await Future.wait([
                ref.read(sellerSummaryProvider.future),
                ref.read(sellerListingsProvider.future),
                ref.read(sellerPlanProvider.future),
              ]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.lg,
                GarraSpacing.md,
                GarraSpacing.lg,
                GarraSpacing.section,
              ),
              children: [
                if (summary.storeName != null) ...[
                  Text(
                    summary.storeName!,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: GarraSpacing.sm),
                ],
                planAsync.when(
                  loading: () => const GarraSkeleton(height: 96),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (plan) => GarraPlanUsageCard(plan: plan),
                ),
                const SizedBox(height: GarraSpacing.lg),
                GarraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado: ${_statusLabel(summary.status)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: GarraSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: GarraStat(
                              label: 'Publicaciones',
                              value: '${summary.listingsCount}',
                            ),
                          ),
                          Expanded(
                            child: GarraStat(
                              label: 'Favoritos',
                              value: '${summary.favoritesCount}',
                            ),
                          ),
                          Expanded(
                            child: GarraStat(
                              label: 'Contactos',
                              value: '${summary.contactsCount}',
                            ),
                          ),
                        ],
                      ),
                      if (summary.canSubmitStore) ...[
                        const SizedBox(height: GarraSpacing.lg),
                        Text(
                          'Tu tienda est\u00e1 en borrador. Al enviarla confirmas '
                          'la declaraci\u00f3n de propiedad intelectual.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: GarraSpacing.sm),
                        FilledButton(
                          key: const Key('seller-store-submit'),
                          onPressed: () => _submitStore(context, ref),
                          child: const Text('Enviar tienda a revisi\u00f3n'),
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
                        'Mis publicaciones',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.push('/marketplace/seller/listings/new'),
                      child: const Text('Nueva'),
                    ),
                  ],
                ),
                const SizedBox(height: GarraSpacing.md),
                listingsAsync.when(
                  loading: () => const GarraSkeleton(height: 100),
                  error: (_, _) => GarraErrorState(
                    onRetry: () => ref.invalidate(sellerListingsProvider),
                  ),
                  data: (listings) {
                    if (listings.isEmpty) {
                      return const GarraEmptyState(
                        title: 'Sin publicaciones',
                        message:
                            'Crea tu primera publicación para llegar a la hinchada.',
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
            ),
          );
        },
      ),
    );
  }
}
