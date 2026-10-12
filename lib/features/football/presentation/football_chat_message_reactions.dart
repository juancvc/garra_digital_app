import 'package:flutter/material.dart';

import '../../chat/data/chat_models.dart';
import '../../chat/presentation/chat_message_reactions.dart';
import '../../community/data/reaction_type.dart';

/// Football Chat: same chip visuals as private chat, with per-type tap to toggle.
class FootballChatTappableReactionChips extends StatelessWidget {
  const FootballChatTappableReactionChips({
    super.key,
    required this.messageId,
    required this.reactions,
    required this.onReactionTap,
  });

  final String messageId;
  final List<ChatMessageReactionSummary> reactions;
  final ValueChanged<ReactionType> onReactionTap;

  @override
  Widget build(BuildContext context) {
    final visible = sortedChatReactions(reactions);
    if (visible.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final r in visible)
          if (r.reactionType != null)
            GestureDetector(
              key: Key('football-chat-reaction-tap-$messageId-${r.type}'),
              onTap: () => onReactionTap(r.reactionType!),
              child: ChatMessageReactionChips(
                messageId: '${messageId}_${r.type}',
                reactions: [r],
              ),
            ),
      ],
    );
  }
}
