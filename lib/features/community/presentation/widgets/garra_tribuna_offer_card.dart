import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_cached_network_image.dart';
import '../../../../core/widgets/garra_card.dart';
import '../../../locations/data/crema_business_offer_models.dart';

/// DEMO_HARDENING_02A: commercial Tribuna card. Label is OFERTA (never "Promocionado").
class GarraTribunaOfferCard extends StatelessWidget {
  const GarraTribunaOfferCard({
    super.key,
    required this.offer,
    this.compact = false,
  });

  final CremaBusinessOffer offer;
  final bool compact;

  String _vigenciaLabel() {
    final start = offer.startsAt?.toLocal();
    final end = offer.endsAt?.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime d) =>
        '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
    if (start == null && end == null) return 'Vigencia abierta';
    if (start != null && end != null) {
      return 'Vigencia: ${fmt(start)} – ${fmt(end)}';
    }
    if (start != null) return 'Desde ${fmt(start)}';
    return 'Hasta ${fmt(end!)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final negocio = (offer.cremaPointName ?? '').trim();
    final header = negocio.isEmpty ? 'OFERTA' : 'OFERTA · $negocio';
    final image = (offer.imageUrl ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        0,
        GarraSpacing.lg,
        GarraSpacing.md,
      ),
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
                maxLines: compact ? 2 : 4,
                overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: GarraSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton(
                  key: ValueKey('tribuna_offer_cta_${offer.id}'),
                  onPressed: () => context.push('/negocios/ofertas'),
                  child: const Text('Ver oferta'),
                ),
                if (offer.cremaPointId.isNotEmpty)
                  OutlinedButton(
                    key: ValueKey('tribuna_offer_negocio_${offer.id}'),
                    onPressed: () =>
                        context.push('/negocios/${offer.cremaPointId}'),
                    child: const Text('Ver negocio'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}