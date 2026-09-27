import 'package:flutter/material.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../data/reaction_type.dart';
import 'garra_comment_reactions.dart';
import 'garra_reaction_burst.dart';

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
    this.onLongPressReactions,
    this.onTapComments,
    this.compact = true,
  });

  final Map<String, int> reactionSummary;
  final int reactionCount;
  final int commentCount;
  final String? myReaction;
  final VoidCallback? onTapReactions;

  /// Long-press: change the current reaction (opens the picker).
  final VoidCallback? onLongPressReactions;
  final VoidCallback? onTapComments;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final top = topNonZeroReactions(reactionSummary, limit: 3);
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.garraColors.textSecondary,
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
              key: const ValueKey('post_reaction_summary'),
              onTap: onTapReactions == null
                  ? null
                  : () {
                      GarraReactionAnchor.remember(context);
                      onTapReactions!();
                    },
              onLongPress: onLongPressReactions == null
                  ? null
                  : () {
                      GarraReactionAnchor.remember(context);
                      onLongPressReactions!();
                    },
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
                                      GarraReactionGlyph(
                                        apiValue: entry.key,
                                        size: 15,
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
                      child: GarraReactionGlyph(
                        key: const ValueKey('post_my_reaction'),
                        apiValue: myReaction!,
                        size: 13,
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
