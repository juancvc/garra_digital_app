import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/auth/current_fan_provider.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/engagement_utils.dart';
import '../data/reaction_type.dart';
import '../data/wall_comment_model.dart';
import '../data/wall_post_model.dart';
import 'providers/community_provider.dart';
import 'widgets/garra_comment_reactions.dart';
import 'widgets/garra_comment_tile.dart';
import 'widgets/garra_post_media_grid.dart';
import 'widgets/garra_reaction_bar.dart';
import 'widgets/garra_reaction_picker.dart';
import 'widgets/garra_share_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  WallPostModel? _post;
  Object? _postError;
  bool _loadingPost = true;

  final List<WallCommentModel> _comments = [];
  String? _nextCursor;
  bool _hasNext = false;
  bool _loadingComments = true;
  bool _loadingMore = false;
  Object? _commentsError;

  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  bool _sendingComment = false;
  bool _reacting = false;

  /// In-flight guards per comment id (no duplicate requests on double tap).
  final Set<String> _reactingComments = {};
  final Set<String> _deletingComments = {};

  /// Reply threads keyed by root comment id (one level deep).
  final Map<String, _ReplyThread> _threads = {};

  /// Comment being answered (root or reply); null = normal comment mode.
  WallCommentModel? _replyTarget;

  static const int _maxCommentLength = 280;
  static const String _commentGoneMessage =
      'Este comentario ya no est\u00e1 disponible.';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPost(), _loadComments(reset: true)]);
  }

  Future<void> _loadPost() async {
    setState(() {
      _loadingPost = true;
      _postError = null;
    });

    try {
      final post = await ref
          .read(communityServiceProvider)
          .getPost(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _loadingPost = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postError = e;
        _loadingPost = false;
      });
    }
  }

  Future<void> _loadComments({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loadingComments = true;
        _commentsError = null;
        _comments.clear();
        _threads.clear();
        _replyTarget = null;
        _nextCursor = null;
        _hasNext = false;
      });
    } else {
      if (_loadingMore || !_hasNext) return;
      setState(() => _loadingMore = true);
    }

    try {
      final page = await ref
          .read(communityServiceProvider)
          .listComments(
            postId: widget.postId,
            cursor: reset ? null : _nextCursor,
          );
      if (!mounted) return;
      setState(() {
        _comments.addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
        _loadingComments = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commentsError = e;
        _loadingComments = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _onReact() async {
    final post = _post;
    if (post == null || _reacting) return;

    final selected = await showGarraReactionPicker(
      context,
      currentReaction: post.myReaction,
    );
    if (selected == null || !mounted) return;

    final previous = post;
    final same =
        post.myReaction != null &&
        post.myReaction!.toUpperCase() == selected.apiValue;
    final optimistic = applyOptimisticReaction(
      post,
      same ? null : selected.apiValue,
    );

    setState(() {
      _post = optimistic;
      _reacting = true;
    });

    final service = ref.read(communityServiceProvider);
    final result = same
        ? await service.removeReaction(post.id)
        : await service.upsertReaction(
            postId: post.id,
            type: selected.apiValue,
          );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _post = previous;
        _reacting = false;
      });
      _showSnack(
        'No se pudo actualizar la reacción. Inténtalo de nuevo.',
        isError: true,
      );
      return;
    }

    setState(() {
      if (result.reactionSummary != null && result.reactionCount != null) {
        _post = applyReactionResponse(
          post: optimistic,
          myReaction: result.myReaction,
          reactionSummary: result.reactionSummary!,
          reactionCount: result.reactionCount!,
        );
      }
      _reacting = false;
    });
  }

  Future<void> _sendComment() async {
    if (_sendingComment) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      _showSnack('Escribe un comentario antes de enviar.', isError: true);
      return;
    }
    if (content.length > _maxCommentLength) {
      _showSnack(
        'El comentario no puede superar $_maxCommentLength caracteres.',
        isError: true,
      );
      return;
    }

    final target = _replyTarget;
    if (target != null) {
      await _sendReply(target, content);
      return;
    }

    setState(() => _sendingComment = true);
    final result = await ref
        .read(communityServiceProvider)
        .createComment(postId: widget.postId, content: content);

    if (!mounted) return;

    if (!result.success) {
      setState(() => _sendingComment = false);
      _showSnack(result.message, isError: true);
      return;
    }

    _commentController.clear();
    final created = result.comment;
    setState(() {
      _sendingComment = false;
      if (created != null) {
        _comments.insert(0, created);
      }
      if (_post != null) {
        _post = _post!.copyWith(commentCount: _post!.commentCount + 1);
      }
    });

    if (created == null) {
      await _loadComments(reset: true);
    }

    _showSnack(result.message);
  }

  /// Sends a reply to [target]; the backend resolves the thread root and the
  /// "@usuario" target when [target] is itself a reply.
  Future<void> _sendReply(WallCommentModel target, String content) async {
    setState(() => _sendingComment = true);
    final result = await ref
        .read(communityServiceProvider)
        .createReply(
          postId: widget.postId,
          parentCommentId: target.id,
          content: content,
        );
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _sendingComment = false;
        if (result.notFound) {
          _replyTarget = null;
          _removeCommentLocally(target.id);
        }
      });
      _showSnack(result.message, isError: true);
      return;
    }

    _commentController.clear();
    final created = result.comment;
    final rootId =
        created?.parentCommentId ?? target.parentCommentId ?? target.id;
    var needsLoad = false;
    setState(() {
      _sendingComment = false;
      _replyTarget = null;
      if (_post != null) {
        _post = _post!.copyWith(commentCount: _post!.commentCount + 1);
      }
      final rootIndex = _commentIndex(rootId);
      final hadReplies = rootIndex >= 0 && _comments[rootIndex].replyCount > 0;
      if (rootIndex >= 0) {
        final root = _comments[rootIndex];
        _comments[rootIndex] = root.copyWith(replyCount: root.replyCount + 1);
      }
      final thread = _threads.putIfAbsent(rootId, _ReplyThread.new);
      thread.expanded = true;
      if (created != null && (thread.loaded || !hadReplies)) {
        if (!thread.replies.any((r) => r.id == created.id)) {
          thread.replies.add(created);
        }
        thread.loaded = true;
      } else {
        needsLoad = true;
      }
    });
    if (needsLoad) await _loadReplies(rootId);
    if (mounted) _showSnack(result.message);
  }

  void _startReply(WallCommentModel comment) {
    setState(() => _replyTarget = comment);
    _commentFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyTarget = null);
  }

  void _toggleReplies(String rootId) {
    final thread = _threads[rootId];
    if (thread != null && thread.expanded) {
      setState(() => thread.expanded = false);
      return;
    }
    if (thread != null && thread.loaded && thread.error == null) {
      setState(() => thread.expanded = true);
      return;
    }
    _loadReplies(rootId);
  }

  Future<void> _loadReplies(String rootId, {bool more = false}) async {
    final thread = _threads.putIfAbsent(rootId, _ReplyThread.new);
    if (thread.loading || thread.loadingMore) return;
    if (more && !thread.hasNext) return;
    setState(() {
      thread.expanded = true;
      thread.error = null;
      if (more) {
        thread.loadingMore = true;
      } else {
        thread.loading = true;
      }
    });

    try {
      final page = await ref
          .read(communityServiceProvider)
          .fetchReplies(
            commentId: rootId,
            cursor: more ? thread.nextCursor : null,
          );
      if (!mounted) return;
      setState(() {
        if (!more) thread.replies.clear();
        final known = thread.replies.map((r) => r.id).toSet();
        thread.replies.addAll(page.items.where((r) => !known.contains(r.id)));
        thread.nextCursor = page.nextCursor;
        thread.hasNext = page.hasNext;
        thread.loaded = true;
        thread.loading = false;
        thread.loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      final gone = e is DioException && e.response?.statusCode == 404;
      setState(() {
        thread.loading = false;
        thread.loadingMore = false;
        if (gone) {
          _removeCommentLocally(rootId);
        } else {
          thread.error = e;
        }
      });
      if (gone) _showSnack(_commentGoneMessage, isError: true);
    }
  }

  /// Finds a comment in the root list or in any loaded reply thread.
  WallCommentModel? _findComment(String id) {
    final index = _commentIndex(id);
    if (index >= 0) return _comments[index];
    for (final thread in _threads.values) {
      for (final reply in thread.replies) {
        if (reply.id == id) return reply;
      }
    }
    return null;
  }

  /// Replaces a comment wherever it lives. Call inside setState.
  void _replaceComment(
    String id,
    WallCommentModel Function(WallCommentModel current) update,
  ) {
    final index = _commentIndex(id);
    if (index >= 0) {
      _comments[index] = update(_comments[index]);
      return;
    }
    for (final thread in _threads.values) {
      final replyIndex = thread.replies.indexWhere((r) => r.id == id);
      if (replyIndex >= 0) {
        thread.replies[replyIndex] = update(thread.replies[replyIndex]);
        return;
      }
    }
  }

  /// Removes a root (with its thread, hidden by the backend too) or a reply
  /// and fixes replyCount / commentCount. Call inside setState.
  void _removeCommentLocally(String id) {
    if (_replyTarget != null &&
        (_replyTarget!.id == id || _replyTarget!.parentCommentId == id)) {
      _replyTarget = null;
    }
    final index = _commentIndex(id);
    if (index >= 0) {
      final root = _comments.removeAt(index);
      final thread = _threads.remove(id);
      final loaded = thread?.replies.length ?? 0;
      _decrementCommentCount(
        1 + (root.replyCount > loaded ? root.replyCount : loaded),
      );
      return;
    }
    for (final entry in _threads.entries) {
      final replyIndex = entry.value.replies.indexWhere((r) => r.id == id);
      if (replyIndex < 0) continue;
      entry.value.replies.removeAt(replyIndex);
      final rootIndex = _commentIndex(entry.key);
      if (rootIndex >= 0) {
        final root = _comments[rootIndex];
        _comments[rootIndex] = root.copyWith(
          replyCount: root.replyCount > 0 ? root.replyCount - 1 : 0,
        );
      }
      _decrementCommentCount(1);
      return;
    }
  }

  void _decrementCommentCount(int by) {
    if (_post == null) return;
    final next = _post!.commentCount - by;
    _post = _post!.copyWith(commentCount: next < 0 ? 0 : next);
  }

  /// PostCommentResponse has no `isMine`: ownership comes from `authorId`
  /// matched against the session fan id (GET /auth/me `id`).
  bool _ownsComment(WallCommentModel comment) {
    if (comment.isMine) return true;
    return isSameFanId(currentFanIdOf(ref), comment.authorId);
  }

  int _commentIndex(String commentId) {
    return _comments.indexWhere((c) => c.id == commentId);
  }

  Future<void> _editComment(WallCommentModel comment) async {
    final saved = await showEditCommentSheet(
      context,
      initialText: comment.content,
      onSubmit: (content) async {
        final result = await ref
            .read(communityServiceProvider)
            .editComment(commentId: comment.id, content: content);
        if (!mounted) return null;
        if (!result.success) return result.message;
        final server = result.comment;
        setState(() {
          _replaceComment(
            comment.id,
            (current) => current.copyWith(
              content: server != null && server.content.isNotEmpty
                  ? server.content
                  : content,
              editedAt:
                  server?.editedAt ?? DateTime.now().toUtc().toIso8601String(),
              updatedAt: server?.updatedAt,
            ),
          );
        });
        return null;
      },
    );
    if (saved == true && mounted) {
      _showSnack('Comentario actualizado');
    }
  }

  Future<void> _deleteComment(WallCommentModel comment) async {
    if (_deletingComments.contains(comment.id)) return;
    final confirmed = await confirmDeleteComment(context);
    if (!confirmed || !mounted) return;
    _deletingComments.add(comment.id);
    final result = await ref
        .read(communityServiceProvider)
        .deleteComment(comment.id);
    _deletingComments.remove(comment.id);
    if (!mounted) return;
    if (!result.success) {
      if (result.notFound) {
        setState(() => _removeCommentLocally(comment.id));
      }
      _showSnack(result.message, isError: true);
      return;
    }
    setState(() => _removeCommentLocally(comment.id));
    _showSnack(result.message);
  }

  Future<void> _openCommentReactions(WallCommentModel comment) async {
    if (_reactingComments.contains(comment.id)) return;
    final selected = await showCommentReactionPicker(
      context,
      currentReaction: comment.myReaction,
    );
    if (selected == null || !mounted) return;
    final current = _findComment(comment.id);
    if (current == null) return;
    await _reactToComment(current, selected);
  }

  Future<void> _reactToComment(
    WallCommentModel comment,
    ReactionType type,
  ) async {
    if (_reactingComments.contains(comment.id)) return;
    final previous = comment;
    final remove = comment.myReaction?.toUpperCase() == type.apiValue;
    final optimistic = applyOptimisticCommentReaction(
      comment,
      remove ? null : type.apiValue,
    );
    if (_findComment(comment.id) == null) return;

    setState(() {
      _reactingComments.add(comment.id);
      _replaceComment(comment.id, (_) => optimistic);
    });

    final service = ref.read(communityServiceProvider);
    final result = remove
        ? await service.removeCommentReaction(comment.id)
        : await service.upsertCommentReaction(
            commentId: comment.id,
            type: type.apiValue,
          );
    if (!mounted) return;

    setState(() {
      _reactingComments.remove(comment.id);
      if (!result.success) {
        // Roll back only the reaction fields (keeps any concurrent edit).
        _replaceComment(
          comment.id,
          (current) => current.copyWith(
            myReaction: previous.myReaction,
            clearMyReaction: previous.myReaction == null,
            reactionSummary: previous.reactionSummary,
            reactionCount: previous.reactionCount,
          ),
        );
      } else if (result.reactionSummary != null &&
          result.reactionCount != null) {
        _replaceComment(
          comment.id,
          (current) => applyCommentReactionResponse(
            comment: current,
            myReaction: result.myReaction,
            reactionSummary: result.reactionSummary!,
            reactionCount: result.reactionCount!,
          ),
        );
      }
    });
    if (!result.success) {
      _showSnack(result.message, isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(GarraColors.danger)
            : const Color(GarraColors.success),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicación'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/muro-crema');
            }
          },
        ),
        actions: [
          if (_post != null)
            IconButton(
              tooltip: _post!.savedByMe ? 'Quitar guardado' : 'Guardar',
              icon: Icon(
                _post!.savedByMe ? Icons.bookmark : Icons.bookmark_border,
              ),
              onPressed: () async {
                HapticFeedback.lightImpact();
                final svc = ref.read(communityServiceProvider);
                if (_post!.savedByMe) {
                  await svc.unsavePost(_post!.id);
                } else {
                  await svc.savePost(_post!.id);
                }
                await _loadPost();
              },
            ),
          if (_post != null && _ownsPost(_post!))
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Eliminar esta publicación?'),
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
                  if (ok == true) {
                    await ref
                        .read(communityServiceProvider)
                        .deleteOwnPost(_post!.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Publicación eliminada')),
                      );
                      context.pop(true);
                    }
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Eliminar publicación'),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  void _focusComposer() {
    _commentFocus.requestFocus();
  }

  Future<void> _openShareSheet(WallPostModel post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SharePostSheet(post: post),
    );
  }

  bool _ownsPost(WallPostModel post) {
    if (post.isMine) return true;
    return isSameFanId(currentFanIdOf(ref), post.authorId);
  }

  Widget _buildBody() {
    if (_loadingPost) {
      return const Padding(
        padding: EdgeInsets.all(GarraSpacing.lg),
        child: Column(
          children: [
            GarraSkeleton(height: 120),
            SizedBox(height: GarraSpacing.lg),
            GarraSkeleton(height: 80),
            SizedBox(height: GarraSpacing.lg),
            GarraSkeleton(height: 80),
          ],
        ),
      );
    }

    if (_postError != null || _post == null) {
      final isMembershipLost =
          _postError is DioException &&
          (_postError as DioException).response?.statusCode == 403;
      if (isMembershipLost) {
        return const Padding(
          padding: EdgeInsets.all(GarraSpacing.xl),
          child: GarraEmptyState(
            title: 'Acceso restringido',
            message:
                'Ya no perteneces a este clan. Solo los miembros activos pueden ver este contenido.',
          ),
        );
      }
      return GarraErrorState(
        title: 'No pudimos cargar la publicación',
        message: 'Revisa tu conexión e inténtalo de nuevo.',
        onRetry: _loadAll,
      );
    }

    final post = _post!;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: const Color(GarraColors.gold),
            onRefresh: _loadAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.lg,
                GarraSpacing.md,
                GarraSpacing.lg,
                GarraSpacing.lg,
              ),
              children: [
                _PostHeader(post: post),
                const SizedBox(height: GarraSpacing.md),
                Text(
                  post.content,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.garraColors.textPrimary,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((post.imageUrl != null && post.imageUrl!.isNotEmpty) ||
                    post.media.isNotEmpty) ...[
                  const SizedBox(height: GarraSpacing.md),
                  GarraPostMediaGrid(
                    media: post.media,
                    legacyImageUrl: post.imageUrl,
                  ),
                ],
                const SizedBox(height: GarraSpacing.lg),
                GarraReactionBar(
                  reactionSummary: post.reactionSummary,
                  reactionCount: post.reactionCount,
                  commentCount: post.commentCount,
                  myReaction: post.myReaction,
                  onTapReactions: _onReact,
                  onTapComments: _focusComposer,
                ),
                const SizedBox(height: GarraSpacing.sm),
                _PostActionRow(
                  myReaction: post.myReaction,
                  reacting: _reacting,
                  onReact: _onReact,
                  onComment: _focusComposer,
                  onShare: () => _openShareSheet(post),
                ),
                const SizedBox(height: GarraSpacing.xl),
                Text(
                  'Comentarios',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: GarraSpacing.md),
                _buildCommentsSection(),
              ],
            ),
          ),
        ),
        _CommentComposer(
          controller: _commentController,
          focusNode: _commentFocus,
          sending: _sendingComment,
          maxLength: _maxCommentLength,
          onSend: _sendComment,
          replyingTo: _replyTarget?.username,
          onCancelReply: _cancelReply,
        ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    if (_loadingComments) {
      return const Column(
        children: [
          GarraSkeleton(height: 64),
          SizedBox(height: GarraSpacing.sm),
          GarraSkeleton(height: 64),
        ],
      );
    }

    if (_commentsError != null) {
      return GarraErrorState(
        title: 'No pudimos cargar los comentarios',
        message: 'Inténtalo de nuevo.',
        onRetry: () => _loadComments(reset: true),
      );
    }

    if (_comments.isEmpty) {
      return const GarraEmptyState(
        title: 'Aún no hay comentarios',
        message: 'Sé el primero en comentar esta arenga.',
      );
    }

    return Column(
      children: [
        ..._comments.map(
          (comment) => Padding(
            padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildCommentTile(comment), _buildReplies(comment)],
            ),
          ),
        ),
        if (_hasNext)
          Padding(
            padding: const EdgeInsets.only(top: GarraSpacing.sm),
            child: GarraSecondaryButton(
              label: _loadingMore ? 'Cargando...' : 'Cargar más',
              onPressed: _loadingMore ? null : () => _loadComments(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentTile(WallCommentModel comment) {
    return GarraCommentTile(
      comment: comment,
      isOwn: _ownsComment(comment),
      onEdit: () => _editComment(comment),
      onDelete: () => _deleteComment(comment),
      onReact: () => _openCommentReactions(comment),
      onReply: () => _startReply(comment),
      reacting: _reactingComments.contains(comment.id),
    );
  }

  /// "Ver N respuestas" toggle and the one-level reply thread of [root].
  Widget _buildReplies(WallCommentModel root) {
    final thread = _threads[root.id];
    final count = root.replyCount;
    if (count <= 0 && (thread == null || thread.replies.isEmpty)) {
      return const SizedBox.shrink();
    }
    final colors = context.garraColors;
    final textTheme = Theme.of(context).textTheme;
    final linkStyle = textTheme.labelMedium?.copyWith(
      color: colors.brandPrimary,
      fontWeight: FontWeight.w800,
    );
    Widget link(String key, String label, VoidCallback onTap) {
      return InkWell(
        key: ValueKey(key),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(label, style: linkStyle),
        ),
      );
    }

    Widget spinner(String key) {
      return Padding(
        key: ValueKey(key),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final children = <Widget>[];
    if (thread == null || !thread.expanded) {
      children.add(
        link(
          'replies_toggle_${root.id}',
          count == 1 ? 'Ver 1 respuesta' : 'Ver $count respuestas',
          () => _toggleReplies(root.id),
        ),
      );
    } else if (thread.loading) {
      children.add(spinner('replies_loading_${root.id}'));
    } else if (thread.error != null) {
      children.add(
        Row(
          children: [
            Flexible(
              child: Text(
                'No pudimos cargar las respuestas.',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: GarraSpacing.sm),
            link(
              'replies_retry_${root.id}',
              'Reintentar',
              () => _loadReplies(root.id),
            ),
          ],
        ),
      );
    } else {
      children.addAll(thread.replies.map(_buildCommentTile));
      if (thread.hasNext) {
        children.add(
          thread.loadingMore
              ? spinner('replies_loading_more_${root.id}')
              : link(
                  'replies_more_${root.id}',
                  'Ver m\u00e1s respuestas',
                  () => _loadReplies(root.id, more: true),
                ),
        );
      }
      children.add(
        link(
          'replies_toggle_${root.id}',
          'Ocultar respuestas',
          () => _toggleReplies(root.id),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Local state of one reply thread (replies are one level deep).
class _ReplyThread {
  final List<WallCommentModel> replies = [];
  bool expanded = false;
  bool loaded = false;
  bool loading = false;
  bool loadingMore = false;
  Object? error;
  String? nextCursor;
  bool hasNext = false;
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post});

  final WallPostModel post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(GarraColors.garnet),
          child: Text(
            post.username.isNotEmpty ? post.username[0].toUpperCase() : 'U',
            style: const TextStyle(
              color: Color(GarraColors.cream),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: GarraSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.fullName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                '@${post.username}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.garraColors.textSecondary,
                ),
              ),
              Text(
                _safeFormat(post.createdAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Reaccionar | Comentar | Compartir. No share counter: the backend does
/// not expose shareCount yet.
class _PostActionRow extends StatelessWidget {
  const _PostActionRow({
    required this.myReaction,
    required this.reacting,
    required this.onReact,
    required this.onComment,
    required this.onShare,
  });

  final String? myReaction;
  final bool reacting;
  final VoidCallback onReact;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? colors.brandPrestige : colors.brandPrimary;
    final reacted = myReaction != null;
    return DecoratedBox(
      key: const ValueKey('post_action_row'),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PostActionButton(
              key: const ValueKey('reaction_cta'),
              icon: reacted
                  ? Text(
                      ReactionType.emojiFor(myReaction!),
                      style: const TextStyle(fontSize: 16),
                    )
                  : Icon(Icons.add_reaction_outlined, size: 20, color: accent),
              label: reacted
                  ? ReactionType.labelFor(myReaction!)
                  : 'Reaccionar',
              color: reacted ? accent : colors.textSecondary,
              onPressed: reacting ? null : onReact,
            ),
          ),
          Expanded(
            child: _PostActionButton(
              key: const ValueKey('post_action_comment'),
              icon: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
                color: accent,
              ),
              label: 'Comentar',
              color: colors.textSecondary,
              onPressed: onComment,
            ),
          ),
          Expanded(
            child: _PostActionButton(
              key: const ValueKey('post_action_share'),
              icon: Icon(Icons.ios_share_rounded, size: 20, color: accent),
              label: 'Compartir',
              color: colors.textSecondary,
              onPressed: onShare,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostActionButton extends StatelessWidget {
  const _PostActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.maxLength,
    required this.onSend,
    this.replyingTo,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final int maxLength;
  final VoidCallback onSend;

  /// Username being answered; null = normal comment mode.
  final String? replyingTo;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.md,
            GarraSpacing.sm,
            GarraSpacing.md,
            GarraSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (replyingTo != null)
                Padding(
                  key: const ValueKey('reply_mode_bar'),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Respondiendo a @$replyingTo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          key: const ValueKey('reply_cancel'),
                          tooltip: 'Cancelar respuesta',
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          onPressed: sending ? null : onCancelReply,
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('comment_composer'),
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !sending,
                      maxLength: maxLength,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: replyingTo != null
                            ? 'Responder a @$replyingTo...'
                            : 'Escribe un comentario...',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: GarraSpacing.sm),
                  IconButton.filled(
                    key: const ValueKey('comment_send'),
                    onPressed: sending ? null : onSend,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.brandPrimary,
                      foregroundColor: colors.onBrand,
                    ),
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _safeFormat(String iso) {
  try {
    return formatDateTime(iso);
  } catch (_) {
    return iso;
  }
}

class _SharePostSheet extends StatefulWidget {
  const _SharePostSheet({required this.post});

  final WallPostModel post;

  @override
  State<_SharePostSheet> createState() => _SharePostSheetState();
}

class _SharePostSheetState extends State<_SharePostSheet> {
  GarraShareCardStyle _style = GarraShareCardStyle.nocheGarra;
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  String get _shareText {
    final post = widget.post;
    return '@${post.username}: ${post.content}\n\n— vía Garra Digital';
  }

  Future<void> _shareTextOnly() async {
    await Share.share(_shareText);
  }

  Future<void> _shareWithImage() async {
    final url = widget.post.imageUrl;
    if (url == null || url.isEmpty) {
      await _shareTextOnly();
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = bytes.data;
      if (data == null) {
        await _shareTextOnly();
        return;
      }
      final dir = await Directory.systemTemp.createTemp('garra_share');
      final file = File('${dir.path}/post.jpg');
      await file.writeAsBytes(data);
      await Share.shareXFiles([XFile(file.path)], text: _shareText);
    } catch (_) {
      await _shareTextOnly();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareCard() async {
    setState(() => _busy = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await shareGarraCardPng(boundaryKey: _boundaryKey, text: _shareText);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Compartir',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.garraColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _shareTextOnly,
                icon: const Icon(Icons.text_snippet_outlined),
                label: const Text('Compartir texto'),
              ),
              const SizedBox(height: 8),
              if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _shareWithImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Compartir con foto'),
                ),
              const SizedBox(height: 16),
              Text(
                'Garra Share Card',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.garraColors.brandPrestige,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final style in GarraShareCardStyle.values)
                    ChoiceChip(
                      label: Text(switch (style) {
                        GarraShareCardStyle.nocheGarra => 'Noche Garra',
                        GarraShareCardStyle.cremaClasico => 'Crema Clásico',
                        GarraShareCardStyle.borgona => 'Borgoña',
                      }),
                      selected: _style == style,
                      onSelected: (_) => setState(() => _style = style),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: GarraShareCard(
                    username: post.username,
                    content: post.content,
                    style: _style,
                    dateLabel: _safeFormat(post.createdAt),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _shareCard,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(GarraColors.gold),
                  foregroundColor: const Color(GarraColors.charcoal),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_rounded),
                label: const Text('Compartir tarjeta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
