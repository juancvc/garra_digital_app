import 'package:flutter/material.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/widgets/garra_card.dart';
import '../../../../core/widgets/garra_ui.dart';
import '../../data/mission_models.dart';

/// Mission card: title, description, reward, progress, completed state.
class GarraMissionCard extends StatelessWidget {
  const GarraMissionCard({
    super.key,
    required this.mission,
    this.showSteps = false,
  });

  final MissionModel mission;
  final bool showSteps;

  @override
  Widget build(BuildContext context) {
    final completed = mission.completed;

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mission.isSponsored) ...[
                      Text(
                        mission.sponsorLabel ??
                            'Patrocinado por ${mission.sponsorName ?? 'sponsor'}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: const Color(GarraColors.gold),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: GarraSpacing.xs),
                    ],
                    Text(
                      mission.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GarraSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: GarraSpacing.sm,
                  vertical: GarraSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: completed
                      ? const Color(GarraColors.success).withValues(alpha: 0.18)
                      : const Color(GarraColors.gold).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  completed
                      ? 'Completada'
                      : '+${mission.rewardPoints} pts',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: completed
                            ? const Color(GarraColors.success)
                            : const Color(GarraColors.gold),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          if (mission.description != null &&
              mission.description!.trim().isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              mission.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: GarraSpacing.md),
          Row(
            children: [
              Expanded(
                child: GarraProgressBar(progress: mission.progressFraction),
              ),
              const SizedBox(width: GarraSpacing.md),
              Text(
                '${mission.completedSteps}/${mission.totalSteps}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          if (!completed) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              'Recompensa: ${mission.rewardPoints} Puntos Garra',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(GarraColors.gold),
                  ),
            ),
          ],
          if (completed) ...[
            const SizedBox(height: GarraSpacing.md),
            _CompletionBanner(rewardPoints: mission.rewardPoints),
          ],
          if (showSteps && mission.steps.isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.lg),
            ...mission.steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
                child: _MissionStepRow(step: step),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.rewardPoints});

  final int rewardPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GarraSpacing.md),
      decoration: BoxDecoration(
        color: const Color(GarraColors.success).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(GarraColors.success).withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.celebration_outlined,
            color: Color(GarraColors.gold),
            size: 22,
          ),
          const SizedBox(width: GarraSpacing.sm),
          Expanded(
            child: Text(
              rewardPoints > 0
                  ? 'Misión completada · +$rewardPoints Puntos Garra'
                  : 'Misión completada',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(GarraColors.cream),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionStepRow extends StatelessWidget {
  const _MissionStepRow({required this.step});

  final MissionStepModel step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          step.completed
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked,
          size: 20,
          color: step.completed
              ? const Color(GarraColors.success)
              : const Color(GarraColors.textSecondary),
        ),
        const SizedBox(width: GarraSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: step.completed
                          ? const Color(GarraColors.textSecondary)
                          : const Color(GarraColors.textPrimary),
                      decoration: step.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
              ),
              if (step.requiredCount > 1)
                Text(
                  '${step.currentCount}/${step.requiredCount}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
