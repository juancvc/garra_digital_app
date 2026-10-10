import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../football/data/garra_football_models.dart';
import 'home_featured_match_card.dart';
import 'home_matchday_poll_card.dart';

const _gold = Color(0xFFC7A45B);

/// Pinned featured fixture + optional Matchday poll in one compact surface above the feed.
class HomeFeedFeaturedBlock extends ConsumerWidget {
  const HomeFeedFeaturedBlock({super.key, required this.featured});

  final AsyncValue<FootballFeaturedResult> featured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withValues(alpha: 0.38)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1218), Color(0xFF140D10)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HomeFeaturedMatchCard(result: featured, embedded: true),
            HomeMatchdayPollCard(featured: featured, embedded: true),
          ],
        ),
      ),
    );
  }
}
