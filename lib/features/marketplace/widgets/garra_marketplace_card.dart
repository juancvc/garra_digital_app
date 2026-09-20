import 'package:flutter/material.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../data/marketplace_models.dart';

/// Listing card for Marketplace Crema — cream/garnet identity, not a ML clone.
class GarraMarketplaceCard extends StatelessWidget {
  const GarraMarketplaceCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onFavoriteTap,
    this.showFavorite = true,
  });

  final MarketplaceListing listing;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(GarraColors.garnet).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(GarraRadius.sm),
              border: Border.all(color: const Color(GarraColors.borderSubtle)),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: Color(GarraColors.gold),
            ),
          ),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (listing.store != null) ...[
                  const SizedBox(height: GarraSpacing.xs),
                  Text(
                    listing.store!.name,
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
                      listing.priceLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(GarraColors.gold),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (listing.category != null &&
                        listing.category!.isNotEmpty)
                      _Pill(label: listing.category!),
                  ],
                ),
              ],
            ),
          ),
          if (showFavorite && onFavoriteTap != null) ...[
            const SizedBox(width: GarraSpacing.sm),
            IconButton(
              tooltip: listing.isFavorite
                  ? 'Quitar de favoritos'
                  : 'Agregar a favoritos',
              onPressed: onFavoriteTap,
              icon: Icon(
                listing.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: listing.isFavorite
                    ? const Color(GarraColors.garnet)
                    : const Color(GarraColors.gold),
              ),
            ),
          ] else if (onTap != null)
            const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GarraSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: const Color(GarraColors.surfaceRaised),
        borderRadius: BorderRadius.circular(GarraRadius.pill),
        border: Border.all(color: const Color(GarraColors.borderSubtle)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(GarraColors.textSecondary),
            ),
      ),
    );
  }
}
