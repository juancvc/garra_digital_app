import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../data/history_models.dart';

class GarraHistoryCard extends StatelessWidget {
  const GarraHistoryCard({
    super.key,
    required this.entry,
  });

  final FanHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final style = _variantStyle(entry.variant);
    final when = DateFormat('d MMM · HH:mm').format(entry.occurredAt.toLocal());

    return GarraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(GarraRadius.sm),
            ),
            child: Icon(style.icon, color: style.accent, size: 22),
          ),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: style.accent,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (entry.subtitle != null &&
                    entry.subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: GarraSpacing.xs),
                  Text(
                    entry.subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  when,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _HistoryVariantStyle _variantStyle(HistoryCardVariant variant) {
    switch (variant) {
      case HistoryCardVariant.prediction:
        return const _HistoryVariantStyle(
          label: 'Polla',
          icon: Icons.sports_soccer_rounded,
          accent: Color(GarraColors.gold),
        );
      case HistoryCardVariant.checkin:
        return const _HistoryVariantStyle(
          label: 'Check-in',
          icon: Icons.location_on_rounded,
          accent: Color(GarraColors.cream),
        );
      case HistoryCardVariant.mission:
        return const _HistoryVariantStyle(
          label: 'Misión',
          icon: Icons.emoji_events_rounded,
          accent: Color(GarraColors.gold),
        );
      case HistoryCardVariant.streak:
        return const _HistoryVariantStyle(
          label: 'Racha',
          icon: Icons.local_fire_department_rounded,
          accent: Color(GarraColors.warning),
        );
      case HistoryCardVariant.community:
        return const _HistoryVariantStyle(
          label: 'Comunidad',
          icon: Icons.forum_rounded,
          accent: Color(GarraColors.creamMuted),
        );
      case HistoryCardVariant.clan:
        return const _HistoryVariantStyle(
          label: 'Clan',
          icon: Icons.shield_rounded,
          accent: Color(GarraColors.garnet),
        );
    }
  }
}

class _HistoryVariantStyle {
  const _HistoryVariantStyle({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;
}
