import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/garra_count_format.dart';
export '../../../../core/utils/date_utils.dart' show formatGarraRelativeTime;
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_avatar.dart';
import '../../data/wall_post_model.dart';
import '../../data/reaction_type.dart';
import 'garra_comment_reactions.dart';
import 'garra_post_media_grid.dart';
import 'garra_reactors_sheet.dart';
import 'garra_reaction_burst.dart';
import '../../../../core/widgets/linked_text.dart';
import 'social_link_card.dart';
import 'post_location_label.dart';

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
    this.onChangeReaction,
    this.onComment,
    this.onDelete,
    this.onOpenOriginal,
  });

  final WallPostModel post;
  final VoidCallback onOpen;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onBlock;
  final VoidCallback? onReport;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onReact;

  /// Long-press on the reaction strip: change the current reaction.
  final VoidCallback? onChangeReaction;
  final VoidCallback? onComment;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final engagement = post.originalPost?.asPost() ?? post;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GarraSpacing.lg,
            vertical: GarraSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.garraColors.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: onOpenProfile,
                    borderRadius: BorderRadius.circular(24),
                    child: GarraAvatar(displayName: post.fullName,
                        avatarUrl: post.avatarUrl, size: 40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: onOpenProfile,
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.isShare ? '${post.fullName} compartió' : post.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.garraColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '@${post.username}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: context.garraColors.textSecondary),
                                ),
                              ),
                              const Text(' · '),
                              Flexible(child: Text(
                                formatGarraRelativeTime(post.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.garraColors.textSecondary),
                              )),
                            ],
                          ),
                          if (post.isFollowersOnly)
                            const Tooltip(
                              message: 'Las publicaciones para seguidores no se pueden compartir',
                              child: Text('Solo seguidores',
                                  style: TextStyle(fontSize: 11)),
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
                        color: context.garraColors.textPrimary,
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'profile') onOpenProfile?.call();
                      if (v == 'block') onBlock?.call();
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
                        if (onReport != null)
                          const PopupMenuItem(
                            value: 'report',
                            child: Text('Denunciar publicación'),
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
              SizedBox(height: post.isShare ? 6 : 10),
              if (post.originalPost case final original?)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (post.content.trim().isNotEmpty) ...[
                  LinkedText(post.content, maxLines: 4,
                      mentions: post.mentions,
                      onOpenMention: (id) => context.push('/comunidad/u/$id'),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle()),
                  const SizedBox(height: GarraSpacing.sm),
                ],
                InkWell(
                  onTap: onOpenOriginal ?? onOpen,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.md, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.garraColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        GarraAvatar(displayName: original.fullName,
                            avatarUrl: original.avatarUrl, size: 28),
                        const SizedBox(width: 8),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(original.fullName, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800)),
                            Text('@${original.username}', maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.garraColors.textSecondary)),
                          ],
                        )),
                      ]),
                      const SizedBox(height: 8),
                      LinkedText(original.content, maxLines: 4,
                          mentions: original.mentions,
                          onOpenMention: (id) => context.push('/comunidad/u/$id'),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium ??
                              const TextStyle()),
                      if (original.postLocation != null)
                        PostLocationLabel(location: original.postLocation!),
                      if (firstSocialLink(original.content) case final link?)
                        SocialLinkCard(link: link),
                      if (original.imageUrl?.isNotEmpty == true || original.media.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        GarraPostMediaGrid(
                          media: original.media,
                          legacyImageUrl: original.imageUrl,
                          onViewPost: onOpenOriginal ?? onOpen,
                        ),
                      ],
                    ]),
                  ),
                )])
              else ...[
                LinkedText(post.content, maxLines: 4,
                    mentions: post.mentions,
                    onOpenMention: (id) => context.push('/comunidad/u/$id'),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium ??
                        const TextStyle()),
                if (post.postLocation != null)
                  PostLocationLabel(location: post.postLocation!),
                if (firstSocialLink(post.content) case final link?)
                  SocialLinkCard(link: link),
                if (post.imageUrl?.isNotEmpty == true || post.media.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GarraPostMediaGrid(media: post.media, legacyImageUrl: post.imageUrl, onViewPost: onOpen),
                ],
              ],
              SizedBox(height: post.isShare ? 4 : GarraSpacing.sm),
              _PostEngagementSummary(
                post: engagement,
                onReactions: engagement.reactionCount > 0
                    ? () => showGarraReactorsSheet(context, postId: engagement.id)
                    : null,
                onComments: onOpenOriginal ?? onOpen,
              ),
              const SizedBox(height: GarraSpacing.xs),
              Row(children: [
                Expanded(child: _PostAction(
                  key: const ValueKey('reaction_cta'),
                  icon: engagement.myReaction == null
                      ? const Icon(Icons.add_reaction_outlined)
                      : GarraReactionGlyph(key: const ValueKey('post_my_reaction'), apiValue: engagement.myReaction!, size: 18),
                  label: engagement.myReaction == null ? 'Reaccionar' : ReactionType.labelFor(engagement.myReaction!),
                  onTap: onReact,
                  onLongPress: onChangeReaction,
                  reactionAnchor: true,
                )),
                Expanded(child: _PostAction(
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: 'Comentar',
                  onTap: onComment ?? onOpenOriginal ?? onOpen,
                )),
                if (!engagement.isFollowersOnly)
                Expanded(child: _PostAction(
                  icon: const Icon(Icons.share_rounded),
                  label: 'Compartir',
                  onTap: onShare,
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostEngagementSummary extends StatelessWidget {
  const _PostEngagementSummary({required this.post, this.onReactions, required this.onComments});

  final WallPostModel post;
  final VoidCallback? onReactions;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: context.garraColors.textSecondary);
    return LayoutBuilder(builder: (context, constraints) {
    final reactions = topNonZeroReactions(post.reactionSummary,
      limit: constraints.maxWidth < 310 ? 1 : 3);
    return Row(children: [
      Expanded(flex: 2, child: InkWell(
        key: const ValueKey('post_reaction_summary'),
        onTap: onReactions,
        child: Row(children: [
          for (final reaction in reactions)
            Padding(padding: const EdgeInsets.only(right: 2),
              child: GarraReactionGlyph(apiValue: reaction.key, size: 15)),
          const SizedBox(width: 4),
          Flexible(child: Text('${post.reactionCount}', style: style, overflow: TextOverflow.ellipsis)),
        ]),
      )),
      Expanded(flex: 3, child: InkWell(
        onTap: onComments,
        child: LayoutBuilder(builder: (_, width) {
          final compact = width.maxWidth < 175;
          return Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
            Text(compact ? '${post.commentCount} com.' :
              '${post.commentCount} ${post.commentCount == 1 ? 'comentario' : 'comentarios'}', style: style),
            Text(compact ? '· ${post.shareCount} comp.' :
              '· ${post.shareCount} ${post.shareCount == 1 ? 'compartido' : 'compartidos'}', style: style),
          ]);
        }),
      )),
      if (post.viewCount > 0) ...[
        const SizedBox(width: 6),
        Row(key: const ValueKey('post_view_count'), mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.visibility_outlined, size: 15,
            color: context.garraColors.textSecondary),
            const SizedBox(width: 3),
            Text(formatGarraCount(post.viewCount), style: style)]),
      ],
    ]);
    });
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({super.key, required this.icon, required this.label,
    this.onTap, this.onLongPress, this.reactionAnchor = false});

  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool reactionAnchor;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap == null ? null : () {
      if (reactionAnchor) GarraReactionAnchor.remember(context);
      onTap!();
    },
    onLongPress: onLongPress == null ? null : () {
      if (reactionAnchor) GarraReactionAnchor.remember(context);
      onLongPress!();
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconTheme(data: IconThemeData(size: 19, color: context.garraColors.textSecondary), child: icon),
        const SizedBox(height: 3),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall),
      ]),
    ),
  );
}

/// Entry to "who reacted" (shared by feed card and post detail).
String reactorsLabel(int count) =>
    count == 1 ? 'Ver 1 reacci\u00f3n' : 'Ver $count reacciones';

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
