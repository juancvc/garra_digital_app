import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/current_fan_provider.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/navigation/draft_exit_guard.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../community/data/community_report.dart';
import '../../community/data/engagement_utils.dart';
import '../../community/data/garra_view_tracker.dart';
import '../../community/data/wall_post_model.dart';
import '../../community/presentation/post_detail_screen.dart'
    show PostDetailModeration;
import '../../community/presentation/providers/community_provider.dart';
import '../../community/presentation/widgets/garra_comment_tile.dart'
    show confirmHideClanPost;
import '../../community/presentation/widgets/garra_reaction_bar.dart';
import '../../community/presentation/widgets/garra_reaction_actions.dart';
import '../../community/presentation/widgets/garra_report_sheet.dart';
import '../../community/presentation/widgets/garra_viewport_tracker.dart';

import '../data/clan_admin_permissions.dart';
import '../data/clan_models.dart';
import '../data/clan_service.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import 'providers/clans_provider.dart';

/// Tribuna del Clan — member-only feed with composer.
class ClanTribunaPage extends ConsumerStatefulWidget {
  const ClanTribunaPage({
    super.key,
    required this.slug,
    this.clanName,
    this.embedded = false,
  });

  final String slug;
  final String? clanName;
  final bool embedded;

  @override
  ConsumerState<ClanTribunaPage> createState() => _ClanTribunaPageState();
}

class _ClanTribunaPageState extends ConsumerState<ClanTribunaPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _contentController = TextEditingController();
  final _media = MediaUploadService();
  bool _publishing = false;
  String? _photoAssetId;
  XFile? _selectedPhoto;
  bool _uploadingPhoto = false;
  final _exitGuard = DraftExitGuard();
  bool get _dirty => _contentController.text.trim().isNotEmpty ||
      _selectedPhoto != null || _photoAssetId != null;
  void _leave() => _exitGuard.leave(context, dirty: _dirty,
      busy: _publishing || _uploadingPhoto,
      refresh: () => setState(() {}), pop: () => Navigator.of(context).pop());

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onDraftChanged);
  }

  void _onDraftChanged() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _contentController.removeListener(_onDraftChanged);
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(clanFeedProvider(widget.slug));
    ref.invalidate(clanDetailProvider(widget.slug));
    try {
      await ref.read(clanFeedProvider(widget.slug).future);
    } catch (_) {}
  }

  Future<void> _addPhoto() async {
    final source = _selectedPhoto == null
        ? await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Elegir de galería'),
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                  ListTile(
                    title: const Text('Tomar foto'),
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ],
              ),
            ),
          )
        : null;
    if (_selectedPhoto == null && source == null) return;
    if (!mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final file =
          _selectedPhoto ??
          (source == ImageSource.camera
              ? await _media.pickCamera()
              : await _media.pickImage());
      if (file == null) {
        if (mounted) setState(() => _uploadingPhoto = false);
        return;
      }
      if (!mounted) return;
      if (!allowNetworkAction(context)) {
        setState(() {
          _selectedPhoto = file;
          _uploadingPhoto = false;
        });
        return;
      }
      setState(() => _selectedPhoto = file);
      final draft = await _media.uploadFile(
        file: file,
        purpose: MediaUploadPurpose.communityPost,
        canStartRemote: () => mounted && allowNetworkAction(context),
      );
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _photoAssetId = draft.isReady ? draft.assetId : null;
        if (draft.isReady) _selectedPhoto = null;
      });
      if (!draft.isReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos cargar la foto.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos cargar la foto.')),
      );
    }
  }

  Future<void> _publish(String clanName) async {
    if (!allowNetworkAction(context)) return;
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe algo antes de publicar.')),
      );
      return;
    }
    if (content.length > 220) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Máximo 220 caracteres.')));
      return;
    }

    setState(() => _publishing = true);
    try {
      await ref
          .read(clanServiceProvider)
          .createClanPost(
            widget.slug,
            CreateClanPostRequest(
              content: content,
              mediaAssetId: _photoAssetId,
            ),
          );
      _contentController.clear();
      _photoAssetId = null;
      _selectedPhoto = null;
      ref.invalidate(clanFeedProvider(widget.slug));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Publicado en $clanName')));
      }
    } on ClanMembershipLostException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on ClanServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo publicar. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final clanAsync = ref.watch(clanDetailProvider(widget.slug));
    final feedAsync = ref.watch(clanFeedProvider(widget.slug));

    final body = clanAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          color: context.garraColors.brandPrestige,
        ),
      ),
      error: (error, _) {
        if (error is ClanMembershipLostException) {
          return _MembershipLostBody(message: error.message);
        }
        return GarraErrorState(onRetry: _refresh);
      },
      data: (clan) {
        if (!clan.isMember) {
          return const _MembershipLostBody(
            message:
                'La Tribuna del Clan es solo para miembros activos. Únete para participar.',
          );
        }
        final name = widget.clanName ?? clan.name;
        final canModerate = ClanAdminPermissions.canModerateContent(
          clan.myMembership?.role,
        );
        return RefreshIndicator(
          color: context.garraColors.brandPrestige,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.md,
              GarraSpacing.lg,
              GarraSpacing.section,
            ),
            children: [
              _ClanComposer(
                clanName: name,
                controller: _contentController,
                publishing: _publishing,
                uploadingPhoto: _uploadingPhoto,
                hasPhoto: _photoAssetId != null,
                hasPendingPhoto: _selectedPhoto != null,
                onPublish: () => _publish(name),
                onAddPhoto: _addPhoto,
              ),
              const SizedBox(height: GarraSpacing.lg),
              feedAsync.when(
                loading: () => Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.garraColors.brandPrestige,
                    ),
                  ),
                ),
                error: (error, _) {
                  if (error is ClanMembershipLostException) {
                    return _MembershipLostBody(message: error.message);
                  }
                  return GarraErrorState(onRetry: _refresh);
                },
                data: (posts) {
                  if (posts.isEmpty) {
                    return const GarraEmptyState(
                      title: 'Tribuna en silencio',
                      message:
                          'Sé el primero en publicar una arenga para tu clan.',
                    );
                  }
                  return Column(
                    children: posts
                        .map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: GarraSpacing.md,
                            ),
                            child: _ClanFeedPostCard(
                              post: post,
                              clanSlug: widget.slug,
                              canModerate: canModerate,
                              onHidden: () =>
                                  ref.invalidate(clanFeedProvider(widget.slug)),
                              onOpenDetail: () => context.push(
                                '/muro-crema/posts/${post.id}',
                                extra: canModerate
                                    ? PostDetailModeration(
                                        clanSlug: widget.slug,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    return PopScope(
      canPop: _exitGuard.canPop(dirty: _dirty,
          busy: _publishing || _uploadingPhoto),
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _leave(); },
      child: widget.embedded ? body : Scaffold(
      backgroundColor: context.garraColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: Text(
          clanAsync.asData != null
              ? 'Tribuna · ${clanAsync.asData!.value.name}'
              : 'Tribuna del Clan',
        ),
      ),
      body: body,
    ));
  }
}

class _ClanComposer extends StatelessWidget {
  const _ClanComposer({
    required this.clanName,
    required this.controller,
    required this.publishing,
    required this.uploadingPhoto,
    required this.hasPhoto,
    required this.hasPendingPhoto,
    required this.onPublish,
    required this.onAddPhoto,
  });

  final String clanName;
  final TextEditingController controller;
  final bool publishing;
  final bool uploadingPhoto;
  final bool hasPhoto;
  final bool hasPendingPhoto;
  final VoidCallback onPublish;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué quieres compartir?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GarraSpacing.sm),
          TextField(
            controller: controller,
            maxLength: 220,
            maxLines: 3,
            decoration: InputDecoration(hintText: 'Escribe en $clanName'),
          ),
          const SizedBox(height: GarraSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: publishing || uploadingPhoto ? null : onAddPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  uploadingPhoto
                      ? 'Subiendo…'
                      : hasPendingPhoto
                      ? 'Subir foto seleccionada'
                      : hasPhoto
                      ? 'Foto lista'
                      : 'Agregar foto',
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
                onPressed: publishing || hasPendingPhoto ? null : onPublish,
                child: Text(publishing ? 'Publicando…' : 'Publicar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClanFeedPostCard extends ConsumerStatefulWidget {
  const _ClanFeedPostCard({
    required this.post,
    required this.onOpenDetail,
    required this.clanSlug,
    this.canModerate = false,
    this.onHidden,
  });

  final WallPostModel post;
  final VoidCallback onOpenDetail;
  final String clanSlug;

  /// OWNER/ADMIN/MODERATOR of this clan: "Ocultar publicación".
  final bool canModerate;
  final VoidCallback? onHidden;

  @override
  ConsumerState<_ClanFeedPostCard> createState() => _ClanFeedPostCardState();
}

class _ClanFeedPostCardState extends ConsumerState<_ClanFeedPostCard> {
  late WallPostModel _post;
  bool _reacting = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(covariant _ClanFeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.reactionCount != widget.post.reactionCount ||
        oldWidget.post.myReaction != widget.post.myReaction) {
      _post = widget.post;
    }
  }

  Future<void> _react({bool change = false}) async {
    if (_reacting) return;
    final intent = await resolveReactionTap(
      context,
      current: _post.myReaction,
      forcePicker: change,
    );
    if (intent == null || !mounted) return;
    if (!allowNetworkAction(context)) return;

    final previous = _post;
    final optimistic = applyOptimisticReaction(_post, intent.apiValue);

    setState(() {
      _post = optimistic;
      _reacting = true;
    });

    final service = ref.read(communityServiceProvider);
    final result = intent.isRemove
        ? await service.removeReaction(_post.id)
        : await service.upsertReaction(
            postId: _post.id,
            type: intent.apiValue!,
          );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _post = previous;
        _reacting = false;
      });
      final msg =
          result.message.toLowerCase().contains('miembro') ||
              result.message.toLowerCase().contains('pertenec')
          ? result.message
          : reactionErrorMessage(intent);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  Future<void> _hide() async {
    final confirmed = await confirmHideClanPost(context);
    if (!confirmed || !mounted) return;
    final result = await ref
        .read(communityServiceProvider)
        .hideClanPost(clanSlug: widget.clanSlug, postId: _post.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) widget.onHidden?.call();
  }

  Future<void> _report() {
    return showGarraReportSheet(
      context,
      service: ref.read(communityServiceProvider),
      target: GarraReportTarget.post,
      targetId: _post.id,
    );
  }

  /// ANALYTICS_12: card was >=50% visible for >=1s (someone else's post).
  Future<void> _onSeen() async {
    final count = await GarraViewTracker.instance.trackPostView(
      ref.read(communityServiceProvider),
      _post.id,
    );
    if (count == null || !mounted) return;
    setState(() => _post = _post.copyWith(viewCount: count));
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final mine = post.isMine || isSameFanId(currentFanIdOf(ref), post.authorId);
    return GarraViewportTracker(
      id: post.id,
      enabled: !mine,
      onVisible: _onSeen,
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final post = _post;
    final colors = context.garraColors;
    // MODERATION_11: "Denunciar publicación" for someone else's post, only
    // with a known session (the backend re-checks ownership).
    final meId = currentFanIdOf(ref)?.trim() ?? '';
    final canReport =
        meId.isNotEmpty && !post.isMine && !isSameFanId(meId, post.authorId);
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _header(context, post)),
              if (widget.canModerate || canReport)
                SizedBox(
                  width: 36,
                  height: 36,
                  child: PopupMenuButton<String>(
                    key: ValueKey('clan_post_menu_${post.id}'),
                    tooltip: 'Opciones de la publicaci\u00f3n',
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: colors.textSecondary,
                    ),
                    color: colors.surfaceRaised,
                    onSelected: (value) {
                      if (value == 'hide') _hide();
                      if (value == 'report') _report();
                    },
                    itemBuilder: (_) => [
                      if (widget.canModerate)
                        PopupMenuItem(
                          value: 'hide',
                          child: Text(
                            'Ocultar publicaci\u00f3n',
                            style: TextStyle(color: colors.danger),
                          ),
                        ),
                      if (canReport)
                        PopupMenuItem(
                          value: 'report',
                          child: Text(
                            'Denunciar publicaci\u00f3n',
                            style: TextStyle(color: colors.textPrimary),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: GarraSpacing.sm),
          GarraReactionBar(
            reactionSummary: post.reactionSummary,
            reactionCount: post.reactionCount,
            commentCount: post.commentCount,
            viewCount: post.viewCount,
            myReaction: post.myReaction,
            onTapReactions: _reacting ? null : _react,
            onLongPressReactions: _reacting ? null : () => _react(change: true),
            onTapComments: widget.onOpenDetail,
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, WallPostModel post) {
    return InkWell(
      onTap: widget.onOpenDetail,
      borderRadius: BorderRadius.circular(GarraRadius.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.fullName.isNotEmpty ? post.fullName : post.username,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (post.username.isNotEmpty)
            Text(
              '@${post.username}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: GarraSpacing.sm),
          Text(post.content, style: Theme.of(context).textTheme.bodyMedium),
          if (post.createdAt.isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.xs),
            Text(
              _friendlyCreatedAt(post.createdAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _MembershipLostBody extends StatelessWidget {
  const _MembershipLostBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GarraSpacing.xl),
        child: GarraEmptyState(title: 'Acceso restringido', message: message),
      ),
    );
  }
}

String _friendlyCreatedAt(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$dd/$mm/${local.year} $hh:$min';
}
