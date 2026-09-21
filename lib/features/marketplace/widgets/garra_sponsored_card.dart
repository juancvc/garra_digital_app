import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../sponsors/data/sponsor_service.dart';
import '../../marketplace/data/marketplace_url_launcher.dart';

/// Secondary sponsored Matchday card — never a hero replacement.
class GarraSponsoredCard extends StatefulWidget {
  const GarraSponsoredCard({
    super.key,
    required this.card,
    this.onImpression,
    this.onOpen,
    this.urlLauncher,
  });

  final SponsoredCard card;
  final VoidCallback? onImpression;
  final VoidCallback? onOpen;
  final MarketplaceUrlLauncher? urlLauncher;

  @override
  State<GarraSponsoredCard> createState() => _GarraSponsoredCardState();
}

class _GarraSponsoredCardState extends State<GarraSponsoredCard> {
  bool _impressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _impressed) return;
      _impressed = true;
      widget.onImpression?.call();
    });
  }

  Future<void> _openCta(BuildContext context) async {
    final url = widget.card.ctaUrl;
    if (!isSafeHttpsUrl(url)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos abrir el enlace.')),
        );
      }
      return;
    }
    widget.onOpen?.call();
    final launcher = widget.urlLauncher ?? marketplaceUrlLauncher;
    final ok = await launcher(Uri.parse(url!.trim()));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir el enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (card.logoUrl != null && card.logoUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(GarraRadius.sm),
                  child: CachedNetworkImage(
                    imageUrl: card.logoUrl!,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.storefront, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: GarraSpacing.sm),
              ],
              Expanded(
                child: Text(
                  card.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(GarraColors.gold),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: GarraSpacing.md),
          Text(
            card.headline,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (card.body != null && card.body!.trim().isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              card.body!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (card.ctaLabel != null &&
              card.ctaLabel!.trim().isNotEmpty &&
              isSafeHttpsUrl(card.ctaUrl)) ...[
            const SizedBox(height: GarraSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _openCta(context),
                child: Text(card.ctaLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
