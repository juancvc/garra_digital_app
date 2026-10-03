import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/current_fan_provider.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/community_report.dart';
import '../data/community_service.dart';
import '../data/engagement_utils.dart';
import '../data/garra_view_tracker.dart';
import '../data/wall_post_model.dart';
import 'providers/community_provider.dart';
import 'widgets/garra_discovery_section.dart';
import 'widgets/garra_report_sheet.dart';
import 'widgets/garra_social_post_card.dart';
import 'widgets/garra_share_sheet.dart';
import 'widgets/garra_reaction_actions.dart';
import 'widgets/garra_viewport_tracker.dart';
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
  final Set<String> _reactingPostIds = {};
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
      if (!mounted) return;
      setState(() {
        _posts = posts;
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
            .map((p) =>
                p.id == post.id ? p.copyWith(savedByMe: post.savedByMe) : p)
            .toList();
      });
    }
  }

  Future<void> _react(WallPostModel card, {bool change = false}) async {
    final post = card.originalPost?.asPost() ?? card;
    if (_reactingPostIds.contains(post.id)) return;
    setState(() => _reactingPostIds.add(post.id));
    final intent = await resolveReactionTap(context,
        current: post.myReaction, forcePicker: change);
    if (!mounted) return;
    if (intent == null || !allowNetworkAction(context)) {
      setState(() => _reactingPostIds.remove(post.id));
      return;
    }
    final optimistic = applyOptimisticReaction(post, intent.apiValue);
    void replace(WallPostModel value) {
      _posts = _posts.map((item) {
        if (item.id == value.id) return value;
        if (item.originalPost?.id == value.id) {
          return item.copyWith(originalPost: item.originalPost!.copyWith(
            reactionSummary: value.reactionSummary,
            reactionCount: value.reactionCount,
            myReaction: value.myReaction,
            clearMyReaction: value.myReaction == null,
          ));
        }
        return item;
      }).toList();
    }
    setState(() => replace(optimistic));
    final result = intent.isRemove
        ? await _service.removeReaction(post.id)
        : await _service.upsertReaction(postId: post.id, type: intent.apiValue!);
    if (!mounted) return;
    setState(() {
      _reactingPostIds.remove(post.id);
      replace(!result.success ? post :
          result.reactionSummary != null && result.reactionCount != null
              ? applyReactionResponse(post: optimistic,
                  myReaction: result.myReaction,
                  reactionSummary: result.reactionSummary!,
                  reactionCount: result.reactionCount!)
              : optimistic);
    });
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reactionErrorMessage(intent))));
    }
  }

  /// ANALYTICS_12: card was >=50% visible for >=1s (someone else's post).
  Future<void> _onPostSeen(String postId) async {
    final count = await GarraViewTracker.instance.trackPostView(_service, postId);
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

  Future<void> _share(WallPostModel post) async {
    final target = post.originalPost?.asPost() ?? post;
    final outcome = await showGarraShareSheet(context, post: target, service: _service,
        allowInternalRepost: !post.isShare);
    if (!mounted || outcome == null) return;
    if (outcome.external) {
      await SharePlus.instance.share(ShareParams(
        text: '${target.fullName}: ${target.content}\n\nÚnete a Garra Digital'));
      return;
    }
    if (outcome.sharedPost case final share?) {
      final count = share.originalPost?.shareCount ?? target.shareCount;
      setState(() => _posts = [share, ..._posts.where((p) => p.id != share.id).map((p) =>
        p.id == target.id ? p.copyWith(shareCount: count, sharedByMe: true) :
        p.originalPost?.id == target.id ? p.copyWith(originalPost:
          p.originalPost!.copyWith(shareCount: count, sharedByMe: true)) : p)]);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compartido en Garra')));
    } else if (outcome.undoCount case final count?) {
      setState(() => _posts = _posts.where((p) => !(p.originalPost?.id == target.id && p.isMine)).map((p) =>
        p.id == target.id ? p.copyWith(shareCount: count, sharedByMe: false) :
        p.originalPost?.id == target.id ? p.copyWith(originalPost:
          p.originalPost!.copyWith(shareCount: count, sharedByMe: false)) : p).toList());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compartido eliminado')));
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
    ref.listen<CommunityFeedChange>(communityFeedRevisionProvider, (previous, next) {
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
      } else if (next.post case final created?) {
        final original = created.originalPost;
        setState(() => _posts = [created, ..._posts.where((p) => p.id != created.id).map((p) {
          if (original == null) return p;
          if (p.id == original.id) {
            return p.copyWith(shareCount: original.shareCount, sharedByMe: true);
          }
          if (p.originalPost?.id == original.id) {
            return p.copyWith(originalPost: p.originalPost!.copyWith(
                shareCount: original.shareCount, sharedByMe: true));
          }
          return p;
        })]);
      }
    });
    return Scaffold(
      backgroundColor: context.garraColors.background,
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
                      // GARRA38: one composite discovery section replaces the old raw
                      // 'Personas para seguir' list (people + communities + content).
                      if (_mode == 'FOLLOWING' && _posts.isEmpty)
                        GarraDiscoverySection(
                          key: const ValueKey('hub_discovery'),
                          onFollowed: _load,
                        ),
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
                          return GarraViewportTracker(
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
                              onOpenProfile: post.authorId == null ||
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
                                  : () => showGarraReportSheet(
                                        context,
                                        service: _service,
                                        target: GarraReportTarget.post,
                                        targetId: post.id,
                                      ),
                              onShare: () => _share(post),
                              onComment: () => context.push('/muro-crema/posts/${post.originalPost?.id ?? post.id}'),
                              onReact: () => _react(post),
                              onChangeReaction: () => _react(post, change: true),
                              onSave: () => _toggleSave(post),
                              onDelete: mine ? () => _deletePost(post.id) : null,
                            ),
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
