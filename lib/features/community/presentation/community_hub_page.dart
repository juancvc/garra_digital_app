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
import 'widgets/garra_social_post_card.dart';
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

  Future<void> _deletePost(String postId) async {
    await confirmAndDeletePublication(
      context: context,
      delete: () async {
        await _service.deleteOwnPost(postId);
        if (!mounted) return;
        setState(() => _posts = _posts.where((p) => p.id != postId).toList());
      },
    );
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
                          return GarraSocialPostCard(
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
                            onDelete: mine ? () => _deletePost(post.id) : null,
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
