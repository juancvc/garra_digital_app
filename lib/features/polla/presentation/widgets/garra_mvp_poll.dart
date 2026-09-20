import 'package:flutter/material.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/design/garra_typography.dart';
import '../../../../core/widgets/garra_card.dart';
import '../../data/matchday_poll_models.dart';
import 'garra_poll_card.dart';

/// MVP voting presentation over the unified MatchPoll model.
class GarraMvpPoll extends StatelessWidget {
  const GarraMvpPoll({
    super.key,
    required this.poll,
    this.results,
    this.submitting = false,
    this.onVote,
  });

  final MatchPoll poll;
  final MatchPollResults? results;
  final bool submitting;
  final ValueChanged<String>? onVote;

  @override
  Widget build(BuildContext context) {
    final options = results?.options ??
        poll.options
            .map(
              (o) => MatchPollOptionResult(
                optionId: o.id,
                displayName: o.displayName,
                shirtNumber: o.shirtNumber,
                imageUrl: o.imageUrl,
                sortOrder: o.sortOrder,
                voteCount: o.voteCount,
                percentage: 0,
              ),
            )
            .toList();

    if (options.isEmpty) {
      return const GarraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MVP del partido',
              style: TextStyle(
                color: Color(GarraColors.cream),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            SizedBox(height: GarraSpacing.sm),
            Text(
              'Aún no hay candidatos para votar.',
              style: TextStyle(color: Color(GarraColors.textSecondary)),
            ),
          ],
        ),
      );
    }

    final myVote = results?.myVoteOptionId;
    final total = results?.totalVotes ?? poll.voteCount;

    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question.isEmpty ? 'Vota por el MVP' : poll.question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GarraSpacing.xs),
          Text(
            poll.isOpen
                ? 'Elige al jugador del partido'
                : 'Votación de MVP cerrada',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (total > 0) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              '$total ${total == 1 ? 'voto' : 'votos'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
          const SizedBox(height: GarraSpacing.md),
          ...options.map((option) {
            final selected = option.optionId == myVote;
            return Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
              child: _MvpCandidateTile(
                option: option,
                selected: selected,
                enabled: poll.isOpen && !submitting,
                onTap: poll.isOpen && onVote != null
                    ? () => onVote!(option.optionId)
                    : null,
              ),
            );
          }),
          if (!poll.isOpen) ...[
            const SizedBox(height: GarraSpacing.sm),
            const GarraPollClosedBanner(),
          ],
        ],
      ),
    );
  }
}

class _MvpCandidateTile extends StatelessWidget {
  const _MvpCandidateTile({
    required this.option,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final MatchPollOptionResult option;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pct = (option.percentage / 100).clamp(0.0, 1.0);
    final trimmed = option.displayName.trim();
    final initials = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(GarraRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(GarraSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? const Color(GarraColors.garnetDeep)
                : const Color(GarraColors.surfaceRaised),
            borderRadius: BorderRadius.circular(GarraRadius.md),
            border: Border.all(
              color: selected
                  ? const Color(GarraColors.gold)
                  : const Color(GarraColors.borderSubtle),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(GarraColors.garnet),
                backgroundImage: option.imageUrl != null &&
                        option.imageUrl!.isNotEmpty
                    ? NetworkImage(option.imageUrl!)
                    : null,
                child: option.imageUrl == null || option.imageUrl!.isEmpty
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: Color(GarraColors.cream),
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(GarraColors.cream),
                          ),
                    ),
                    if (option.shirtNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'N° ${option.shirtNumber}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                    const SizedBox(height: GarraSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(GarraRadius.pill),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: pct),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 8,
                            backgroundColor: const Color(GarraColors.charcoal),
                            color: const Color(GarraColors.gold),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GarraSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${option.percentage}%',
                    style: GarraTypography.numeric(size: 18),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(GarraColors.gold),
                      size: 18,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
