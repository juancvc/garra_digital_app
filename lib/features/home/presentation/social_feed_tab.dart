import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/current_fan_provider.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/navigation/home_back_scroll.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_brand_visual.dart';
import '../../../core/widgets/garra_states.dart';
import '../../community/data/community_report.dart';
import '../../community/data/community_service.dart';
import '../../community/data/engagement_utils.dart';
import '../../community/data/garra_view_tracker.dart';
import '../../community/data/wall_post_model.dart';
import '../../community/presentation/providers/community_provider.dart';
import '../../community/presentation/widgets/garra_reaction_actions.dart';
import '../../community/presentation/widgets/garra_report_sheet.dart';
import '../../community/presentation/widgets/garra_social_post_card.dart';
import '../../community/presentation/widgets/garra_share_sheet.dart';
import '../../community/presentation/widgets/garra_viewport_tracker.dart';

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
  final ScrollController _scrollController = ScrollController();
  HomeBackScroll? _homeBackScroll;
  final Set<String> _reactingPostIds = {};
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  CommunityService get _service => ref.read(communityServiceProvider);

  @override
  void initState() {
    super.initState();
    if (widget.mode != 'RECENT') {
      _homeBackScroll = ref.read(homeBackScrollProvider.notifier);
      _homeBackScroll!.attach(_scrollController);
    }
    _load();
  }

  @override
  void dispose() {
    _homeBackScroll?.detach(_scrollController);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SocialFeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      if (widget.mode == 'RECENT') {
        _homeBackScroll?.detach(_scrollController);
        _homeBackScroll = null;
      } else {
        _homeBackScroll ??= ref.read(homeBackScrollProvider.notifier);
        _homeBackScroll!.attach(_scrollController);
      }
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final hadContent = _posts.isNotEmpty;
    setState(() {
      if (!hadContent) _loading = true;
      _error = null;
    });
    try {
      final posts = await _service.getGlobalFeed(mode: widget.mode);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _posts = posts;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
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
    if (!allowNetworkAction(context)) return;
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

  /// ANALYTICS_12: card was >=50% visible for >=1s (someone else's post).
  Future<void> _onPostSeen(String postId) async {
    final count = await GarraViewTracker.instance.trackPostView(
      _service,
      postId,
    );
    if (count == null || !mounted) return;
    setState(() {
      _posts = _posts
          .map((p) => p.id == postId ? p.copyWith(viewCount: count) : p)
          .toList();
    });
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

  Future<void> _react(WallPostModel post, {bool change = false}) async {
    if (_reactingPostIds.contains(post.id)) return;
    setState(() => _reactingPostIds.add(post.id));

    final intent = await resolveReactionTap(
      context,
      current: post.myReaction,
      forcePicker: change,
    );
    if (!mounted) return;
    if (intent == null || !allowNetworkAction(context)) {
      setState(() => _reactingPostIds.remove(post.id));
      return;
    }

    final optimistic = applyOptimisticReaction(post, intent.apiValue);
    setState(() {
      _replacePost(optimistic);
    });

    final result = intent.isRemove
        ? await _service.removeReaction(post.id)
        : await _service.upsertReaction(
            postId: post.id,
            type: intent.apiValue!,
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
      _showError(reactionErrorMessage(intent));
    }
  }

  void _replacePost(WallPostModel replacement) {
    _posts = _posts
        .map((post) {
          if (post.id == replacement.id) return replacement;
          if (post.originalPost?.id == replacement.id) {
            return post.copyWith(originalPost: post.originalPost!.copyWith(
              reactionSummary: replacement.reactionSummary,
              reactionCount: replacement.reactionCount,
              myReaction: replacement.myReaction,
              clearMyReaction: replacement.myReaction == null,
            ));
          }
          return post;
        })
        .toList();
  }

  Future<void> _share(WallPostModel post) async {
    final target = post.originalPost?.asPost() ?? post;
    final outcome = await showGarraShareSheet(context, post: target, service: _service,
        allowInternalRepost: !post.isShare);
    if (!mounted || outcome == null) return;
    if (outcome.external) {
      await SharePlus.instance.share(ShareParams(
        text: '${target.fullName}: ${target.content}\n\nÚnete a Garra Digital',
      ));
      return;
    }
    if (outcome.sharedPost case final share?) {
      final count = share.originalPost?.shareCount ?? target.shareCount;
      setState(() {
        _posts = [share, ..._posts.where((p) => p.id != share.id).map((p) =>
          p.id == target.id ? p.copyWith(shareCount: count, sharedByMe: true) :
          p.originalPost?.id == target.id ? p.copyWith(originalPost:
            p.originalPost!.copyWith(shareCount: count, sharedByMe: true)) : p)];
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compartido en Garra')));
    } else if (outcome.undoCount case final count?) {
      setState(() {
        _posts = _posts.where((p) => !(p.originalPost?.id == target.id && p.isMine)).map((p) =>
          p.id == target.id ? p.copyWith(shareCount: count, sharedByMe: false) :
          p.originalPost?.id == target.id ? p.copyWith(originalPost:
            p.originalPost!.copyWith(shareCount: count, sharedByMe: false)) : p).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compartido eliminado')));
    }
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

  void _reconcilePublishedPost(WallPostModel post) {
    ++_loadGeneration;
    setState(() {
      final original = post.originalPost;
      _posts = [post, ..._posts.where((existing) => existing.id != post.id).map((existing) {
        if (original == null) return existing;
        if (existing.id == original.id) {
          return existing.copyWith(shareCount: original.shareCount, sharedByMe: true);
        }
        if (existing.originalPost?.id == original.id) {
          return existing.copyWith(originalPost: existing.originalPost!.copyWith(
              shareCount: original.shareCount, sharedByMe: true));
        }
        return existing;
      })];
      _loading = false;
      _error = null;
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _openCompose() async {
    final revision = ref.read(communityFeedRevisionProvider).revision;
    final created = await context.push<bool>('/comunidad/compose');
    if (created == true &&
        mounted &&
        ref.read(communityFeedRevisionProvider).revision == revision) {
      ref.read(communityFeedRevisionProvider.notifier).bump();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CommunityFeedChange>(communityFeedRevisionProvider, (
      previous,
      next,
    ) {
      if (previous?.revision == next.revision) return;
      if (next.unsharedOriginalId case final originalId?) {
        setState(() => _posts = _posts.where((p) =>
          !(p.originalPost?.id == originalId && p.isMine)).map((p) {
          if (p.id == originalId) {
            return p.copyWith(shareCount: next.shareCount, sharedByMe: false);
          }
          if (p.originalPost?.id == originalId) {
            return p.copyWith(originalPost: p.originalPost!.copyWith(
                shareCount: next.shareCount, sharedByMe: false));
          }
          return p;
        }).toList());
        return;
      }
      final post = next.post;
      if (post == null) {
        _scrollToTop();
        _load();
      } else {
        _reconcilePublishedPost(post);
      }
    });
    final me = ref.watch(currentFanProvider).asData?.value;
    final meId = me?.id;

    return RefreshIndicator(
      color: const Color(GarraColors.burgundy),
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
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
                onAction: widget.mode == 'FOLLOWING'
                    ? () => context.push('/comunidad/buscar')
                    : _openCompose,
              ),
            )
          else ...[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.garraColors.textSecondary,
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
        GarraViewportTracker(
          id: post.id,
          enabled: !mine,
          onVisible: () => _onPostSeen(post.id),
          child: GarraSocialPostCard(
            post: view,
            onOpenOriginal: post.originalPost == null ? null :
                () => context.push('/muro-crema/posts/${post.originalPost!.id}').then((_) => _load()),
            onOpen: () => context
                .push('/muro-crema/posts/${post.originalPost?.id ?? post.id}')
                .then((_) => _load()),
            onOpenProfile:
                post.authorId == null || post.authorId!.isEmpty
                ? null
                : () => context.push('/comunidad/u/${post.authorId}'),
            onBlock: mine || post.authorId == null || post.authorId!.isEmpty
                ? null
                : () => _confirmBlock(post.authorId!),
            onReport: mine
                ? null
                : () => showGarraReportSheet(
                    context,
                    service: _service,
                    target: GarraReportTarget.post,
                    targetId: post.id,
                  ),
            onShare: () => _share(post),
            onSave: () => _toggleSave(post),
            onDelete: mine ? () => _deletePost(post.id) : null,
            onReact: () => _react(post.originalPost?.asPost() ?? post),
            onChangeReaction: () => _react(post.originalPost?.asPost() ?? post, change: true),
            onComment: () => context
                .push('/muro-crema/posts/${post.originalPost?.id ?? post.id}')
                .then((_) => _load()),
          ),
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(GarraColors.gold),
                    context.garraColors.border,
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
                  color: context.garraColors.surface,
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
                          color: context.garraColors.textSecondary,
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
