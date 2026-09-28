import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/utils/garra_count_format.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_cached_network_image.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/data/chat_service.dart';
import '../../chat/presentation/floating_chat_panel.dart';
import '../data/community_report.dart';
import '../data/community_service.dart';
import '../data/garra_view_tracker.dart';
import '../data/wall_post_model.dart';
import 'widgets/garra_post_media_grid.dart';
import 'widgets/garra_report_sheet.dart';

class PublicFanProfilePage extends StatefulWidget {
  const PublicFanProfilePage({
    super.key,
    required this.userId,
    this.communityService,
    this.chatService,
  });

  final String userId;
  final CommunityService? communityService;
  final ChatService? chatService;

  @override
  State<PublicFanProfilePage> createState() => _PublicFanProfilePageState();
}

class _PublicFanProfilePageState extends State<PublicFanProfilePage> {
  late final CommunityService _service =
      widget.communityService ?? CommunityService();
  late final ChatService _chat = widget.chatService ?? ChatService();
  Map<String, dynamic>? _profile;
  ChatRelationship _chatRelationship = ChatRelationship.none();
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _service.getPublicProfile(widget.userId);
      var relationship = ChatRelationship.none();
      if (profile['isMe'] != true) {
        try {
          relationship = await _chat.relationship(widget.userId);
        } catch (_) {
          relationship = ChatRelationship.none();
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _chatRelationship = relationship;
        _loading = false;
      });
      // ANALYTICS_12: someone else's profile opened -> one visit per session
      // (backend dedupes viewer+profile per 24h; the viewer never gets totals).
      if (profile['isMe'] != true) {
        GarraViewTracker.instance.trackProfileView(_service, widget.userId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos abrir este perfil';
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final p = _profile;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    try {
      final followed = p['isFollowedByMe'] == true;
      if (followed) {
        await _service.unfollowUser(widget.userId);
      } else {
        await _service.followUser(widget.userId);
      }
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _message() async {
    if (_busy || _chatRelationship.blocked) return;
    final relationship = _chatRelationship;
    final name = _profile?['displayName']?.toString() ?? '';
    // CHAT_V2_A: an ACTIVE thread always opens the canonical chat screen.
    final conversationId = relationship.conversationId;
    if (relationship.status == 'ACTIVE' && conversationId != null) {
      await context.push('/chat/$conversationId');
      return;
    }
    await showGarraFloatingChat(
      context: context,
      chatService: _chat,
      otherUserId: widget.userId,
      otherDisplayName: name,
      openingSuggestion: 'Hola',
      relationship: relationship.status == 'NONE' ? null : relationship,
    );
  }

  Future<void> _block() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquear usuario'),
        content: const Text(
          'No verás sus publicaciones ni comentarios en la comunidad.',
        ),
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
    await _service.blockUser(widget.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Usuario bloqueado')));
    context.pop();
  }

  /// MODERATION_11: platform report of someone else's profile.
  Future<void> _report() {
    return showGarraReportSheet(
      context,
      service: _service,
      target: GarraReportTarget.profile,
      targetId: widget.userId,
    );
  }

  Widget _messageButton() {
    final relationship = _chatRelationship;
    final pendingIn = relationship.isPending && !relationship.outgoing;
    final label = pendingIn ? 'Aceptar chat' : 'Mensaje';
    final colors = context.garraColors;
    return OutlinedButton.icon(
      key: const Key('profile-message-action'),
      onPressed: _busy ? null : _message,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.brandPrimary),
      ),
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.garraColors.background,
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (_profile?['isMe'] != true) ...[
            IconButton(
              tooltip: 'Invitar a Garra',
              onPressed: () {
                final p = _profile;
                final username = p?['username']?.toString() ?? '';
                Share.share(
                  'Sigue a @$username en Garra Digital — la red de la hinchada crema.',
                );
              },
              icon: const Icon(Icons.ios_share_outlined),
            ),
            IconButton(
              tooltip: 'Bloquear',
              onPressed: _block,
              icon: const Icon(Icons.block),
            ),
            if (_profile != null)
              PopupMenuButton<String>(
                key: const ValueKey('profile_menu'),
                tooltip: 'M\u00e1s opciones',
                icon: const Icon(Icons.more_vert_rounded),
                color: context.garraColors.surfaceRaised,
                onSelected: (value) {
                  if (value == 'report') _report();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'report',
                    child: Text(
                      'Denunciar perfil',
                      style: TextStyle(color: context.garraColors.textPrimary),
                    ),
                  ),
                ],
              ),
          ] else
            IconButton(
              tooltip: 'Editar perfil',
              onPressed: () => context.push('/passport/edit'),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? GarraErrorState(message: _error!, onRetry: _load)
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final p = _profile!;
    final name =
        p['displayName']?.toString() ?? p['fullName']?.toString() ?? '';
    final username = p['username']?.toString() ?? '';
    final level = p['levelName']?.toString();
    final since = p['memberSince']?.toString();
    final followers = p['followerCount'] ?? 0;
    final following = p['followingCount'] ?? 0;
    final postCount = p['globalPostCount'] ?? 0;
    final followed = p['isFollowedByMe'] == true;
    final blocked = p['isBlockedByMe'] == true;
    final isMe = p['isMe'] == true;
    final rawPosts = p['globalPosts'];
    final posts = rawPosts is List
        ? rawPosts
              .whereType<Map>()
              .map((e) => WallPostModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <WallPostModel>[];

    final colors = context.garraColors;
    final displayName = name.isEmpty ? username : name;
    final avatarUrl = p['avatarUrl']?.toString();
    final levelNumber = (p['levelNumber'] as num?)?.toInt();
    final sinceYear = since == null ? null : DateTime.tryParse(since)?.year;

    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: [
        _ProfileHero(
          displayName: displayName,
          username: username,
          avatarUrl: avatarUrl,
          levelNumber: levelNumber,
          levelName: level,
          sinceYear: sinceYear,
        ),
        const SizedBox(height: GarraSpacing.lg),
        Container(
          key: const Key('profile-stats'),
          padding: const EdgeInsets.symmetric(vertical: GarraSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(GarraRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              _Stat(label: 'Publicaciones', value: '$postCount'),
              _Stat(label: 'Seguidores', value: '$followers'),
              _Stat(label: 'Siguiendo', value: '$following'),
            ],
          ),
        ),
        // ANALYTICS_12: private to the owner (backend sends it only when isMe).
        if (isMe && p['profileViewCount'] is num) ...[
          const SizedBox(height: GarraSpacing.sm),
          _ProfileViews(count: (p['profileViewCount'] as num).toInt()),
        ],
        const SizedBox(height: GarraSpacing.md),
        if (isMe)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/passport/edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.brandPrimary),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar perfil'),
                ),
              ),
              const SizedBox(width: 8),
              // CHAT_V2_A: own inbox entry (no new bottom tab).
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('profile-messages-entry'),
                  onPressed: () => context.push('/chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Mensajes'),
                ),
              ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: blocked || _chatRelationship.blocked
                ? const OutlinedButton(
                    onPressed: null,
                    child: Text('Bloqueado'),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const Key('profile-follow-action'),
                          onPressed: _busy ? null : _toggleFollow,
                          style: FilledButton.styleFrom(
                            backgroundColor: followed
                                ? colors.surfaceRaised
                                : colors.brandPrimary,
                            foregroundColor: followed
                                ? colors.textPrimary
                                : colors.onBrand,
                            side: followed
                                ? BorderSide(color: colors.border)
                                : null,
                          ),
                          child: Text(followed ? 'Siguiendo' : 'Seguir'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _messageButton()),
                    ],
                  ),
          ),
        const SizedBox(height: GarraSpacing.lg),
        const GarraSectionHeader(title: 'Publicaciones'),
        const SizedBox(height: GarraSpacing.md),
        if (posts.isEmpty)
          const GarraEmptyState(
            title: 'Sin publicaciones',
            message: 'Este hincha aún no publicó en la comunidad.',
          )
        else
          ...posts.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.md),
              child: GarraCard(
                key: Key('profile-post-${post.id}'),
                onTap: () => context.push('/muro-crema/posts/${post.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((post.imageUrl != null && post.imageUrl!.isNotEmpty) ||
                        post.media.isNotEmpty) ...[
                      const SizedBox(height: GarraSpacing.sm),
                      GarraPostMediaGrid(
                        media: post.media,
                        legacyImageUrl: post.imageUrl,
                      ),
                    ],
                    const SizedBox(height: GarraSpacing.xs),
                    TextButton.icon(
                      key: Key('profile-post-comments-${post.id}'),
                      onPressed: () =>
                          context.push('/muro-crema/posts/${post.id}'),
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                        post.commentCount == 0
                            ? 'Comentar'
                            : post.commentCount == 1
                            ? 'Ver 1 comentario'
                            : 'Ver ${post.commentCount} comentarios',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Garra identity header: brand band (no cover contract yet), large
/// tappable photo, name, @username, level and year joined.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.levelNumber,
    required this.levelName,
    required this.sinceYear,
  });

  final String displayName;
  final String username;
  final String? avatarUrl;
  final int? levelNumber;
  final String? levelName;
  final int? sinceYear;

  bool get _hasPhoto => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  void _openPhoto(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final colors = ctx.garraColors;
        return Dialog(
          key: const Key('profile-photo-viewer'),
          backgroundColor: colors.mediaBackdrop,
          insetPadding: const EdgeInsets.all(GarraSpacing.lg),
          child: Stack(
            children: [
              InteractiveViewer(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GarraCachedNetworkImage(imageUrl: avatarUrl!),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.onBrand),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final textTheme = Theme.of(context).textTheme;
    const avatarSize = 96.0;
    return Column(
      children: [
        SizedBox(
          height: 96 + avatarSize / 2,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(GarraRadius.md),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.brandPrimary, colors.surfaceRaised],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: GestureDetector(
                  key: const Key('profile-avatar'),
                  onTap: _hasPhoto ? () => _openPhoto(context) : null,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.background,
                      border: Border.all(color: colors.brandPrestige, width: 2),
                    ),
                    child: GarraAvatar(
                      displayName: displayName,
                      avatarUrl: avatarUrl,
                      size: avatarSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: GarraSpacing.sm),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '@$username',
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: GarraSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: GarraSpacing.sm,
          runSpacing: GarraSpacing.xs,
          children: [
            if (levelNumber != null &&
                levelName != null &&
                levelName!.isNotEmpty)
              GarraLevelBadge(levelNumber: levelNumber!, levelName: levelName!)
            else if (levelName != null && levelName!.isNotEmpty)
              Text(
                'Nivel $levelName',
                style: textTheme.labelMedium?.copyWith(
                  color: colors.brandPrestige,
                ),
              ),
            if (sinceYear != null)
              Text(
                'En Garra desde $sinceYear',
                key: const Key('profile-member-since'),
                style: textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// ANALYTICS_12: discreet "N visitas" line, only on my own profile.
class _ProfileViews extends StatelessWidget {
  const _ProfileViews({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final label = count == 1 ? '1 visita' : '${formatGarraCount(count)} visitas';
    return Row(
      key: const Key('profile_views'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.visibility_outlined, size: 16, color: colors.textSecondary),
        const SizedBox(width: GarraSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.garraColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.garraColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final _service = CommunityService();
  List<Map<String, dynamic>> _blocks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final blocks = await _service.listBlocks();
      if (!mounted) return;
      setState(() {
        _blocks = blocks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String userId) async {
    await _service.unblockUser(userId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.garraColors.background,
      appBar: AppBar(title: const Text('Usuarios bloqueados')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocks.isEmpty
          ? const GarraEmptyState(
              title: 'Nadie bloqueado',
              message: 'Cuando bloquees a alguien, aparecerá aquí.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              itemCount: _blocks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final b = _blocks[i];
                final id = b['userId']?.toString() ?? '';
                final name = b['displayName']?.toString() ?? '';
                final username = b['username']?.toString() ?? '';
                return GarraCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              '@$username',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: id.isEmpty ? null : () => _unblock(id),
                        child: const Text('Desbloquear'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Share helper placeholder (call sites use share_plus directly).
void shareCommunityText(String text) {}
