import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../data/create_wall_post_request.dart';
import '../data/engagement_utils.dart';
import '../data/reaction_type.dart';
import '../data/wall_post_model.dart';
import '../data/wall_status_model.dart';
import 'providers/community_provider.dart';
import 'widgets/garra_reaction_bar.dart';
import 'widgets/garra_reaction_picker.dart';

class MuroCremaPage extends ConsumerStatefulWidget {
  const MuroCremaPage({super.key});

  @override
  ConsumerState<MuroCremaPage> createState() => _MuroCremaPageState();
}

class _MuroCremaPageState extends ConsumerState<MuroCremaPage> {
  final _contentController = TextEditingController();

  String _selectedFilter = 'ALL';
  String _selectedPostLocationTag = 'STADIUM';
  bool _publishing = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(wallStatusProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Muro Crema',
          style: TextStyle(
            color: AppTheme.cream,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nueva publicación',
            icon: const Icon(Icons.edit_outlined, color: AppTheme.gold),
            onPressed: () => context.push('/muro-crema/compose'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/muro-crema/compose'),
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Publicar'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isMobile = width < 600;
            final horizontalPadding = isMobile ? 16.0 : 24.0;

            return statusAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
              ),
              error: (error, _) => _ErrorState(
                message: 'No se pudo cargar el muro.',
                detail: error.toString(),
                horizontalPadding: horizontalPadding,
              ),
              data: (status) {
                if (status == null ||
                    status.matchId == null ||
                    status.matchId!.isEmpty) {
                  return _EmptyState(horizontalPadding: horizontalPadding);
                }

                final matchId = status.matchId!;
                final params = WallPostsParams(
                  matchId: matchId,
                  locationTag: _selectedFilter,
                );
                final postsAsync = ref.watch(wallPostsProvider(params));
                final canPublish = _canPublish(status.wallStatus);

                return RefreshIndicator(
                  color: AppTheme.gold,
                  backgroundColor: const Color(0xFF1A1A1A),
                  onRefresh: () async {
                    ref.invalidate(wallStatusProvider);
                    ref.invalidate(wallPostsProvider(params));
                    ref.invalidate(myWallPostsProvider);

                    await Future.wait([
                      ref.read(wallStatusProvider.future),
                      ref.read(wallPostsProvider(params).future),
                    ]);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      0,
                    ),
                    children: [
                      _Header(
                        status: status,
                        isMobile: isMobile,
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      _FilterChips(
                        selectedTag: _selectedFilter,
                        onChanged: (value) {
                          setState(() => _selectedFilter = value);
                        },
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      _CreatePostCard(
                        controller: _contentController,
                        selectedLocationTag: _selectedPostLocationTag,
                        publishing: _publishing,
                        canPublish: canPublish,
                        wallStatus: status.wallStatus,
                        isMobile: isMobile,
                        onLocationChanged: (value) {
                          setState(() => _selectedPostLocationTag = value);
                        },
                        onPublish: () => _publish(matchId: matchId),
                      ),
                      SizedBox(height: isMobile ? 14 : 18),
                      postsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.only(top: 36),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.gold,
                            ),
                          ),
                        ),
                        error: (error, _) => _InlineErrorState(
                          message: 'No se pudieron cargar las publicaciones.',
                          detail: error.toString(),
                        ),
                        data: (posts) {
                          if (posts.isEmpty) {
                            return const _NoPostsState();
                          }

                          return Column(
                            children: [
                              ...posts.map(
                                    (post) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: isMobile ? 10 : 14,
                                  ),
                                  child: _WallPostCard(
                                    post: post,
                                    isMobile: isMobile,
                                    onReport: () => _openReportDialog(
                                      postId: post.id,
                                      params: params,
                                    ),
                                    onOpenDetail: () => context.push(
                                      '/muro-crema/posts/${post.id}',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 130),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _publish({
    required String matchId,
  }) async {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      _showSnackBar(
        message: 'Escribe una arenga antes de publicar.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (content.length > 220) {
      _showSnackBar(
        message: 'La arenga no puede superar los 220 caracteres.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() => _publishing = true);

    final service = ref.read(communityServiceProvider);

    final result = await service.createPost(
      CreateWallPostRequest(
        matchId: matchId,
        content: content,
        imageUrl: null,
        locationTag: _selectedPostLocationTag,
      ),
    );

    if (!mounted) return;

    if (result.success) {
      _contentController.clear();

      _showSnackBar(
        message: result.message,
        backgroundColor: Colors.green,
      );

      ref.invalidate(
        wallPostsProvider(
          WallPostsParams(
            matchId: matchId,
            locationTag: _selectedFilter,
          ),
        ),
      );
      ref.invalidate(myWallPostsProvider);
    } else {
      _showSnackBar(
        message: _normalizeWallError(result.message),
        backgroundColor: Colors.orange,
      );
    }

    if (mounted) {
      setState(() => _publishing = false);
    }
  }

  Future<void> _openReportDialog({
    required String postId,
    required WallPostsParams params,
  }) async {
    const categories = <String, String>{
      'SPAM': 'Spam',
      'HARASSMENT': 'Acoso',
      'VIOLENCE': 'Violencia',
      'HATE': 'Odio / discriminación',
      'SEXUAL_CONTENT': 'Contenido sexual',
      'FRAUD': 'Fraude',
      'OTHER': 'Otro',
    };
    String selected = 'OTHER';
    final reasonController = TextEditingController();

    final submitted = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'Reportar publicación',
                style: TextStyle(
                  color: AppTheme.cream,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selected,
                    dropdownColor: const Color(0xFF1A1A1A),
                    items: categories.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => selected = v);
                    },
                    decoration: const InputDecoration(labelText: 'Categoría'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Detalle (opcional)',
                      hintText: 'Cuéntanos más',
                      isDense: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppTheme.gold),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, {
                      'category': selected,
                      'reason': reasonController.text.trim(),
                    });
                  },
                  child: const Text('Reportar'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();

    if (submitted == null) {
      return;
    }

    final service = ref.read(communityServiceProvider);

    final result = await service.reportPost(
      postId: postId,
      category: submitted['category'] ?? 'OTHER',
      reason: (submitted['reason'] ?? '').isEmpty
          ? (categories[submitted['category']] ?? 'Reportado')
          : submitted['reason']!,
    );

    if (!mounted) return;

    _showSnackBar(
      message: result.success
          ? 'Reportado. Gracias.'
          : _normalizeWallError(result.message),
      backgroundColor: result.success ? Colors.green : Colors.orange,
    );

    ref.invalidate(wallPostsProvider(params));
    ref.invalidate(myWallPostsProvider);
  }

  bool _canPublish(String wallStatus) {
    return wallStatus != 'CLOSED' && wallStatus != 'ARCHIVED';
  }

  String _normalizeWallError(String message) {
    if (message.contains('Maximum posts per user')) {
      return 'Ya alcanzaste el máximo de publicaciones para este partido';
    }

    if (message.contains('Wall is not open')) {
      return 'El muro no está abierto para este partido';
    }

    return message;
  }

  void _showSnackBar({
    required String message,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.status,
    required this.isMobile,
  });

  final WallStatusModel status;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.burgundy,
            Color(0xFF2A0B0F),
          ],
        ),
        border: Border.all(
          color: AppTheme.cream.withOpacity(0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isMobile ? 42 : 48,
            height: isMobile ? 42 : 48,
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: AppTheme.gold,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Muro Crema',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.cream,
                    fontSize: isMobile ? 20 : 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  status.matchName ?? 'Partido crema',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(
                      label: _translateWallStatus(status.wallStatus),
                      color: AppTheme.gold,
                      icon: Icons.info_outline_rounded,
                      compact: true,
                    ),
                    if (status.matchDateTime != null &&
                        status.matchDateTime!.isNotEmpty)
                      _Badge(
                        label: _safeFormatDateTime(status.matchDateTime!),
                        color: Colors.white70,
                        icon: Icons.calendar_month_rounded,
                        compact: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selectedTag,
    required this.onChanged,
  });

  final String selectedTag;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = [
      _TagFilter(label: 'Todos', value: 'ALL'),
      _TagFilter(label: 'Estadio', value: 'STADIUM'),
      _TagFilter(label: 'Camino', value: 'ON_THE_WAY'),
      _TagFilter(label: 'Casa', value: 'HOME'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = selectedTag == filter.value;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: selected,
              selectedColor: AppTheme.gold,
              backgroundColor: const Color(0xFF1A1A1A),
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                color: selected ? AppTheme.background : AppTheme.cream,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              side: BorderSide(
                color: selected
                    ? AppTheme.gold
                    : AppTheme.cream.withOpacity(0.12),
              ),
              onSelected: (_) => onChanged(filter.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CreatePostCard extends StatelessWidget {
  const _CreatePostCard({
    required this.controller,
    required this.selectedLocationTag,
    required this.publishing,
    required this.canPublish,
    required this.wallStatus,
    required this.isMobile,
    required this.onLocationChanged,
    required this.onPublish,
  });

  final TextEditingController controller;
  final String selectedLocationTag;
  final bool publishing;
  final bool canPublish;
  final String wallStatus;
  final bool isMobile;
  final ValueChanged<String> onLocationChanged;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    if (!canPublish) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Row(
            children: [
              Container(
                width: isMobile ? 42 : 48,
                height: isMobile ? 42 : 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.24),
                  ),
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: Colors.orange,
                ),
              ),
              SizedBox(width: isMobile ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Muro cerrado',
                      style: TextStyle(
                        color: AppTheme.cream,
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No se pueden publicar arengas en este momento.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.62),
                        fontSize: isMobile ? 12 : 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    const locations = [
      _TagFilter(label: 'Estadio', value: 'STADIUM'),
      _TagFilter(label: 'Camino', value: 'ON_THE_WAY'),
      _TagFilter(label: 'Casa', value: 'HOME'),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Publica tu arenga',
              style: TextStyle(
                color: AppTheme.cream,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              enabled: !publishing,
              maxLines: isMobile ? 3 : 4,
              maxLength: 220,
              decoration: const InputDecoration(
                labelText: 'Escribe tu arenga crema',
                alignLabelWithHint: true,
                isDense: true,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '¿Desde dónde alientas?',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: locations.map((location) {
                  final selected = selectedLocationTag == location.value;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(location.label),
                      selected: selected,
                      selectedColor: AppTheme.gold,
                      backgroundColor: const Color(0xFF242424),
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppTheme.background
                            : AppTheme.cream,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      side: BorderSide(
                        color: selected
                            ? AppTheme.gold
                            : AppTheme.cream.withOpacity(0.12),
                      ),
                      onSelected: !publishing
                          ? (_) => onLocationChanged(location.value)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: publishing ? null : onPublish,
                icon: publishing
                    ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.burgundy,
                  ),
                )
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Publicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WallPostCard extends ConsumerStatefulWidget {
  const _WallPostCard({
    required this.post,
    required this.isMobile,
    required this.onReport,
    required this.onOpenDetail,
  });

  final WallPostModel post;
  final bool isMobile;
  final VoidCallback onReport;
  final VoidCallback onOpenDetail;

  @override
  ConsumerState<_WallPostCard> createState() => _WallPostCardState();
}

class _WallPostCardState extends ConsumerState<_WallPostCard> {
  late WallPostModel _post;
  bool _reacting = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(covariant _WallPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.reactionCount != widget.post.reactionCount ||
        oldWidget.post.commentCount != widget.post.commentCount ||
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar la reacción. Inténtalo de nuevo.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
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

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.isMobile;
    final post = _post;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 13 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.onOpenDetail,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 17 : 20,
                        backgroundColor: AppTheme.burgundy,
                        child: Text(
                          post.username.isNotEmpty
                              ? post.username[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: AppTheme.cream,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.cream,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${post.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: widget.onReport,
                          tooltip: 'Reportar',
                          icon: const Icon(
                            Icons.flag_outlined,
                            color: AppTheme.gold,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.86),
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          post.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _Badge(
                        label: _translateLocationTag(post.locationTag),
                        color: AppTheme.gold,
                        icon: Icons.place_rounded,
                        compact: true,
                      ),
                      _Badge(
                        label: _translatePostStatus(post.status),
                        color: post.status == 'ACTIVE'
                            ? Colors.green
                            : Colors.orange,
                        icon: Icons.info_outline_rounded,
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _safeFormatDateTime(post.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.48),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GarraReactionBar(
              reactionSummary: post.reactionSummary,
              reactionCount: post.reactionCount,
              commentCount: post.commentCount,
              myReaction: post.myReaction,
              onTapReactions: _reacting ? null : _react,
              onTapComments: widget.onOpenDetail,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('react_cta_${post.id}'),
                onPressed: _reacting ? null : _react,
                icon: Text(
                  post.myReaction != null
                      ? ReactionType.emojiFor(post.myReaction!)
                      : '👍',
                  style: const TextStyle(fontSize: 16),
                ),
                label: Text(
                  post.myReaction != null
                      ? ReactionType.labelFor(post.myReaction!)
                      : 'Reaccionar',
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: compact ? 13 : 15,
          ),
          SizedBox(width: compact ? 4 : 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPostsState extends StatelessWidget {
  const _NoPostsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            color: AppTheme.gold.withOpacity(0.9),
            size: 46,
          ),
          const SizedBox(height: 14),
          const Text(
            'Aún no hay arengas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.cream,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sé el primero en alentar en el Muro Crema.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.horizontalPadding,
  });

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 130),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.forum_outlined,
          color: AppTheme.gold.withOpacity(0.9),
          size: 54,
        ),
        const SizedBox(height: 18),
        const Text(
          'Muro no disponible',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.cream,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Cuando exista un partido con muro activo, aparecerá aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.62),
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.detail,
    required this.horizontalPadding,
  });

  final String message;
  final String detail;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 130),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.error_outline_rounded,
          color: Colors.redAccent.withOpacity(0.9),
          size: 54,
        ),
        const SizedBox(height: 18),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.cream,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _InlineErrorState extends StatelessWidget {
  const _InlineErrorState({
    required this.message,
    required this.detail,
  });

  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagFilter {
  const _TagFilter({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

String _translateWallStatus(String status) {
  switch (status) {
    case 'CLOSED':
      return 'Cerrado';
    case 'PRE_MATCH':
      return 'Previa';
    case 'LIVE':
      return 'En vivo';
    case 'POST_MATCH':
      return 'Post partido';
    case 'ARCHIVED':
      return 'Archivado';
    default:
      return status;
  }
}

String _translateLocationTag(String locationTag) {
  switch (locationTag) {
    case 'STADIUM':
      return 'Estadio';
    case 'ON_THE_WAY':
      return 'Camino al templo';
    case 'HOME':
      return 'Desde casa';
    default:
      return locationTag;
  }
}

String _translatePostStatus(String status) {
  switch (status) {
    case 'ACTIVE':
      return 'Activo';
    case 'HIDDEN':
      return 'Oculto';
    case 'REPORTED':
      return 'Reportado';
    default:
      return status;
  }
}

String _safeFormatDateTime(String isoDate) {
  try {
    return formatDateTime(isoDate);
  } catch (_) {
    return isoDate;
  }
}