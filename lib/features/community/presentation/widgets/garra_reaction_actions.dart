import 'package:flutter/material.dart';

import '../../data/reaction_type.dart';
import 'garra_comment_reactions.dart';
import 'garra_reaction_burst.dart';
import 'garra_reaction_picker.dart';

/// What a reaction tap resolved to: remove the current reaction, or select
/// [type] (add or change).
class ReactionIntent {
  const ReactionIntent.remove() : type = null;
  const ReactionIntent.select(ReactionType this.type);

  final ReactionType? type;

  bool get isRemove => type == null;
  String? get apiValue => type?.apiValue;
}

/// UX_08 reaction toggle, shared by posts, comments and replies:
/// - with an active reaction, a tap removes it directly (no picker);
/// - without one (or with [forcePicker], i.e. long-press "cambiar"), the
///   picker opens; choosing the active option again also removes it.
/// Explicitly selecting GARRA plays the GARRA micro-animation (never on
/// load, refresh, removal or server state changes).
Future<ReactionIntent?> resolveReactionTap(
  BuildContext context, {
  required String? current,
  bool forcePicker = false,
  bool comment = false,
}) async {
  final active = ReactionType.tryParse(current);
  if (active != null && !forcePicker) return const ReactionIntent.remove();

  final selected = comment
      ? await showCommentReactionPicker(context, currentReaction: current)
      : await showGarraReactionPicker(context, currentReaction: current);
  if (selected == null) return null;
  if (active == selected) return const ReactionIntent.remove();
  if (selected == ReactionType.garra && context.mounted) {
    showGarraReactionBurst(context);
  }
  return ReactionIntent.select(selected);
}

/// Spanish rollback message for a failed reaction request.
String reactionErrorMessage(ReactionIntent intent) => intent.isRemove
    ? 'No se pudo quitar la reacci\u00f3n. Int\u00e9ntalo de nuevo.'
    : 'No se pudo actualizar la reacci\u00f3n. Int\u00e9ntalo de nuevo.';