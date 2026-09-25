import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/auth/current_fan_provider.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/engagement_utils.dart';
import '../data/reaction_type.dart';
import '../data/wall_comment_model.dart';
import '../data/wall_post_model.dart';
import 'providers/community_provider.dart';
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
  bool _sendingComment = false;
  bool _reacting = false;

  static const int _maxCommentLength = 280;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _commentController.dispose();
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

  Future<void> _deleteComment(WallCommentModel comment) async {
    final result = await ref
        .read(communityServiceProvider)
        .deleteComment(comment.id);
    if (!mounted) return;
    if (!result.success) {
      _showSnack(result.message, isError: true);
      return;
    }
    setState(() {
      _comments.removeWhere((c) => c.id == comment.id);
      if (_post != null && _post!.commentCount > 0) {
        _post = _post!.copyWith(commentCount: _post!.commentCount - 1);
      }
    });
    _showSnack(result.message);
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
      backgroundColor: const Color(GarraColors.charcoal),
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
          if (_post != null)
            IconButton(
              tooltip: 'Compartir',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => _openShareSheet(_post!),
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

  Future<void> _openShareSheet(WallPostModel post) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(GarraColors.charcoal),
      isScrollControlled: true,
      builder: (ctx) => _SharePostSheet(post: post),
    );
  }

  bool _ownsPost(WallPostModel post) {
    if (post.isMine) return true;
    final meId = ref.watch(currentFanProvider).asData?.value?.id;
    return meId != null && meId.isNotEmpty && post.authorId == meId;
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
                    color: const Color(GarraColors.cream),
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
                  onTapComments: () {},
                ),
                const SizedBox(height: GarraSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('reaction_cta'),
                    onPressed: _reacting ? null : _onReact,
                    icon: Text(
                      post.myReaction != null
                          ? ReactionType.emojiFor(post.myReaction!)
                          : '🛡',
                    ),
                    label: Text(
                      post.myReaction != null
                          ? ReactionType.labelFor(post.myReaction!)
                          : 'Reaccionar',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(GarraColors.cream),
                      side: const BorderSide(color: Color(GarraColors.gold)),
                    ),
                  ),
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
          sending: _sendingComment,
          maxLength: _maxCommentLength,
          onSend: _sendComment,
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
            child: _CommentTile(
              comment: comment,
              onDelete: comment.isMine ? () => _deleteComment(comment) : null,
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
                  color: const Color(GarraColors.textSecondary),
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, this.onDelete});

  final WallCommentModel comment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GarraSpacing.md),
      decoration: BoxDecoration(
        color: const Color(GarraColors.surface),
        borderRadius: BorderRadius.circular(GarraRadius.lg),
        border: Border.all(color: const Color(GarraColors.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GarraAvatar(
            displayName: comment.fullName.isNotEmpty
                ? comment.fullName
                : comment.username,
            avatarUrl: comment.avatarUrl,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${comment.fullName.isNotEmpty ? comment.fullName : '@${comment.username}'} · ${formatGarraRelativeTime(comment.createdAt)}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Eliminar',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: const Color(GarraColors.gold),
                      ),
                  ],
                ),
                Text(
                  comment.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.sending,
    required this.maxLength,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final int maxLength;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(GarraColors.surface),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.md,
            GarraSpacing.sm,
            GarraSpacing.md,
            GarraSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('comment_composer'),
                  controller: controller,
                  enabled: !sending,
                  maxLength: maxLength,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Escribe un comentario...',
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
                  backgroundColor: const Color(GarraColors.gold),
                  foregroundColor: AppTheme.background,
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
                  color: const Color(GarraColors.cream),
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
                  color: const Color(GarraColors.gold),
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
