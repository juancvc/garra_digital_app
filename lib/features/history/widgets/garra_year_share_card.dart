import 'package:flutter/material.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../data/history_models.dart';

/// 9:16 shareable recap card rendered from the safe share DTO only.
class GarraYearShareCard extends StatelessWidget {
  const GarraYearShareCard({
    super.key,
    required this.share,
  });

  final FanYearShareDto share;

  static const double aspectWidth = 9;
  static const double aspectHeight = 16;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if (share.bestStreak != null && share.bestStreak! > 0) {
      lines.add('🔥 ${share.bestStreak} fechas de Racha Garra');
    }
    if (share.predictionPoints != null && share.predictionPoints! > 0) {
      lines.add('🎯 ${share.predictionPoints} pts en La Polla');
    }
    if (share.missionsCompleted != null && share.missionsCompleted! > 0) {
      lines.add('🏆 ${share.missionsCompleted} misiones');
    }
    if (share.matchdaysParticipated != null &&
        share.matchdaysParticipated! > 0) {
      lines.add('⚡ ${share.matchdaysParticipated} fechas participadas');
    }
    if (share.pointsEarned != null && share.pointsEarned! > 0) {
      lines.add('✨ ${share.pointsEarned} pts ganados');
    }
    if (share.primaryClanName != null &&
        share.primaryClanName!.trim().isNotEmpty) {
      lines.add('🛡 ${share.primaryClanName}');
    }

    return AspectRatio(
      aspectRatio: aspectWidth / aspectHeight,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(GarraColors.garnetDeep),
              Color(GarraColors.charcoal),
              Color(0xFF0A0A0A),
            ],
          ),
          borderRadius: BorderRadius.circular(GarraRadius.lg),
          border: Border.all(
            color: const Color(GarraColors.gold).withValues(alpha: 0.35),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.xxl,
          GarraSpacing.section,
          GarraSpacing.xxl,
          GarraSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GARRA DIGITAL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(GarraColors.gold),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: GarraSpacing.lg),
            Text(
              'MI AÑO CREMA ${share.year}',
              style: GarraTypography.numeric(size: 28).copyWith(
                color: const Color(GarraColors.cream),
              ),
            ),
            const SizedBox(height: GarraSpacing.md),
            Text(
              share.displayName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (share.levelName != null &&
                share.levelName!.trim().isNotEmpty) ...[
              const SizedBox(height: GarraSpacing.xs),
              Text(
                share.levelName!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(GarraColors.gold),
                    ),
              ),
            ],
            const SizedBox(height: GarraSpacing.xxl),
            Expanded(
              child: lines.isEmpty
                  ? Text(
                      'Tu historia recién comienza.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < lines.length; i++) ...[
                          if (i > 0) const SizedBox(height: GarraSpacing.md),
                          Text(
                            lines[i],
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ],
                    ),
            ),
            Text(
              share.tagline?.trim().isNotEmpty == true
                  ? share.tagline!
                  : 'Más que hinchas.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(GarraColors.creamMuted),
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
