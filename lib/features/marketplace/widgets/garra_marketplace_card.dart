import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../data/marketplace_models.dart';

enum GarraMarketplaceCardLayout { list, compactGrid }

/// Listing card for Marketplace Crema — cream/garnet identity, not a ML clone.
class GarraMarketplaceCard extends StatelessWidget {
  const GarraMarketplaceCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onFavoriteTap,
    this.showFavorite = true,
    this.onVisible,
    this.layout = GarraMarketplaceCardLayout.list,
  });

  final MarketplaceListing listing;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final bool showFavorite;

  /// Fired once when featured card is built (caller dedupes).
  final VoidCallback? onVisible;
  final GarraMarketplaceCardLayout layout;

  @override
  Widget build(BuildContext context) {
    if (listing.featured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onVisible?.call();
      });
    }

    final cover = listing.coverImageUrl;

    if (layout == GarraMarketplaceCardLayout.compactGrid) {
      return _CompactMarketplaceCard(
        listing: listing,
        cover: cover,
        onTap: onTap,
        showFavorite: showFavorite,
        onFavoriteTap: onFavoriteTap,
      );
    }

    return GarraCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(GarraRadius.sm),
            child: SizedBox(
              width: 72,
              height: 72,
              child: cover != null && cover.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const _FallbackThumb(),
                      errorWidget: (_, _, _) => const _FallbackThumb(),
                    )
                  : const _FallbackThumb(),
            ),
          ),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (listing.featured) ...[
                  const _DestacadoBadge(),
                  const SizedBox(height: GarraSpacing.xs),
                ],
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
              onPressed: () {
                HapticFeedback.lightImpact();
                onFavoriteTap?.call();
              },
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

class _CompactMarketplaceCard extends StatelessWidget {
  const _CompactMarketplaceCard({
    required this.listing,
    required this.cover,
    required this.onTap,
    required this.showFavorite,
    required this.onFavoriteTap,
  });

  final MarketplaceListing listing;
  final String? cover;
  final VoidCallback? onTap;
  final bool showFavorite;
  final VoidCallback? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 132,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                cover != null && cover!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: cover!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const _FallbackThumb(),
                        errorWidget: (_, _, _) => const _FallbackThumb(),
                      )
                    : const _FallbackThumb(),
                if (showFavorite && onFavoriteTap != null)
                  Positioned(
                    top: GarraSpacing.xs,
                    right: GarraSpacing.xs,
                    child: Material(
                      color: const Color(
                        GarraColors.charcoal,
                      ).withValues(alpha: 0.82),
                      shape: const CircleBorder(),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: listing.isFavorite
                            ? 'Quitar de favoritos'
                            : 'Agregar a favoritos',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onFavoriteTap?.call();
                        },
                        icon: Icon(
                          listing.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 20,
                          color: listing.isFavorite
                              ? const Color(GarraColors.garnet)
                              : const Color(GarraColors.gold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(GarraSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if (listing.store != null) ...[
                    const SizedBox(height: GarraSpacing.xs),
                    Text(
                      listing.store!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    listing.priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(GarraColors.gold),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(GarraColors.garnet).withValues(alpha: 0.22),
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_outlined,
        color: Color(GarraColors.gold),
      ),
    );
  }
}

class _DestacadoBadge extends StatelessWidget {
  const _DestacadoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(GarraColors.gold).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(GarraRadius.pill),
        border: Border.all(
          color: const Color(GarraColors.gold).withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        'Destacado',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(GarraColors.gold),
          fontWeight: FontWeight.w700,
        ),
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
