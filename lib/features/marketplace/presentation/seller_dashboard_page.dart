import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/marketplace_models.dart';
import '../widgets/garra_plan_usage_card.dart';
import 'providers/marketplace_provider.dart';
import 'seller_store_page.dart';

class SellerDashboardPage extends ConsumerWidget {
  const SellerDashboardPage({super.key});

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'ACTIVE':
        return 'Aprobado';
      case 'DRAFT':
        return 'Borrador';
      case 'PENDING_REVIEW':
      case 'PENDING':
        return 'En revisi\u00f3n';
      case 'REJECTED':
        return 'Rechazado';
      case 'SUSPENDED':
        return 'Suspendido';
      default:
        return status;
    }
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(sellerSummaryProvider);
    ref.invalidate(sellerStoresProvider);
    ref.invalidate(sellerPlanProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(sellerSummaryProvider);
    final storesAsync = ref.watch(sellerStoresProvider);
    final planAsync = ref.watch(sellerPlanProvider);

    return Scaffold(
      backgroundColor: context.garraColors.background,
      appBar: AppBar(
        title: const Text('Panel de vendedor'),
        actions: [
          IconButton(
            tooltip: 'Plan',
            onPressed: () => context.push('/marketplace/seller/plan'),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
          IconButton(
            tooltip: 'Nueva publicaci\u00f3n',
            // The form picks the business: auto with one, explicit with 2-3.
            onPressed: () => context.push('/marketplace/seller/listings/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.garraColors.brandPrestige),
        ),
        error: (_, _) => GarraErrorState(onRetry: () => _refresh(ref)),
        data: (summary) {
          return RefreshIndicator(
            color: context.garraColors.brandPrestige,
            onRefresh: () async {
              _refresh(ref);
              await Future.wait([
                ref.read(sellerSummaryProvider.future),
                ref.read(sellerStoresProvider.future),
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
                    ],
                  ),
                ),
                const SizedBox(height: GarraSpacing.xxl),
                storesAsync.when(
                  loading: () => const GarraSkeleton(height: 100),
                  error: (_, _) => GarraErrorState(
                    onRetry: () => ref.invalidate(sellerStoresProvider),
                  ),
                  data: (stores) => _MyBusinessesSection(stores: stores),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// MARKETPLACE_V2_A1 "Mis negocios": up to [kMarketplaceMaxStores]
/// non-archived businesses (each one managed through its own storeId) plus
/// the archived history. Data comes from a single GET /seller/me/stores.
class _MyBusinessesSection extends StatelessWidget {
  const _MyBusinessesSection({required this.stores});

  final List<MarketplaceStore> stores;

  @override
  Widget build(BuildContext context) {
    final active = stores.where((s) => !s.isArchived).toList();
    final archived = stores.where((s) => s.isArchived).toList();
    final atLimit = active.length >= kMarketplaceMaxStores;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Mis negocios', style: textTheme.titleMedium)),
            Text(
              '${active.length}/$kMarketplaceMaxStores',
              key: const Key('seller-stores-count'),
              style: textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: GarraSpacing.md),
        if (active.isEmpty)
          const GarraEmptyState(
            title: 'Sin negocios',
            message: 'Crea tu primer negocio para publicar en Marketplace.',
          ),
        for (final store in active) ...[
          _StoreCard(store: store),
          const SizedBox(height: GarraSpacing.md),
        ],
        OutlinedButton.icon(
          key: const Key('seller-store-create'),
          onPressed: atLimit
              ? null
              : () => context.push('/marketplace/seller/stores/new'),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Crear negocio'),
        ),
        if (atLimit) ...[
          const SizedBox(height: GarraSpacing.sm),
          Text(
            'Puedes administrar hasta $kMarketplaceMaxStores negocios.',
            key: const Key('seller-stores-limit'),
            style: textTheme.bodySmall,
          ),
        ],
        if (archived.isNotEmpty) ...[
          const SizedBox(height: GarraSpacing.xl),
          Text('Archivados', style: textTheme.titleSmall),
          for (final store in archived)
            ListTile(
              key: Key('seller-store-archived-${store.id}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(store.name),
              subtitle: Text(marketplaceStoreStatusLabel(store.status)),
              onTap: () => context.push('/marketplace/seller/stores/${store.id}'),
            ),
        ],
      ],
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final MarketplaceStore store;

  @override
  Widget build(BuildContext context) {
    final logo = store.logoUrl;
    final initial = store.name.trim().isEmpty
        ? '?'
        : store.name.trim().substring(0, 1).toUpperCase();
    void manage() => context.push('/marketplace/seller/stores/${store.id}');

    return GarraCard(
      key: Key('seller-store-card-${store.id}'),
      onTap: manage,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            foregroundImage:
                logo != null && logo.isNotEmpty ? NetworkImage(logo) : null,
            onForegroundImageError:
                logo != null && logo.isNotEmpty ? (_, _) {} : null,
            child: Text(initial),
          ),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  marketplaceStoreStatusLabel(store.status),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            key: Key('seller-store-manage-${store.id}'),
            onPressed: manage,
            child: const Text('Administrar'),
          ),
        ],
      ),
    );
  }
}