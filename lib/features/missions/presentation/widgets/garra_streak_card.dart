import 'package:flutter/material.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/design/garra_typography.dart';
import '../../../../core/widgets/garra_card.dart';
import '../../data/mission_models.dart';

/// Streak card: current + best. Labels use "fechas", never "asistencia".
class GarraStreakCard extends StatelessWidget {
  const GarraStreakCard({
    super.key,
    required this.streak,
    this.compact = false,
  });

  final StreakSummary streak;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!streak.isActive) {
      return GarraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Racha Garra',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: GarraSpacing.sm),
            Text(
              'Aún no tienes racha. Completa misiones de fecha para empezar.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (streak.best > 0) ...[
              const SizedBox(height: GarraSpacing.md),
              Text(
                'Mejor racha: ${streak.best} ${_fechasLabel(streak.best)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(GarraColors.gold),
                    ),
              ),
            ],
          ],
        ),
      );
    }

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Racha Garra',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GarraSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${streak.current}',
                      style: GarraTypography.numeric(size: compact ? 28 : 36),
                    ),
                    const SizedBox(height: GarraSpacing.xs),
                    Text(
                      '${_fechasLabel(streak.current)} actuales',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${streak.best}',
                      style: GarraTypography.numeric(
                        size: compact ? 22 : 28,
                      ).copyWith(
                        color: const Color(GarraColors.gold),
                      ),
                    ),
                    const SizedBox(height: GarraSpacing.xs),
                    Text(
                      'Mejor racha',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fechasLabel(int count) {
    return count == 1 ? 'fecha' : 'fechas';
  }
}
