import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import 'providers/reward_provider.dart';

class MyRewardsPage extends ConsumerWidget {
  const MyRewardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myRewardsProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Mis canjes')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myRewardsProvider),
        child: mine.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => GarraErrorState(
            message: 'No pudimos cargar tus canjes.',
            onRetry: () => ref.invalidate(myRewardsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(GarraSpacing.lg),
                children: [
                  GarraCard(
                    child: Text(
                      'Aún no has canjeado beneficios. Explora el catálogo con tus Puntos Garra.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(GarraSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: GarraSpacing.md),
              itemBuilder: (context, i) {
                final r = items[i];
                return GarraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.statusLabelEs,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: const Color(GarraColors.gold),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: GarraSpacing.xs),
                      Text(r.rewardTitle,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: GarraSpacing.xs),
                      Text(r.providerLabel,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: GarraSpacing.md),
                      if (r.status == 'ISSUED') ...[
                        Center(
                          child: QrImageView(
                            data: r.redemptionCode,
                            version: QrVersions.auto,
                            size: 120,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: GarraSpacing.sm),
                      ],
                      Text(
                        r.redemptionCode,
                        style: GarraTypography.numeric(size: 16),
                      ),
                      const SizedBox(height: GarraSpacing.xs),
                      Text(
                        '${r.pointsSpent} Puntos Garra',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
