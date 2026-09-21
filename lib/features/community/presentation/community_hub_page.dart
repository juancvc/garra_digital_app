import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/community_service.dart';
import '../data/wall_post_model.dart';
import 'widgets/garra_reaction_bar.dart';

/// Comunidad 365 hub: global feed + entry to Comunidades Cremas / Solidaria.
class CommunityHubPage extends ConsumerStatefulWidget {
  const CommunityHubPage({super.key});

  @override
  ConsumerState<CommunityHubPage> createState() => _CommunityHubPageState();
}

class _CommunityHubPageState extends ConsumerState<CommunityHubPage> {
  final _service = CommunityService();
  List<WallPostModel> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _service.getGlobalFeed();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar la comunidad';
        _loading = false;
      });
    }
  }

  Future<void> _confirmBlock(String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquear usuario'),
        content: const Text(
          'No verás sus publicaciones ni comentarios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.blockUser(userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuario bloqueado')),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Comunidad'),
        actions: [
          TextButton(
            onPressed: () => context.push('/clans'),
            child: const Text('Comunidades'),
          ),
          IconButton(
            tooltip: 'Ofertas',
            onPressed: () => context.push('/ruta-templo/ofertas'),
            icon: const Icon(Icons.local_offer_outlined),
          ),
          IconButton(
            tooltip: 'Solidaria',
            onPressed: () => context.push('/solidaria'),
            icon: const Icon(Icons.volunteer_activism_outlined),
          ),
          IconButton(
            tooltip: 'Bloqueados',
            onPressed: () => context.push('/comunidad/bloqueados'),
            icon: const Icon(Icons.person_off_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await context.push<bool>('/comunidad/compose');
          if (ok == true) _load();
        },
        backgroundColor: const Color(GarraColors.gold),
        foregroundColor: const Color(GarraColors.charcoal),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Publicar'),
      ),
      body: RefreshIndicator(
        color: const Color(GarraColors.gold),
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      GarraErrorState(message: _error!, onRetry: _load),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      Material(
                        color: const Color(GarraColors.garnetDeep),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => context.push('/comunidad/compose'),
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(GarraSpacing.lg),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '¿Qué vive la crema hoy?',
                                        style: TextStyle(
                                          color: Color(GarraColors.cream),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Comparte con la comunidad · 365 días',
                                        style: TextStyle(
                                          color: Color(GarraColors.creamMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: Color(GarraColors.gold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickLink(
                              label: 'Comunidades Cremas',
                              onTap: () => context.push('/clans'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickLink(
                              label: 'Garra Solidaria',
                              onTap: () => context.push('/solidaria'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: GarraSpacing.lg),
                      if (_posts.isEmpty)
                        const GarraEmptyState(
                          title: 'Tribuna en silencio',
                          message:
                              'Sé el primero en compartir lo que vive la crema hoy.',
                        )
                      else
                        ..._posts.map((post) => _GlobalPostCard(
                              post: post,
                              onOpen: () => context
                                  .push('/muro-crema/posts/${post.id}')
                                  .then((_) => _load()),
                              onOpenProfile: post.authorId == null ||
                                      post.authorId!.isEmpty
                                  ? null
                                  : () => context.push(
                                        '/comunidad/u/${post.authorId}',
                                      ),
                              onBlock: post.authorId == null ||
                                      post.authorId!.isEmpty
                                  ? null
                                  : () => _confirmBlock(post.authorId!),
                              onShare: () => Share.share(
                                '${post.fullName}: ${post.content}',
                              ),
                            )),
                    ],
                  ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(GarraColors.cream),
        side: const BorderSide(color: Color(GarraColors.gold)),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _GlobalPostCard extends StatelessWidget {
  const _GlobalPostCard({
    required this.post,
    required this.onOpen,
    this.onOpenProfile,
    this.onBlock,
    this.onShare,
  });

  final WallPostModel post;
  final VoidCallback onOpen;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onBlock;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: GarraCard(
        onTap: onOpen,
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
                        Text(
                          '@${post.username}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'profile') onOpenProfile?.call();
                    if (v == 'block') onBlock?.call();
                    if (v == 'share') onShare?.call();
                  },
                  itemBuilder: (_) => [
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
                    if (onBlock != null)
                      const PopupMenuItem(
                        value: 'block',
                        child: Text('Bloquear usuario'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(post.content, maxLines: 4, overflow: TextOverflow.ellipsis),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    post.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            GarraReactionBar(
              reactionSummary: post.reactionSummary,
              reactionCount: post.reactionCount,
              commentCount: post.commentCount,
              myReaction: post.myReaction,
            ),
          ],
        ),
      ),
    );
  }
}
