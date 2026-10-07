import 'dart:async';

import 'package:dio/dio.dart';
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
import '../../community/data/community_feed_item.dart';
import '../../community/data/community_service.dart';
import '../../community/data/engagement_utils.dart';
import '../../community/data/garra_view_tracker.dart';
import '../../community/data/wall_post_model.dart';
import '../../community/presentation/providers/community_provider.dart';
import '../../community/presentation/widgets/garra_reaction_actions.dart';
import '../../community/presentation/widgets/garra_discovery_section.dart';
import '../../community/presentation/widgets/garra_report_sheet.dart';
import '../../community/presentation/widgets/garra_social_post_card.dart';
import '../../community/presentation/widgets/garra_tribuna_offer_card.dart';
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

  /// DEMO_HARDENING_02A.1: hard bound for one feed page (Dio connect/receive
  /// timeouts + GET retry + 401 refresh can otherwise stack up to ~1 min of
  /// skeleton). Past it the tab shows error + Reintentar, never a stuck skeleton.
  static const Duration loadTimeout = Duration(seconds: 15);

  @override
  ConsumerState<SocialFeedTab> createState() => _SocialFeedTabState();
}

class _SocialFeedTabState extends ConsumerState<SocialFeedTab> {
  List<CommunityFeedItem> _items = [];

  List<WallPostModel> get _posts => [
        for (final item in _items)
          if (item is CommunityPostFeedItem) item.post,
      ];

  void _mapPosts(WallPostModel Function(WallPostModel post) map) {
    _items = [
      for (final item in _items)
        if (item is CommunityPostFeedItem)
          CommunityPostFeedItem(map(item.post))
        else
          item,
    ];
  }

  void _filterPosts(bool Function(WallPostModel post) keep) {
    _items = [
      for (final item in _items)
        if (item is! CommunityPostFeedItem)
          item
        else if (keep(item.post))
          item,
    ];
  }

  /// Rebuild feed from a new organic post list while keeping BUSINESS_OFFER cards
  /// after every N-th post (same client-visible density as backend V1).
  void _setPostsKeepingOffers(List<WallPostModel> posts) {
    final offers = [
      for (final item in _items)
        if (item is BusinessOfferFeedItem) item,
    ];
    final next = <CommunityFeedItem>[];
    var offerIdx = 0;
    for (var i = 0; i < posts.length; i++) {
      next.add(CommunityPostFeedItem(posts[i]));
      if ((i + 1) % 5 == 0 && offerIdx < offers.length) {
        next.add(offers[offerIdx++]);
      }
    }
    while (offerIdx < offers.length) {
      next.add(offers[offerIdx++]);
    }
    _items = next;
  }
  final ScrollController _scrollController = ScrollController();
  HomeBackScroll? _homeBackScroll;
  final Set<String> _reactingPostIds = {};
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  /// GARRA40: cursor pagination. `_nextCursor` is opaque (backend-owned).
  String? _nextCursor;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _moreFailed = false;

  CommunityService get _service => ref.read(communityServiceProvider);

  /// Watchdogs for in-flight page loads; cancelled on dispose so a disposed tab
  /// never keeps timers alive.
  final Set<Timer> _loadWatchdogs = {};

  /// DEMO_HARDENING_02A.1: a page load that does not settle within
  /// [SocialFeedTab.loadTimeout] fails with [TimeoutException], so the tab ends in
  /// error + Reintentar instead of an endless skeleton.
  Future<T> _bounded<T>(Future<T> request) {
    final result = Completer<T>();
    late final Timer watchdog;
    watchdog = Timer(SocialFeedTab.loadTimeout, () {
      _loadWatchdogs.remove(watchdog);
      if (!result.isCompleted) {
        result.completeError(TimeoutException('feed page', SocialFeedTab.loadTimeout));
      }
    });
    _loadWatchdogs.add(watchdog);
    request.then(
      (value) {
        watchdog.cancel();
        _loadWatchdogs.remove(watchdog);
        if (!result.isCompleted) result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        watchdog.cancel();
        _loadWatchdogs.remove(watchdog);
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    return result.future;
  }

  @override
  void initState() {
    super.initState();
    if (widget.mode != 'RECENT') {
      _homeBackScroll = ref.read(homeBackScrollProvider.notifier);
      _homeBackScroll!.attach(_scrollController);
    }
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    for (final watchdog in _loadWatchdogs) {
      watchdog.cancel();
    }
    _loadWatchdogs.clear();
    _scrollController.removeListener(_onScroll);
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
    final hadContent = _items.isNotEmpty;
    setState(() {
      if (!hadContent) _loading = true;
      _error = null;
      _loadingMore = false;
      _moreFailed = false;
    });
    try {
      final page = await _bounded(_service.getFeedPage(mode: widget.mode));
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasNext && page.items.isNotEmpty;
        _loading = false;
        _error = null;
      });
      _scheduleFillCheck();
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

  void _onScroll() {
    // After a failure the user decides ("Reintentar"): scrolling never re-fires it.
    if (!_scrollController.hasClients || _moreFailed) return;
    if (_scrollController.position.extentAfter < 900) _loadMore();
  }

  /// A short first page (or a tall screen) must still be able to continue.
  void _scheduleFillCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore || _nextCursor == null) return;
    final generation = _loadGeneration;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final page = await _bounded(
        _service.getFeedPage(mode: widget.mode, cursor: _nextCursor),
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        final knownPostIds = {
          for (final item in _items)
            if (item is CommunityPostFeedItem) item.post.id,
        };
        final knownOfferIds = {
          for (final item in _items)
            if (item is BusinessOfferFeedItem) item.offer.id,
        };
        final merged = [..._items];
        for (final item in page.items) {
          if (item is CommunityPostFeedItem) {
            if (knownPostIds.add(item.post.id)) merged.add(item);
          } else if (item is BusinessOfferFeedItem) {
            if (knownOfferIds.add(item.offer.id)) merged.add(item);
          }
        }
        _items = merged;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasNext && page.items.isNotEmpty;
        _loadingMore = false;
      });
      if (_hasMore) _scheduleFillCheck();
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  /// Coming back from the post detail only re-reads that post (counts,
  /// reaction, deletion) so the loaded pages and the scroll position survive.
  Future<void> _refreshPost(String postId) async {
    if (!mounted) return;
    try {
      final fresh = await _service.getPost(postId);
      if (!mounted) return;
      setState(() {
        _mapPosts((p) {
          if (p.id == postId) return fresh;
          final original = p.originalPost;
          if (original?.id == postId) {
            return p.copyWith(
              originalPost: original!.copyWith(
                reactionSummary: fresh.reactionSummary,
                reactionCount: fresh.reactionCount,
                commentCount: fresh.commentCount,
                myReaction: fresh.myReaction,
                clearMyReaction: fresh.myReaction == null,
                shareCount: fresh.shareCount,
                sharedByMe: fresh.sharedByMe,
              ),
            );
          }
          return p;
        });
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (!mounted) return;
      // Deleted / no longer visible: drop it instead of leaving a dead card.
      if (code == 404 || code == 403) {
        setState(() {
          _filterPosts((p) => p.id != postId && p.originalPost?.id != postId);
        });
      }
    } catch (_) {
      // Offline or transient: keep what is on screen.
    }
  }

  Future<void> _toggleSave(WallPostModel post) async {
    if (!allowNetworkAction(context)) return;
    final next = !post.savedByMe;
    setState(() {
      _mapPosts((p) => p.id == post.id ? p.copyWith(savedByMe: next) : p);
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
        _mapPosts(
          (p) => p.id == post.id ? p.copyWith(savedByMe: post.savedByMe) : p,
        );
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
      _mapPosts((p) => p.id == postId ? p.copyWith(viewCount: count) : p);
    });
  }

  Future<void> _deletePost(String postId) async {
    await confirmAndDeletePublication(
      context: context,
      delete: () async {
        await _service.deleteOwnPost(postId);
        if (!mounted) return;
        setState(() => _filterPosts((p) => p.id != postId));
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
    _mapPosts((post) {
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
    });
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
        final rebuilt = [
          share,
          ..._posts.where((p) => p.id != share.id).map((p) =>
            p.id == target.id ? p.copyWith(shareCount: count, sharedByMe: true) :
            p.originalPost?.id == target.id ? p.copyWith(originalPost:
              p.originalPost!.copyWith(shareCount: count, sharedByMe: true)) : p),
        ];
        _setPostsKeepingOffers(rebuilt);
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compartido en Garra')));
    } else if (outcome.undoCount case final count?) {
      setState(() {
        final rebuilt = _posts
            .where((p) => !(p.originalPost?.id == target.id && p.isMine))
            .map((p) =>
              p.id == target.id ? p.copyWith(shareCount: count, sharedByMe: false) :
              p.originalPost?.id == target.id ? p.copyWith(originalPost:
                p.originalPost!.copyWith(shareCount: count, sharedByMe: false)) : p)
            .toList();
        _setPostsKeepingOffers(rebuilt);
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
    if (ok != true || !mounted) return;
    if (!allowNetworkAction(context)) return;
    try {
      await _service.blockUser(userId);
    } catch (_) {
      if (!mounted) return;
      _showError('No pudimos bloquear ahora. Int\u00e9ntalo de nuevo.');
      return;
    }
    if (!mounted) return;
    // The author disappears right away (also from wrappers of their posts);
    // no full reload, so the loaded pages and scroll position survive.
    setState(() {
      _filterPosts((p) => p.authorId != userId && p.originalPost?.authorId != userId);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Usuario bloqueado')));
  }

  void _reconcilePublishedPost(WallPostModel post) {
    ++_loadGeneration;
    setState(() {
      final original = post.originalPost;
      final rebuilt = [post, ..._posts.where((existing) => existing.id != post.id).map((existing) {
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
      _setPostsKeepingOffers(rebuilt);
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
        setState(() {
          final rebuilt = _posts.where((p) =>
            !(p.originalPost?.id == originalId && p.isMine)).map((p) {
            if (p.id == originalId) {
              return p.copyWith(shareCount: next.shareCount, sharedByMe: false);
            }
            if (p.originalPost?.id == originalId) {
              return p.copyWith(originalPost: p.originalPost!.copyWith(
                  shareCount: next.shareCount, sharedByMe: false));
            }
            return p;
          }).toList();
          _setPostsKeepingOffers(rebuilt);
        });
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
          if (_items.isEmpty) ...widget.contextualInserts,
          if (_loading && _items.isEmpty)
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
          else if (_error != null && _items.isEmpty)
            GarraErrorState(message: _error!, onRetry: _load)
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.lg),
              child: GarraEmptyState(
                title: widget.mode == 'FOLLOWING'
                    ? 'Tu Garra empieza aqu\u00ed.'
                    : 'Sé el primero en publicar',
                message: widget.mode == 'FOLLOWING'
                    ? 'Descubre hinchas para llenar tu inicio.'
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
            if (_loadingMore)
              const Padding(
                key: ValueKey('feed_loading_more'),
                padding: EdgeInsets.symmetric(vertical: GarraSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_moreFailed)
              Padding(
                key: const ValueKey('feed_more_error'),
                padding: const EdgeInsets.symmetric(
                  horizontal: GarraSpacing.lg,
                  vertical: GarraSpacing.sm,
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'No pudimos cargar m\u00e1s publicaciones.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.garraColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _loadMore,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
          ],
          // GARRA38: "Descubre en Garra" closes the feed (and fills the empty
          // state). Kept mounted (Offstage while the feed loads) so it
          // fetches once and never refetches on rebuild.
          Offstage(
            key: const ValueKey('garra_discovery_slot'),
            offstage: _loading && _items.isEmpty,
            child: GarraDiscoverySection(
              key: const ValueKey('garra_discovery'),
              excludePostIds: {
                for (final p in _posts) ...[p.id, ?p.originalPost?.id],
              },
              onFollowed: widget.mode == 'FOLLOWING' ? _load : null,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeedItems(String? meId) {
    final items = <Widget>[];
    var insertIndex = 0;
    var postIndex = 0;
    for (final entry in _items) {
      if (entry is BusinessOfferFeedItem) {
        items.add(
          GarraTribunaOfferCard(
            key: ValueKey('tribuna_offer_${entry.offer.id}'),
            offer: entry.offer,
          ),
        );
        continue;
      }
      if (entry is! CommunityPostFeedItem) continue;
      final post = entry.post;
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
                () => context.push('/muro-crema/posts/${post.originalPost!.id}').then((_) => _refreshPost(post.originalPost!.id)),
            onOpen: () => context
                .push('/muro-crema/posts/${post.originalPost?.id ?? post.id}')
                .then((_) => _refreshPost(post.originalPost?.id ?? post.id)),
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
                .then((_) => _refreshPost(post.originalPost?.id ?? post.id)),
          ),
        ),
      );

      final shouldInsert = postIndex == 1 || (postIndex > 1 && (postIndex - 1) % 4 == 0);
      if (shouldInsert && insertIndex < widget.contextualInserts.length) {
        items.add(widget.contextualInserts[insertIndex]);
        insertIndex++;
      }
      postIndex++;
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
          // Capped so the pill ellipsizes (instead of overflowing) on 220 px screens.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (MediaQuery.sizeOf(context).width -
                      2 * GarraSpacing.lg -
                      GarraSpacing.sm)
                  .clamp(0.0, double.infinity),
            ),
            child: const GarraEditorialEyebrow(
              label: 'La tribuna crema',
              icon: Icons.local_fire_department_outlined,
            ),
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
