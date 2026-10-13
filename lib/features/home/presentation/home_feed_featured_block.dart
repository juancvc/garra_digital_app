import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../football/data/garra_football_models.dart';
import 'home_featured_match_card.dart';
import 'home_matchday_poll_card.dart';
import 'providers/home_provider.dart';

const _gold = Color(0xFFC7A45B);
const _cream = Color(0xFFF3E9D2);

/// A single editorial slot above the feed. Its child providers own their
/// existing requests; this widget never fetches during build or scrolling.
class HomeFeedFeaturedBlock extends ConsumerWidget {
  const HomeFeedFeaturedBlock({super.key, required this.featured});

  final AsyncValue<FootballFeaturedResult> featured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = featured.asData?.value;
    final match = result?.featured?.live ?? result?.featured?.next ?? result?.featured?.last;
    final hasReliableMatch = result?.unavailable != true &&
        match != null && !match.isUnconfirmed && match.status != 'UNKNOWN';

    // PRODUCT-10A.2D: compact slot (match + poll) with no decorative photo
    // and no shortcut tiles; the Tribuna feed starts right below it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: _gold.withValues(alpha: 0.48)),
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1019), Color(0xFF170C12)],
          ),
        ),
        child: hasReliableMatch
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HomeFeaturedMatchCard(result: featured, embedded: true),
                  HomeMatchdayPollCard(featured: featured, embedded: true),
                ],
              )
            : _TribunaAlive(featured: featured),
      ),
    );
  }
}

class _TribunaAlive extends ConsumerWidget {
  const _TribunaAlive({required this.featured});
  final AsyncValue<FootballFeaturedResult> featured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = featured.isLoading && !featured.hasValue;
    final failed = featured.hasError && !featured.hasValue;
    return Padding(
      key: const ValueKey('home_tribuna_alive'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LA TRIBUNA VIVE', style: TextStyle(
            color: _gold, fontSize: 10, fontWeight: FontWeight.w900,
            letterSpacing: 1.5)),
          const SizedBox(height: 4),
          const Text('La pasión también se cuenta.', style: TextStyle(
            color: _cream, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
            loading ? 'Buscando el próximo partido destacado…'
                : 'Mientras llega el próximo partido, vive las historias de la hinchada.',
            style: const TextStyle(color: Color(0xFFD3C5B0), fontSize: 12),
          ),
          if (failed)
            TextButton(
              onPressed: () => ref.invalidate(homeFeaturedProvider),
              child: const Text('Reintentar partido'),
            ),
        ],
      ),
    );
  }
}
