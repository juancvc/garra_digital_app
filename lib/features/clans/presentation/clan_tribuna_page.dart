import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../community/data/engagement_utils.dart';
import '../../community/data/wall_post_model.dart';
import '../../community/presentation/providers/community_provider.dart';
import '../../community/presentation/widgets/garra_reaction_bar.dart';
import '../../community/presentation/widgets/garra_reaction_picker.dart';

import '../data/clan_models.dart';
import '../data/clan_service.dart';
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

class _ClanTribunaPageState extends ConsumerState<ClanTribunaPage> {
  final _contentController = TextEditingController();
  bool _publishing = false;

  @override
  void dispose() {
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

  Future<void> _publish(String clanName) async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe algo antes de publicar.')),
      );
      return;
    }
    if (content.length > 220) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 220 caracteres.')),
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      await ref.read(clanServiceProvider).createClanPost(
            widget.slug,
            CreateClanPostRequest(content: content),
          );
      _contentController.clear();
      ref.invalidate(clanFeedProvider(widget.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Publicado en $clanName')),
        );
      }
    } on ClanMembershipLostException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on ClanServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
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
    final clanAsync = ref.watch(clanDetailProvider(widget.slug));
    final feedAsync = ref.watch(clanFeedProvider(widget.slug));

    final body = clanAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(GarraColors.gold)),
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
        return RefreshIndicator(
          color: const Color(GarraColors.gold),
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
                onPublish: () => _publish(name),
              ),
              const SizedBox(height: GarraSpacing.lg),
              feedAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(GarraColors.gold),
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
                            padding:
                                const EdgeInsets.only(bottom: GarraSpacing.md),
                            child: _ClanFeedPostCard(
                              post: post,
                              onOpenDetail: () => context.push(
                                '/muro-crema/posts/${post.id}',
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

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: Text(
          clanAsync.asData != null
              ? 'Tribuna · ${clanAsync.asData!.value.name}'
              : 'Tribuna del Clan',
        ),
      ),
      body: body,
    );
  }
}

class _ClanComposer extends StatelessWidget {
  const _ClanComposer({
    required this.clanName,
    required this.controller,
    required this.publishing,
    required this.onPublish,
  });

  final String clanName;
  final TextEditingController controller;
  final bool publishing;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Publicar en $clanName',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GarraSpacing.sm),
          TextField(
            controller: controller,
            maxLength: 220,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Escribe tu arenga…',
            ),
          ),
          const SizedBox(height: GarraSpacing.sm),
          GarraPrimaryButton(
            label: publishing ? 'Publicando…' : 'Publicar',
            loading: publishing,
            onPressed: publishing ? null : onPublish,
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
  });

  final WallPostModel post;
  final VoidCallback onOpenDetail;

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

  Future<void> _react() async {
    if (_reacting) return;
    final selected = await showGarraReactionPicker(
      context,
      currentReaction: _post.myReaction,
    );
    if (selected == null || !mounted) return;

    final previous = _post;
    final same = _post.myReaction != null &&
        _post.myReaction!.toUpperCase() == selected.apiValue;
    final optimistic = applyOptimisticReaction(
      _post,
      same ? null : selected.apiValue,
    );

    setState(() {
      _post = optimistic;
      _reacting = true;
    });

    final service = ref.read(communityServiceProvider);
    final result = same
        ? await service.removeReaction(_post.id)
        : await service.upsertReaction(
            postId: _post.id,
            type: selected.apiValue,
          );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _post = previous;
        _reacting = false;
      });
      final msg = result.message.toLowerCase().contains('miembro') ||
              result.message.toLowerCase().contains('pertenec')
          ? result.message
          : 'No se pudo actualizar la reacción. Inténtalo de nuevo.';
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

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
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
                Text(
                  post.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (post.createdAt.isNotEmpty) ...[
                  const SizedBox(height: GarraSpacing.xs),
                  Text(
                    _friendlyCreatedAt(post.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: GarraSpacing.sm),
          GarraReactionBar(
            reactionSummary: post.reactionSummary,
            reactionCount: post.reactionCount,
            commentCount: post.commentCount,
            myReaction: post.myReaction,
            onTapReactions: _reacting ? null : _react,
            onTapComments: widget.onOpenDetail,
          ),
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
        child: GarraEmptyState(
          title: 'Acceso restringido',
          message: message,
        ),
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
