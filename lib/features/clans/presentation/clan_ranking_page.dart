import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/clan_models.dart';
import 'providers/clans_provider.dart';

class ClanRankingPage extends ConsumerWidget {
  const ClanRankingPage({super.key, this.year});

  final int? year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingYear = year ?? DateTime.now().year;
    final rankingAsync = ref.watch(globalClanRankingProvider(rankingYear));

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Ranking de Clanes')),
      body: rankingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (_, __) => GarraErrorState(
          onRetry: () =>
              ref.invalidate(globalClanRankingProvider(rankingYear)),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(GarraSpacing.xl),
                child: GarraEmptyState(
                  title: 'Ranking vacío',
                  message:
                      'Cuando los clanes sumen Puntos Polla, aparecerán aquí.',
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(GarraColors.gold),
            onRefresh: () async {
              ref.invalidate(globalClanRankingProvider(rankingYear));
              await ref.read(globalClanRankingProvider(rankingYear).future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.lg,
                GarraSpacing.md,
                GarraSpacing.lg,
                GarraSpacing.section,
              ),
              itemCount: entries.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: GarraSpacing.lg),
                    child: GarraSectionHeader(
                      title: 'Puntos Polla',
                      subtitle: 'Temporada $rankingYear',
                    ),
                  );
                }
                final entry = entries[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
                  child: _RankingTile(entry: entry),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.entry});

  final ClanGlobalRankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final points = NumberFormat.decimalPattern('es').format(entry.totalPoints);
    final highlight = entry.isPrimary;

    return Container(
      decoration: highlight
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(GarraRadius.md),
              border: Border.all(
                color: const Color(GarraColors.gold),
                width: 1.5,
              ),
            )
          : null,
      child: GarraCard(
        onTap: entry.slug.isEmpty
            ? null
            : () => context.push('/clans/${entry.slug}'),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '#${entry.rank}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(GarraColors.gold),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            GarraAvatar(
              displayName: entry.name,
              avatarUrl: entry.logoUrl,
              size: 44,
            ),
            const SizedBox(width: GarraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (highlight) ...[
                        const SizedBox(width: GarraSpacing.sm),
                        Text(
                          'Tu clan',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: const Color(GarraColors.gold),
                                  ),
                        ),
                      ],
                    ],
                  ),
                  if (entry.memberCount != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${NumberFormat.decimalPattern('es').format(entry.memberCount)} miembros',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  points,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(GarraColors.gold),
                      ),
                ),
                Text(
                  'Puntos Polla',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
