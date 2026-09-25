import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/utils/date_utils.dart';
export '../../../../core/utils/date_utils.dart' show formatGarraRelativeTime;
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/widgets/garra_avatar.dart';
import '../../data/wall_post_model.dart';
import 'garra_post_media_grid.dart';
import 'garra_reaction_bar.dart';

/// Shared social post row for Home feed and Comunidad surfaces.
class GarraSocialPostCard extends StatelessWidget {
  const GarraSocialPostCard({
    super.key,
    required this.post,
    required this.onOpen,
    this.onOpenProfile,
    this.onBlock,
    this.onReport,
    this.onShare,
    this.onSave,
    this.onReact,
    this.onComment,
    this.onDelete,
  });

  final WallPostModel post;
  final VoidCallback onOpen;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onBlock;
  final VoidCallback? onReport;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onReact;
  final VoidCallback? onComment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GarraSpacing.lg,
            vertical: GarraSpacing.md,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(GarraColors.borderSubtle)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onOpenProfile,
                    child: GarraAvatar(displayName: post.fullName, size: 40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onOpenProfile,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.fullName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '@${post.username}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              const Text(' · '),
                              Text(
                                formatGarraRelativeTime(post.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onSave != null)
                    IconButton(
                      tooltip: post.savedByMe ? 'Quitar guardado' : 'Guardar',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onSave!();
                      },
                      icon: Icon(
                        post.savedByMe ? Icons.bookmark : Icons.bookmark_border,
                        color: const Color(GarraColors.cream),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'profile') onOpenProfile?.call();
                      if (v == 'block') onBlock?.call();
                      if (v == 'share') onShare?.call();
                      if (v == 'report') onReport?.call();
                      if (v == 'save') {
                        HapticFeedback.lightImpact();
                        onSave?.call();
                      }
                      if (v == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) {
                      if (post.isMine) {
                        return [
                          if (onShare != null)
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('Compartir'),
                            ),
                          if (onSave != null)
                            const PopupMenuItem(
                              value: 'save',
                              child: Text('Guardar'),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar publicación'),
                            ),
                        ];
                      }
                      return [
                        if (onOpenProfile != null)
                          const PopupMenuItem(
                            value: 'profile',
                            child: Text('Ver perfil'),
                          ),
                        if (onShare != null)
                          const PopupMenuItem(
                            value: 'share',
                            child: Text('Compartir'),
                          ),
                        if (onReport != null)
                          const PopupMenuItem(
                            value: 'report',
                            child: Text('Reportar publicación'),
                          ),
                        if (onBlock != null)
                          const PopupMenuItem(
                            value: 'block',
                            child: Text('Bloquear usuario'),
                          ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(post.content, maxLines: 4, overflow: TextOverflow.ellipsis),
              if ((post.imageUrl != null && post.imageUrl!.isNotEmpty) ||
                  post.media.isNotEmpty) ...[
                const SizedBox(height: 10),
                GarraPostMediaGrid(
                  media: post.media,
                  legacyImageUrl: post.imageUrl,
                ),
              ],
              const SizedBox(height: 8),
              GarraReactionBar(
                reactionSummary: post.reactionSummary,
                reactionCount: post.reactionCount,
                commentCount: post.commentCount,
                myReaction: post.myReaction,
                onTapReactions: onReact,
                onTapComments: onComment ?? onOpen,
              ),
              if (post.commentCount > 0)
                TextButton(
                  onPressed: onOpen,
                  child: Text('Ver ${post.commentCount} comentarios'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> confirmAndDeletePublication({
  required BuildContext context,
  required Future<void> Function() delete,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Eliminar publicación?'),
      content: const Text('Esta acción no se puede deshacer.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await delete();
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Publicación eliminada')));
}
