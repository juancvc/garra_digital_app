import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/garra_avatar.dart';
import '../../../../core/widgets/garra_sheet.dart';
import '../../data/reaction_type.dart';
import '../../data/wall_comment_model.dart';
import 'garra_comment_reactions.dart';
import 'garra_reaction_burst.dart';
import 'garra_reactors_sheet.dart';

/// Max length accepted by the backend when editing a comment.
const commentEditMaxLength = 500;

enum _CommentMenuAction { edit, delete, moderate }

/// Comment row for post detail: author, text, "Editado" marker, own-comment
/// menu (Editar / Eliminar) and a light reaction strip.
class GarraCommentTile extends StatelessWidget {
  const GarraCommentTile({
    super.key,
    required this.comment,
    this.isOwn = false,
    this.onEdit,
    this.onDelete,
    this.onReact,
    this.onChangeReaction,
    this.onReply,
    this.onModerate,
    this.reacting = false,
  });

  final WallCommentModel comment;
  final bool isOwn;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReact;

  /// Long-press on the reaction pill: change the current reaction.
  final VoidCallback? onChangeReaction;

  /// "Responder" action (roots and replies). Hidden when null.
  final VoidCallback? onReply;

  /// Clan moderation ("Ocultar comentario"). Only passed by clan-post
  /// contexts where the viewer is OWNER/ADMIN/MODERATOR of that clan.
  final VoidCallback? onModerate;
  final bool reacting;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final textTheme = Theme.of(context).textTheme;
    final name = comment.fullName.isNotEmpty
        ? comment.fullName
        : comment.username;
    final metaStyle = textTheme.labelSmall?.copyWith(
      color: colors.textSecondary,
    );
    final openProfile = comment.authorId == null
        ? null
        : () => context.push('/comunidad/u/${comment.authorId}');
    final showOwnActions = isOwn && (onEdit != null || onDelete != null);
    final showMenu = showOwnActions || onModerate != null;

    return Padding(
      key: ValueKey('comment_tile_${comment.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: openProfile,
            child: GarraAvatar(
              displayName: name,
              avatarUrl: comment.avatarUrl,
              size: comment.isReply ? 22 : 28,
            ),
          ),
          const SizedBox(width: GarraSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: openProfile,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        formatGarraRelativeTime(comment.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                    ),
                    if (comment.isEdited) ...[
                      Text(' · ', style: metaStyle),
                      Text(
                        'Editado',
                        key: ValueKey('comment_edited_${comment.id}'),
                        style: metaStyle?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (comment.replyToUsername != null)
                  Text.rich(
                    key: ValueKey('comment_reply_to_${comment.id}'),
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '@${comment.replyToUsername} ',
                          style: TextStyle(
                            color: colors.brandPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: comment.content),
                      ],
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  )
                else
                  Text(
                    comment.content,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: _CommentReactButton(
                              commentId: comment.id,
                              myReaction: comment.myReaction,
                              onPressed: reacting ? null : onReact,
                              onLongPress: reacting ? null : onChangeReaction,
                            ),
                          ),
                          if (onReply != null)
                            InkWell(
                              key: ValueKey('comment_reply_${comment.id}'),
                              onTap: onReply,
                              borderRadius: BorderRadius.circular(
                                GarraRadius.pill,
                              ),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 32,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Responder',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: GarraSpacing.sm),
                    InkWell(
                      key: ValueKey('comment_reactors_${comment.id}'),
                      onTap: comment.reactionCount > 0
                          ? () => showGarraReactorsSheet(
                              context,
                              commentId: comment.id,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(GarraRadius.sm),
                      child: GarraCommentReactionSummary(
                        key: ValueKey('comment_reaction_summary_${comment.id}'),
                        reactionSummary: comment.reactionSummary,
                        reactionCount: comment.reactionCount,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showMenu)
            SizedBox(
              width: 36,
              height: 36,
              child: PopupMenuButton<_CommentMenuAction>(
                key: ValueKey('comment_menu_${comment.id}'),
                tooltip: 'Opciones del comentario',
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: colors.textSecondary,
                ),
                color: colors.surfaceRaised,
                onSelected: (action) {
                  switch (action) {
                    case _CommentMenuAction.edit:
                      onEdit?.call();
                    case _CommentMenuAction.delete:
                      onDelete?.call();
                    case _CommentMenuAction.moderate:
                      onModerate?.call();
                  }
                },
                itemBuilder: (_) => [
                  if (showOwnActions && onEdit != null)
                    PopupMenuItem(
                      value: _CommentMenuAction.edit,
                      child: Text(
                        'Editar',
                        style: TextStyle(color: colors.textPrimary),
                      ),
                    ),
                  if (showOwnActions && onDelete != null)
                    PopupMenuItem(
                      value: _CommentMenuAction.delete,
                      child: Text(
                        'Eliminar',
                        style: TextStyle(color: colors.danger),
                      ),
                    ),
                  if (onModerate != null)
                    PopupMenuItem(
                      value: _CommentMenuAction.moderate,
                      child: Text(
                        'Ocultar comentario',
                        style: TextStyle(color: colors.danger),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentReactButton extends StatelessWidget {
  const _CommentReactButton({
    required this.commentId,
    required this.myReaction,
    required this.onPressed,
    this.onLongPress,
  });

  final String commentId;
  final String? myReaction;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final selected = isCommentReactionType(myReaction)
        ? ReactionType.tryParse(myReaction)
        : null;
    final accent = selected == null
        ? colors.textSecondary
        : commentReactionTint(context, selected);
    final label = selected == null
        ? 'Reaccionar'
        : commentReactionLabel(selected);

    return Semantics(
      button: true,
      selected: selected != null,
      label: selected == null ? 'Reaccionar' : 'Tu reacción: $label',
      hint: selected == null
          ? null
          : 'Toca para quitarla. Mant\u00e9n presionado para cambiarla.',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('comment_react_$commentId'),
          onTap: onPressed == null
              ? null
              : () {
                  GarraReactionAnchor.remember(context);
                  onPressed!();
                },
          onLongPress: onLongPress == null
              ? null
              : () {
                  GarraReactionAnchor.remember(context);
                  onLongPress!();
                },
          borderRadius: BorderRadius.circular(GarraRadius.pill),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: EdgeInsets.symmetric(
              horizontal: selected == null ? 4 : 10,
              vertical: 4,
            ),
            decoration: selected == null
                ? null
                : BoxDecoration(
                    color: commentReactionAccent(
                      context,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(GarraRadius.pill),
                    border: Border.all(color: accent.withValues(alpha: 0.7)),
                  ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected == null)
                  Icon(
                    Icons.add_reaction_outlined,
                    size: 16,
                    color: colors.textSecondary,
                  )
                else
                  CommentReactionIcon(type: selected, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected == null
                          ? colors.textSecondary
                          : colors.textPrimary,
                      fontWeight: selected == null
                          ? FontWeight.w700
                          : FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the compact editor. [onSubmit] returns an error message to show
/// inside the sheet, or null on success (the sheet then closes).
Future<bool?> showEditCommentSheet(
  BuildContext context, {
  required String initialText,
  required Future<String?> Function(String content) onSubmit,
}) {
  return showGarraSheet<bool>(
    context: context,
    builder: (_) =>
        GarraEditCommentSheet(initialText: initialText, onSubmit: onSubmit),
  );
}

class GarraEditCommentSheet extends StatefulWidget {
  const GarraEditCommentSheet({
    super.key,
    required this.initialText,
    required this.onSubmit,
  });

  final String initialText;
  final Future<String?> Function(String content) onSubmit;

  @override
  State<GarraEditCommentSheet> createState() => _GarraEditCommentSheetState();
}

class _GarraEditCommentSheetState extends State<GarraEditCommentSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _trimmed => _controller.text.trim();

  Future<void> _save() async {
    if (_saving) return;
    final content = _trimmed;
    if (content.isEmpty) {
      setState(() => _error = 'El comentario no puede estar vacío.');
      return;
    }
    if (content.length > commentEditMaxLength) {
      setState(
        () =>
            _error = 'Máximo $commentEditMaxLength caracteres por comentario.',
      );
      return;
    }
    if (content == widget.initialText.trim()) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit(content);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final empty = _trimmed.isEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.md,
          GarraSpacing.lg,
          GarraSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Editar comentario',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: GarraSpacing.md),
            TextField(
              key: const ValueKey('comment_edit_field'),
              controller: _controller,
              enabled: !_saving,
              autofocus: true,
              maxLength: commentEditMaxLength,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: colors.textPrimary),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: 'Escribe tu comentario',
                errorText: empty
                    ? 'El comentario no puede estar vacío.'
                    : _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: GarraSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const ValueKey('comment_edit_cancel'),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: GarraSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('comment_edit_save'),
                    onPressed: _saving || empty ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.brandPrimary,
                      foregroundColor: colors.onBrand,
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onBrand,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation before a clan moderator hides someone's comment.
Future<bool> confirmHideComment(BuildContext context) async {
  final colors = context.garraColors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        '\u00bfOcultar este comentario?',
        style: TextStyle(color: colors.textPrimary),
      ),
      content: Text(
        'Dejar\u00e1 de verse en la publicaci\u00f3n. Si tiene respuestas, tambi\u00e9n se ocultar\u00e1n.',
        style: TextStyle(color: colors.textSecondary),
      ),
      actions: [
        TextButton(
          key: const ValueKey('comment_hide_cancel'),
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('comment_hide_confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: colors.danger,
            foregroundColor: colors.onBrand,
          ),
          child: const Text('Ocultar'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Confirmation before a clan moderator hides a clan post.
Future<bool> confirmHideClanPost(BuildContext context) async {
  final colors = context.garraColors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        '\u00bfOcultar esta publicaci\u00f3n?',
        style: TextStyle(color: colors.textPrimary),
      ),
      content: Text(
        'Dejar\u00e1 de verse en la comunidad.',
        style: TextStyle(color: colors.textSecondary),
      ),
      actions: [
        TextButton(
          key: const ValueKey('post_hide_cancel'),
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('post_hide_confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: colors.danger,
            foregroundColor: colors.onBrand,
          ),
          child: const Text('Ocultar'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Spanish confirmation before deleting an own comment.
Future<bool> confirmDeleteComment(BuildContext context) async {
  final colors = context.garraColors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        '¿Eliminar comentario?',
        style: TextStyle(color: colors.textPrimary),
      ),
      content: Text(
        'Esta acción quitará tu comentario de la publicación.',
        style: TextStyle(color: colors.textSecondary),
      ),
      actions: [
        TextButton(
          key: const ValueKey('comment_delete_cancel'),
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('comment_delete_confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: colors.danger,
            foregroundColor: colors.onBrand,
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return ok == true;
}
