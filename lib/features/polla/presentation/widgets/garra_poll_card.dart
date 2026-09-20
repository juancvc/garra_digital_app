import 'package:flutter/material.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/design/garra_typography.dart';
import '../../../../core/widgets/garra_card.dart';
import '../../data/matchday_poll_models.dart';

/// Reusable matchday poll card with options, percentages and vote CTA.
class GarraPollCard extends StatelessWidget {
  const GarraPollCard({
    super.key,
    required this.question,
    required this.options,
    required this.isOpen,
    this.myVoteOptionId,
    this.totalVotes = 0,
    this.submitting = false,
    this.onVote,
  });

  final String question;
  final List<MatchPollOptionResult> options;
  final bool isOpen;
  final String? myVoteOptionId;
  final int totalVotes;
  final bool submitting;
  final ValueChanged<String>? onVote;

  factory GarraPollCard.fromPoll({
    Key? key,
    required MatchPoll poll,
    MatchPollResults? results,
    bool submitting = false,
    ValueChanged<String>? onVote,
  }) {
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

    return GarraPollCard(
      key: key,
      question: poll.question,
      options: options,
      isOpen: poll.isOpen,
      myVoteOptionId: results?.myVoteOptionId,
      totalVotes: results?.totalVotes ?? poll.voteCount,
      submitting: submitting,
      onVote: onVote,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: GarraSpacing.xs),
          Text(
            isOpen
                ? (myVoteOptionId == null
                    ? 'Elige una opción'
                    : 'Puedes cambiar tu voto')
                : 'Encuesta cerrada',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (totalVotes > 0) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              '$totalVotes ${totalVotes == 1 ? 'voto' : 'votos'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
          const SizedBox(height: GarraSpacing.md),
          ...options.map((option) {
            final selected = option.optionId == myVoteOptionId;
            return Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
              child: _PollOptionRow(
                option: option,
                selected: selected,
                enabled: isOpen && !submitting,
                onTap: isOpen && onVote != null
                    ? () => onVote!(option.optionId)
                    : null,
              ),
            );
          }),
          if (!isOpen && options.isEmpty)
            const Text(
              'Sin opciones disponibles.',
              style: TextStyle(color: Color(GarraColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  const _PollOptionRow({
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(GarraColors.cream),
                          ),
                    ),
                  ),
                  Text(
                    '${option.percentage}%',
                    style: GarraTypography.numeric(size: 16),
                  ),
                  if (selected) ...[
                    const SizedBox(width: GarraSpacing.sm),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(GarraColors.gold),
                      size: 18,
                    ),
                  ],
                ],
              ),
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
              const SizedBox(height: GarraSpacing.xs),
              Text(
                '${option.voteCount} ${option.voteCount == 1 ? 'voto' : 'votos'}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact helper when a poll has no candidates yet.
class GarraPollEmptyState extends StatelessWidget {
  const GarraPollEmptyState({
    super.key,
    this.title = 'Sin encuestas abiertas',
    this.message = 'Cuando haya encuestas del partido, aparecerán aquí.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: GarraSpacing.sm),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Closed poll banner.
class GarraPollClosedBanner extends StatelessWidget {
  const GarraPollClosedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: Color(GarraColors.warning)),
          const SizedBox(width: GarraSpacing.md),
          Expanded(
            child: Text(
              'Esta encuesta ya cerró. Puedes ver los resultados.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
