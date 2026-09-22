import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/current_fan_provider.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_brand_visual.dart';
import '../../../core/widgets/garra_states.dart';
import '../../community/data/community_service.dart';
import '../../community/data/engagement_utils.dart';
import '../../community/data/wall_post_model.dart';
import '../../community/presentation/providers/community_provider.dart';
import '../../community/presentation/widgets/garra_reaction_picker.dart';
import '../../community/presentation/widgets/garra_social_post_card.dart';

/// Home social feed for Para ti / Siguiendo modes.
class SocialFeedTab extends ConsumerStatefulWidget {
  const SocialFeedTab({
    super.key,
    required this.mode,
    this.contextualInserts = const [],
  });

  /// `FOR_YOU` or `FOLLOWING`.
  final String mode;
  final List<Widget> contextualInserts;

  @override
  ConsumerState<SocialFeedTab> createState() => _SocialFeedTabState();
}

class _SocialFeedTabState extends ConsumerState<SocialFeedTab> {
  List<WallPostModel> _posts = [];
  final Set<String> _reactingPostIds = {};
  bool _loading = true;
  String? _error;

  CommunityService get _service => ref.read(communityServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SocialFeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _load();
    }
  }

  Future<void> _load() async {
    final hadContent = _posts.isNotEmpty;
    setState(() {
      if (!hadContent) _loading = true;
      _error = null;
    });
    try {
      final posts = await _service.getGlobalFeed(mode: widget.mode);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!hadContent) {
          _error = 'No pudimos cargar el feed';
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
            .map(
              (p) =>
                  p.id == post.id ? p.copyWith(savedByMe: post.savedByMe) : p,
            )
            .toList();
      });
      _showError('No se pudo actualizar el guardado. Inténtalo de nuevo.');
    }
  }

  Future<void> _react(WallPostModel post) async {
    if (_reactingPostIds.contains(post.id)) return;

    final selected = await showGarraReactionPicker(
      context,
      currentReaction: post.myReaction,
    );
    if (selected == null || !mounted) return;

    final same = post.myReaction?.toUpperCase() == selected.apiValue;
    final optimistic = applyOptimisticReaction(
      post,
      same ? null : selected.apiValue,
    );
    setState(() {
      _reactingPostIds.add(post.id);
      _replacePost(optimistic);
    });

    final result = same
        ? await _service.removeReaction(post.id)
        : await _service.upsertReaction(
            postId: post.id,
            type: selected.apiValue,
          );
    if (!mounted) return;

    setState(() {
      _reactingPostIds.remove(post.id);
      if (!result.success) {
        _replacePost(post);
      } else if (result.reactionSummary != null &&
          result.reactionCount != null) {
        _replacePost(
          applyReactionResponse(
            post: optimistic,
            myReaction: result.myReaction,
            reactionSummary: result.reactionSummary!,
            reactionCount: result.reactionCount!,
          ),
        );
      }
    });

    if (!result.success) {
      _showError('No se pudo actualizar la reacción. Inténtalo de nuevo.');
    }
  }

  void _replacePost(WallPostModel replacement) {
    _posts = _posts
        .map((post) => post.id == replacement.id ? replacement : post)
        .toList();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(GarraColors.danger),
        behavior: SnackBarBehavior.floating,
      ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Usuario bloqueado')));
    _load();
  }

  void _openCompose() => context.push('/comunidad/compose');

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentFanProvider).asData?.value;
    final meId = me?.id;

    return RefreshIndicator(
      color: const Color(GarraColors.burgundy),
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: GarraSpacing.xxl),
        children: [
          _ComposerRow(displayName: me?.fullName, onCompose: _openCompose),
          if (widget.mode == 'FOR_YOU') const _EditorialFeedMarker(),
          if (_posts.isEmpty) ...widget.contextualInserts,
          if (_loading && _posts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(GarraSpacing.lg),
              child: Column(
                children: [
                  GarraSkeleton(height: 112),
                  SizedBox(height: GarraSpacing.md),
                  GarraSkeleton(height: 260),
                  SizedBox(height: GarraSpacing.md),
                  GarraSkeleton(height: 180),
                ],
              ),
            )
          else if (_error != null && _posts.isEmpty)
            GarraErrorState(message: _error!, onRetry: _load)
          else if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.lg),
              child: GarraEmptyState(
                title: widget.mode == 'FOLLOWING'
                    ? 'Todavía no sigues a nadie'
                    : 'Sé el primero en publicar',
                message: widget.mode == 'FOLLOWING'
                    ? 'Descubre hinchas y empieza a seguir.'
                    : 'Comparte lo que vive la crema hoy.',
                actionLabel: widget.mode == 'FOLLOWING'
                    ? 'Buscar personas'
                    : 'Nueva publicación',
                onAction: () => context.push(
                  widget.mode == 'FOLLOWING'
                      ? '/comunidad/buscar'
                      : '/comunidad/compose',
                ),
              ),
            )
          else ...[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(GarraColors.creamMuted),
                  ),
                ),
              ),
            ..._buildFeedItems(meId),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildFeedItems(String? meId) {
    final items = <Widget>[];
    var insertIndex = 0;
    for (var index = 0; index < _posts.length; index++) {
      final post = _posts[index];
      final mine =
          post.isMine ||
          (meId != null && meId.isNotEmpty && post.authorId == meId);
      final view = post.copyWith(isMine: mine);
      items.add(
        GarraSocialPostCard(
          post: view,
          onOpen: () =>
              context.push('/muro-crema/posts/${post.id}').then((_) => _load()),
          onOpenProfile: mine || post.authorId == null || post.authorId!.isEmpty
              ? null
              : () => context.push('/comunidad/u/${post.authorId}'),
          onBlock: mine || post.authorId == null || post.authorId!.isEmpty
              ? null
              : () => _confirmBlock(post.authorId!),
          onReport: mine
              ? null
              : () => context.push('/muro-crema/posts/${post.id}'),
          onShare: () => SharePlus.instance.share(
            ShareParams(
              text:
                  '${post.fullName}: ${post.content}\n\nÚnete a Garra Digital',
            ),
          ),
          onSave: () => _toggleSave(post),
          onReact: () => _react(post),
          onComment: () =>
              context.push('/muro-crema/posts/${post.id}').then((_) => _load()),
        ),
      );

      final shouldInsert = index == 1 || (index > 1 && (index - 1) % 4 == 0);
      if (shouldInsert && insertIndex < widget.contextualInserts.length) {
        items.add(widget.contextualInserts[insertIndex]);
        insertIndex++;
      }
    }
    return items;
  }
}

class _EditorialFeedMarker extends StatelessWidget {
  const _EditorialFeedMarker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        0,
        GarraSpacing.lg,
        GarraSpacing.md,
      ),
      child: Row(
        children: [
          const GarraEditorialEyebrow(
            label: 'La tribuna crema',
            icon: Icons.local_fire_department_outlined,
          ),
          const SizedBox(width: GarraSpacing.sm),
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(GarraColors.gold),
                    Color(GarraColors.borderSubtle),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerRow extends StatelessWidget {
  const _ComposerRow({required this.onCompose, this.displayName});

  final String? displayName;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.sm,
        GarraSpacing.lg,
        GarraSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.25;
          return Row(
            children: [
              GarraAvatar(
                displayName:
                    (displayName != null && displayName!.trim().isNotEmpty)
                    ? displayName!
                    : 'Crema',
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: const Color(GarraColors.surface),
                  borderRadius: BorderRadius.circular(GarraRadius.lg),
                  child: InkWell(
                    onTap: onCompose,
                    borderRadius: BorderRadius.circular(GarraRadius.lg),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Text(
                        '¿Qué vive la crema hoy?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(GarraColors.creamMuted),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (compact)
                IconButton(
                  tooltip: 'Foto',
                  onPressed: onCompose,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.photo_outlined, size: 19),
                )
              else
                TextButton.icon(
                  onPressed: onCompose,
                  icon: const Icon(Icons.photo_outlined, size: 18),
                  label: const Text('Foto'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
