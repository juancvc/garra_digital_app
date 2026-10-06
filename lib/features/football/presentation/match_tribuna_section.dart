import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/garra_cached_network_image.dart';
import '../../community/data/wall_post_model.dart';
import '../../community/presentation/providers/community_provider.dart';
import '../data/garra_football_models.dart';

/// SONIC_01: the match Tribuna inside the Centro Garra match detail. It is the
/// existing match wall (Muro Crema) scoped to the Garra match linked to the
/// fixture: same posts endpoint, same limits enforced by the backend, same
/// compose (text + photo), post detail with comments and reactions. Nothing is
/// duplicated and the global feed is not involved.
class MatchTribunaSection extends ConsumerWidget {
  const MatchTribunaSection({super.key, required this.match});

  static const previewSize = 3;
  final FootballMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final matchId = match.garraMatchId;
    if (matchId == null || matchId.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.forum_outlined),
          title: Text('Tribuna Garra'),
          subtitle: Text('Aún no está vinculada a este partido'),
        ),
      );
    }
    final params = WallPostsParams(matchId: matchId, locationTag: 'ALL');
    final posts = ref.watch(wallPostsProvider(params));
    final wall = ref.watch(wallStatusProvider).asData?.value;
    final isCurrentWall = wall?.matchId == matchId;
    final canPublish = isCurrentWall &&
        wall!.wallStatus != 'CLOSED' && wall.wallStatus != 'ARCHIVED';

    Future<void> compose() async {
      final created = await context.push<bool>(
        '/muro-crema/compose?matchId=${Uri.encodeQueryComponent(matchId)}',
      );
      if (created == true) {
        ref.invalidate(wallPostsProvider(params));
        ref.invalidate(myWallPostsProvider);
      }
    }

    return Card(
      key: const ValueKey('match_tribuna'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.forum_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text('Tribuna del partido', style: text.titleMedium)),
              if (match.isLive)
                Text('EN VIVO', style: text.labelSmall?.copyWith(
                  color: Colors.red.shade700, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text(_subtitle(canPublish), style: text.bodySmall),
            const SizedBox(height: 8),
            posts.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('No pudimos cargar la Tribuna'),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(wallPostsProvider(params)),
                  child: const Text('Reintentar'),
                ),
              ),
              data: (items) {
                final visible = items.where((p) => p.status == 'ACTIVE').toList();
                if (visible.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(canPublish
                        ? 'Aún no hay arengas. ¡Sé el primero en alentar!'
                        : 'Todavía no hay arengas en esta Tribuna.'),
                  );
                }
                return Column(children: [
                  for (final post in visible.take(previewSize))
                    _TribunaPostTile(post: post),
                ]);
              },
            ),
            Wrap(spacing: 8, children: [
              if (canPublish)
                FilledButton.icon(
                  onPressed: compose,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Publicar en la Tribuna'),
                ),
              TextButton(
                onPressed: () => context.push(
                    '/muro-crema?matchId=${Uri.encodeQueryComponent(matchId)}'),
                child: const Text('Ver Tribuna completa'),
              ),
              TextButton(
                onPressed: () => context.push('/matchday/$matchId/polls'),
                child: const Text('Encuestas del partido'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _subtitle(bool canPublish) {
    if (canPublish) {
      return match.isLive
          ? 'Vive el partido con la hinchada.'
          : match.isFinished
              ? 'Comenta el resultado con la hinchada.'
              : 'Calienta la previa con la hinchada.';
    }
    if (match.isFinished) return 'La conversación del partido.';
    return 'La Tribuna se abre cerca del partido. Mientras tanto, puedes leerla.';
  }
}

class _TribunaPostTile extends StatelessWidget {
  const _TribunaPostTile({required this.post});
  final WallPostModel post;

  @override
  Widget build(BuildContext context) {
    final image = (post.imageUrl ?? '').isNotEmpty
        ? post.imageUrl!
        : post.media.isNotEmpty ? post.media.first.url : null;
    return ListTile(
      key: ValueKey('tribuna_post_${post.id}'),
      contentPadding: EdgeInsets.zero,
      onTap: () => context.push('/muro-crema/posts/${post.id}'),
      leading: CircleAvatar(child: Text(
        post.username.isEmpty ? 'H' : post.username[0].toUpperCase())),
      title: Text(post.fullName.isEmpty ? '@${post.username}' : post.fullName,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [post.content, if (post.reactionCount > 0 || post.commentCount > 0)
          '${post.reactionCount} reacciones · ${post.commentCount} comentarios']
            .join('\n'),
        maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: image == null ? null : ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 48, height: 48,
          child: GarraCachedNetworkImage(imageUrl: image, fit: BoxFit.cover)),
      ),
    );
  }
}
