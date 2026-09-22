import 'package:flutter/material.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../data/reaction_type.dart';

/// Compact engagement strip: top non-zero reactions + comment count.
/// Layout-safe on narrow screens (no horizontal RenderFlex overflow).
class GarraReactionBar extends StatelessWidget {
  const GarraReactionBar({
    super.key,
    required this.reactionSummary,
    required this.reactionCount,
    required this.commentCount,
    this.myReaction,
    this.onTapReactions,
    this.onTapComments,
    this.compact = true,
  });

  final Map<String, int> reactionSummary;
  final int reactionCount;
  final int commentCount;
  final String? myReaction;
  final VoidCallback? onTapReactions;
  final VoidCallback? onTapComments;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final top = topNonZeroReactions(reactionSummary, limit: 3);
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(GarraColors.textSecondary),
          fontWeight: FontWeight.w700,
        );

    final commentLabel = commentCount == 0
        ? 'Comentar'
        : commentCount == 1
            ? '1'
            : '$commentCount';

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? GarraSpacing.xs : GarraSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTapReactions,
              borderRadius: BorderRadius.circular(GarraRadius.sm),
              child: Row(
                children: [
                  Flexible(
                    child: top.isEmpty
                        ? Text(
                            reactionCount > 0
                                ? '$reactionCount reacciones'
                                : 'Reaccionar',
                            style: textStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Row(
                            children: [
                              ...top.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(
                                    right: GarraSpacing.sm,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        ReactionType.emojiFor(entry.key),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 3),
                                      Text('${entry.value}', style: textStyle),
                                    ],
                                  ),
                                ),
                              ),
                              if (reactionCount > 0)
                                Flexible(
                                  child: Text(
                                    '· $reactionCount',
                                    style: textStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (myReaction != null) ...[
                    const SizedBox(width: GarraSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(GarraColors.garnet)
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(GarraRadius.pill),
                      ),
                      child: Text(
                        ReactionType.emojiFor(myReaction!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onTapComments,
            borderRadius: BorderRadius.circular(GarraRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: Color(GarraColors.gold),
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: Text(
                      commentLabel,
                      style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
