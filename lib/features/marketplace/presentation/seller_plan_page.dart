import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import 'providers/marketplace_provider.dart';

/// Informational Pro plan screen — no price, no purchase.
class SellerPlanPage extends ConsumerWidget {
  const SellerPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(sellerPlanProvider);
    final analyticsAsync = ref.watch(sellerAdvancedAnalyticsProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Plan de vendedor')),
      body: planAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (_, _) => GarraErrorState(
          onRetry: () => ref.invalidate(sellerPlanProvider),
        ),
        data: (plan) {
          return ListView(
            padding: const EdgeInsets.all(GarraSpacing.lg),
            children: [
              Text(
                'PLAN ${plan.code.toUpperCase()}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(GarraColors.gold),
                    ),
              ),
              const SizedBox(height: GarraSpacing.sm),
              Text(
                plan.description ??
                    'Beneficios de tu plan de vendedor en Marketplace Crema.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: GarraSpacing.xxl),
              GarraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qué incluye',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: GarraSpacing.md),
                    _Bullet(
                      'Hasta ${plan.usage.maxActiveListings} publicaciones activas',
                    ),
                    _Bullet(
                      'Hasta ${plan.usage.maxActiveStores} tienda activa',
                    ),
                    _Bullet(
                      plan.features.advancedAnalytics
                          ? 'Analítica avanzada por publicación'
                          : 'Métricas básicas (favoritos y contactos)',
                    ),
                    _Bullet(
                      plan.features.featuredEligible
                          ? 'Elegible para Destacados (asignación admin)'
                          : 'Destacados no incluidos en este plan',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GarraSpacing.lg),
              GarraCard(
                child: Text(
                  'Plan administrado por Garra Digital',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (plan.features.advancedAnalytics) ...[
                const SizedBox(height: GarraSpacing.xxl),
                Text(
                  'Analítica avanzada',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: GarraSpacing.md),
                analyticsAsync.when(
                  loading: () => const GarraSkeleton(height: 80),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (analytics) {
                    if (analytics == null) return const SizedBox.shrink();
                    return GarraCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GarraStat(
                                  label: 'Favoritos',
                                  value: '${analytics.favorites}',
                                ),
                              ),
                              Expanded(
                                child: GarraStat(
                                  label: 'Contactos',
                                  value: '${analytics.contacts}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: GarraSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: GarraStat(
                                  label: 'Impresiones Destacados',
                                  value: '${analytics.featuredImpressions}',
                                ),
                              ),
                              Expanded(
                                child: GarraStat(
                                  label: 'Aperturas Destacados',
                                  value: '${analytics.featuredOpens}',
                                ),
                              ),
                            ],
                          ),
                          if (analytics.listings.isNotEmpty) ...[
                            const SizedBox(height: GarraSpacing.lg),
                            for (final row in analytics.listings.take(5))
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: GarraSpacing.sm,
                                ),
                                child: Text(
                                  '${row.title}: ${row.favorites} fav · ${row.contacts} contactos',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
