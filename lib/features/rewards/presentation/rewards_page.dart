import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../widgets/garra_reward_card.dart';
import 'providers/reward_provider.dart';

class RewardsPage extends ConsumerWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(rewardCatalogProvider);
    final home = ref.watch(homeProvider);
    final points = home.maybeWhen(
      data: (h) => h.fan.points,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Beneficios'),
        actions: [
          TextButton(
            onPressed: () => context.push('/rewards/me'),
            child: const Text('Mis canjes'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rewardCatalogProvider);
          ref.invalidate(homeProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(GarraSpacing.lg),
          children: [
            GarraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Puntos Garra',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(GarraColors.gold),
                        ),
                  ),
                  const SizedBox(height: GarraSpacing.sm),
                  Text(
                    points == null
                        ? '—'
                        : NumberFormat('#,###').format(points),
                    style: GarraTypography.numeric(size: 32),
                  ),
                  const SizedBox(height: GarraSpacing.xs),
                  Text(
                    'Canjea beneficios reales. No es dinero ni saldo transferible.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: GarraSpacing.xl),
            const GarraSectionHeader(
              title: 'Beneficios disponibles',
              subtitle: 'Canjea con tus Puntos Garra.',
            ),
            const SizedBox(height: GarraSpacing.md),
            catalog.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: GarraSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => GarraErrorState(
                message: 'No pudimos cargar los beneficios.',
                onRetry: () => ref.invalidate(rewardCatalogProvider),
              ),
              data: (offers) {
                if (offers.isEmpty) {
                  return GarraCard(
                    child: Text(
                      'Por ahora no hay beneficios disponibles. Sigue participando y vuelve pronto.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final offer in offers) ...[
                      GarraRewardCard(
                        offer: offer,
                        onTap: () => context.push('/rewards/${offer.slug}'),
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
