import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../data/marketplace_models.dart';

/// Compact seller plan + usage. No prices. No checkout.
class GarraPlanUsageCard extends StatelessWidget {
  const GarraPlanUsageCard({
    super.key,
    required this.plan,
    this.onLearnPro,
  });

  final SellerPlan plan;
  final VoidCallback? onLearnPro;

  @override
  Widget build(BuildContext context) {
    final usageLabel =
        '${plan.usage.activeListings} / ${plan.usage.maxActiveListings} publicaciones activas';

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLAN ${plan.code.toUpperCase()}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(GarraColors.gold),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: GarraSpacing.sm),
          Text(
            usageLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: GarraSpacing.sm),
          Text(
            plan.features.advancedAnalytics
                ? 'Analítica avanzada · Elegible para Destacados'
                : 'Métricas básicas · Destacados no incluidos en el plan',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (plan.limitReached) ...[
            const SizedBox(height: GarraSpacing.md),
            Text(
              'Alcanzaste el límite de publicaciones activas de tu plan.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(GarraColors.gold),
                  ),
            ),
          ],
          if (plan.isFree) ...[
            const SizedBox(height: GarraSpacing.md),
            TextButton(
              onPressed: onLearnPro ??
                  () => context.push('/marketplace/seller/plan'),
              child: const Text('Conocer Plan Pro'),
            ),
          ],
        ],
      ),
    );
  }
}
