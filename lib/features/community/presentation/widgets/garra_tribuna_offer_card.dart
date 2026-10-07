import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_cached_network_image.dart';
import '../../../../core/widgets/garra_card.dart';
import '../../../locations/data/crema_business_offer_models.dart';

/// DEMO_HARDENING_02A.1: where the offer card is shown. Drives which CTAs make
/// sense so the card never links to the surface the user is already on.
enum GarraOfferCardContext {
  /// Tribuna / Home feed: "Ver oferta" + "Ver negocio".
  feed,

  /// Public business page: the card already is the offer presentation, so it
  /// shows the full benefit and no navigation CTAs (no loops back to itself).
  business,
}

/// Public business page focused on one offer. `cremaPointId` is the CremaPoint
/// id used by `/negocios/:id` (never an applicationId); `oferta` is the
/// CremaBusinessOffer id the page scrolls to.
String garraOfferDestination(CremaBusinessOffer offer) {
  final point = Uri.encodeComponent(offer.cremaPointId);
  final id = Uri.encodeQueryComponent(offer.id);
  return '/negocios/$point?oferta=$id';
}

/// Public business page (no offer focus).
String garraOfferBusinessDestination(CremaBusinessOffer offer) =>
    '/negocios/${Uri.encodeComponent(offer.cremaPointId)}';

/// DEMO_HARDENING_02A: commercial Tribuna card. Label is OFERTA (never "Promocionado").
class GarraTribunaOfferCard extends StatelessWidget {
  const GarraTribunaOfferCard({
    super.key,
    required this.offer,
    this.cardContext = GarraOfferCardContext.feed,
  });

  final CremaBusinessOffer offer;
  final GarraOfferCardContext cardContext;

  String _vigenciaLabel() {
    final start = offer.startsAt?.toLocal();
    final end = offer.endsAt?.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime d) =>
        '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
    if (start == null && end == null) return 'Vigencia abierta';
    if (start != null && end != null) {
      return 'Vigencia: ${fmt(start)} \u2014 ${fmt(end)}';
    }
    if (start != null) return 'Desde ${fmt(start)}';
    return 'Hasta ${fmt(end!)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final negocio = (offer.cremaPointName ?? '').trim();
    final header = negocio.isEmpty ? 'OFERTA' : 'OFERTA \u00b7 $negocio';
    final image = (offer.imageUrl ?? '').trim();
    final inFeed = cardContext == GarraOfferCardContext.feed;
    final canNavigate = inFeed && offer.cremaPointId.isNotEmpty;

    return Padding(
      padding: inFeed
          ? const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              0,
              GarraSpacing.lg,
              GarraSpacing.md,
            )
          : const EdgeInsets.only(bottom: GarraSpacing.md),
      child: GarraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_offer_outlined,
                    size: 16, color: colors.brandPrestige),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    header,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.brandPrestige,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                  ),
                ),
              ],
            ),
            if (image.isNotEmpty) ...[
              const SizedBox(height: GarraSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: GarraCachedNetworkImage(
                      imageUrl: image, fit: BoxFit.cover),
                ),
              ),
            ],
            const SizedBox(height: GarraSpacing.sm),
            Text(
              offer.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (offer.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                offer.description,
                // Business page is the offer presentation: full benefit text.
                maxLines: inFeed ? 4 : null,
                overflow: inFeed ? TextOverflow.ellipsis : null,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 6),
            Text(
              _vigenciaLabel(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.brandPrestige,
                  ),
            ),
            if (canNavigate) ...[
              const SizedBox(height: GarraSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton(
                    key: ValueKey('tribuna_offer_cta_${offer.id}'),
                    onPressed: () =>
                        context.push(garraOfferDestination(offer)),
                    child: const Text('Ver oferta'),
                  ),
                  OutlinedButton(
                    key: ValueKey('tribuna_offer_negocio_${offer.id}'),
                    onPressed: () =>
                        context.push(garraOfferBusinessDestination(offer)),
                    child: const Text('Ver negocio'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}