import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_card.dart';
import '../data/reward_models.dart';

class GarraRewardCard extends StatelessWidget {
  const GarraRewardCard({
    super.key,
    required this.offer,
    this.onTap,
  });

  final RewardOffer offer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(GarraRadius.md),
            child: SizedBox(
              width: 72,
              height: 72,
              child: offer.imageUrl != null && offer.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: offer.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _fallback(context),
                    )
                  : _fallback(context),
            ),
          ),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.sponsored
                      ? 'Patrocinado por ${offer.providerName ?? offer.providerLabel}'
                      : offer.providerLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.garraColors.brandPrestige,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: GarraSpacing.xs),
                Text(
                  offer.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  '${offer.pointsCost} Puntos Garra',
                  style: GarraTypography.numeric(size: 16),
                ),
                if (!offer.available) ...[
                  const SizedBox(height: GarraSpacing.xs),
                  Text(
                    offer.ineligibilityReason ?? 'No disponible',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.garraColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.garraColors.brandPrestige),
        ],
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: context.garraColors.surfaceRaised,
      child: Icon(
        Icons.card_giftcard_outlined,
        color: context.garraColors.brandPrestige,
      ),
    );
  }
}
