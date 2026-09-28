import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/utils/country_labels.dart';
import '../../../../core/widgets/garra_avatar.dart';
import '../../../../core/widgets/garra_card.dart';
import '../../data/clan_models.dart';

/// Clan card: logo fallback, name, location, member count, join policy.
/// No verified checkmark.
class GarraClanCard extends StatelessWidget {
  const GarraClanCard({
    super.key,
    required this.clan,
    this.onTap,
    this.trailing,
    this.showJoinPolicy = true,
    this.roleLabel,
    this.isPrimary = false,
  });

  final ClanModel clan;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showJoinPolicy;
  final String? roleLabel;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final members = NumberFormat.decimalPattern('es').format(clan.memberCount);
    final location = clan.locationLabel;

    return GarraCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GarraAvatar(
            key: const ValueKey('clan_card_avatar'),
            displayName: clan.name,
            avatarUrl: clan.logoUrl,
            size: 52,
          ),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clan.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(width: GarraSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: GarraSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.garraColors.brandPrestige
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Principal',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: context.garraColors.brandPrestige,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: GarraSpacing.xs),
                  Text(
                    location,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: GarraSpacing.sm),
                Wrap(
                  spacing: GarraSpacing.sm,
                  runSpacing: GarraSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$members miembros',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (showJoinPolicy)
                      _Pill(
                        label: ClanJoinPolicyLabels.indicator(clan.joinPolicy),
                      ),
                    if (clan.visibility.toUpperCase() != 'PUBLIC')
                      _Pill(label: clanVisibilityLabel(clan.visibility)),
                    if (roleLabel != null && roleLabel!.isNotEmpty)
                      _Pill(
                        label: roleLabel!,
                        accent: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: GarraSpacing.sm),
            trailing!,
          ] else if (onTap != null)
            Icon(
              Icons.chevron_right,
              color: context.garraColors.brandPrestige,
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GarraSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: accent
            ? context.garraColors.brandPrimary.withValues(alpha: 0.28)
            : context.garraColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.garraColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent
                  ? context.garraColors.textPrimary
                  : context.garraColors.textSecondary,
            ),
      ),
    );
  }
}
