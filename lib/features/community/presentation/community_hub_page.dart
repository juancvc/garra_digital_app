import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/current_fan_provider.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/community_service.dart';
import '../data/wall_post_model.dart';
import 'widgets/garra_reaction_bar.dart';
import 'widgets/garra_post_media_grid.dart';
import '../../retention/data/retention_service.dart';

/// Comunidad 365 hub: Para ti / Siguiendo / Recientes + discovery.
class CommunityHubPage extends ConsumerStatefulWidget {
  const CommunityHubPage({super.key});

  @override
  ConsumerState<CommunityHubPage> createState() => _CommunityHubPageState();
}

class _CommunityHubPageState extends ConsumerState<CommunityHubPage> {
  final _service = CommunityService();
  final _retention = RetentionService();
  List<WallPostModel> _posts = [];
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;
  String? _error;
  String _mode = 'FOR_YOU';

  static const _modes = [
    ('FOR_YOU', 'Para ti'),
    ('FOLLOWING', 'Siguiendo'),
    ('RECENT', 'Recientes'),
  ];

  @override
  void initState() {
    super.initState();
    _maybeOnboard();
    _load();
  }

  Future<void> _maybeOnboard() async {
    try {
      final prefs = await _retention.getInterests();
      if (!prefs.onboardingCompleted && mounted) {
        context.push('/onboarding');
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final hadContent = _posts.isNotEmpty;
    setState(() {
      if (!hadContent) _loading = true;
      _error = null;
    });
    try {
      final posts = await _service.getGlobalFeed(mode: _mode);
      List<Map<String, dynamic>> people = [];
      try {
        people = await _service.discoveryPeople();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _people = people;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Keep last good content on refresh failure.
        if (!hadContent) {
          _error = 'No pudimos cargar la comunidad';
        } else {
          _error = 'No pudimos actualizar. Mostramos la última versión.';
        }
        _loading = false;
      });
    }
  }

  Future<void> _toggleSave(WallPostModel post) async {
    final next = !post.savedByMe;
    setState(() {
      _posts = _posts
          .map((p) => p.id == post.id ? p.copyWith(savedByMe: next) : p)
          .toList();
    });
    try {
      if (next) {
        await _service.savePost(post.id);
      } else {
        await _service.unsavePost(post.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = _posts
            .map((p) =>
                p.id == post.id ? p.copyWith(savedByMe: post.savedByMe) : p)
            .toList();
      });
    }
  }

  Future<void> _confirmBlock(String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquear usuario'),
        content: const Text('No verás sus publicaciones ni comentarios.'),
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
        title: const Row(
          children: [
            _GarraMarkBadge(),
            SizedBox(width: 8),
            Text('Comunidad'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => context.push('/comunidad/buscar'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Actividad',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(GarraColors.burgundy),
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
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _modes
                              .map(
                                (m) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(m.$2),
                                    selected: _mode == m.$1,
                                    onSelected: (_) {
                                      setState(() => _mode = m.$1);
                                      _load();
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      if (_mode == 'FOLLOWING' && _people.isNotEmpty) ...[
                        const SizedBox(height: GarraSpacing.lg),
                        const GarraSectionHeader(title: 'Personas para seguir'),
                        const SizedBox(height: 8),
                        ..._people.take(5).map((p) {
                          final id = p['userId']?.toString() ??
                              p['id']?.toString() ??
                              '';
                          final name = p['displayName']?.toString() ??
                              p['fullName']?.toString() ??
                              '';
                          final username = p['username']?.toString() ?? '';
                          final reason = p['reason']?.toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GarraCard(
                              onTap: id.isEmpty
                                  ? null
                                  : () => context.push('/comunidad/u/$id'),
                              child: Row(
                                children: [
                                  GarraAvatar(
                                    displayName:
                                        name.isEmpty ? username : name,
                                    size: 40,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        Text(
                                          '@$username',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        if (reason != null && reason.isNotEmpty)
                                          Text(
                                            reason,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: id.isEmpty
                                        ? null
                                        : () async {
                                            await _service.followUser(id);
                                            await _load();
                                          },
                                    child: const Text('Seguir'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: GarraSpacing.lg),
                      if (_posts.isEmpty)
                        GarraEmptyState(
                          title: _mode == 'FOLLOWING'
                              ? 'Todavía no sigues a nadie'
                              : 'Sé el primero en publicar',
                          message: _mode == 'FOLLOWING'
                              ? 'Descubre hinchas y empieza a seguir.'
                              : 'Comparte lo que vive la crema hoy.',
                          actionLabel: _mode == 'FOLLOWING'
                              ? 'Buscar personas'
                              : 'Nueva publicación',
                          onAction: () => context.push(
                            _mode == 'FOLLOWING'
                                ? '/comunidad/buscar'
                                : '/comunidad/compose',
                          ),
                        )
                      else
                        ..._posts.map((post) {
                          final meId =
                              ref.watch(currentFanProvider).asData?.value?.id;
                          final mine = post.isMine ||
                              (meId != null &&
                                  meId.isNotEmpty &&
                                  post.authorId == meId);
                          final view = post.copyWith(isMine: mine);
                          return _GlobalPostCard(
                            post: view,
                            onOpen: () => context
                                .push('/muro-crema/posts/${post.id}')
                                .then((_) => _load()),
                            onOpenProfile: mine ||
                                    post.authorId == null ||
                                    post.authorId!.isEmpty
                                ? null
                                : () => context.push(
                                      '/comunidad/u/${post.authorId}',
                                    ),
                            onBlock: mine ||
                                    post.authorId == null ||
                                    post.authorId!.isEmpty
                                ? null
                                : () => _confirmBlock(post.authorId!),
                            onReport: mine
                                ? null
                                : () => context.push(
                                      '/muro-crema/posts/${post.id}',
                                    ),
                            onShare: () => SharePlus.instance.share(
                              ShareParams(
                                text:
                                    '${post.fullName}: ${post.content}\n\nÚnete a Garra Digital',
                              ),
                            ),
                            onSave: () => _toggleSave(post),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}

class _GarraMarkBadge extends StatelessWidget {
  const _GarraMarkBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(GarraColors.burgundyDeep),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(GarraColors.cream),
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _GlobalPostCard extends StatelessWidget {
  const _GlobalPostCard({
    required this.post,
    required this.onOpen,
    this.onOpenProfile,
    this.onBlock,
    this.onReport,
    this.onShare,
    this.onSave,
  });

  final WallPostModel post;
  final VoidCallback onOpen;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onBlock;
  final VoidCallback? onReport;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

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
                if (onSave != null)
                  IconButton(
                    tooltip: post.savedByMe ? 'Quitar guardado' : 'Guardar',
                    onPressed: onSave,
                    icon: Icon(
                      post.savedByMe
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: const Color(GarraColors.cream),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'profile') onOpenProfile?.call();
                    if (v == 'block') onBlock?.call();
                    if (v == 'share') onShare?.call();
                    if (v == 'report') onReport?.call();
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
            ),
            if (post.commentCount > 0)
              TextButton(
                onPressed: onOpen,
                child: Text('Ver ${post.commentCount} comentarios'),
              ),
          ],
        ),
      ),
    );
  }
}
