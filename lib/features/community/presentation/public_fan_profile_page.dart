import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/community_service.dart';
import '../data/wall_post_model.dart';

class PublicFanProfilePage extends StatefulWidget {
  const PublicFanProfilePage({super.key, required this.userId});

  final String userId;

  @override
  State<PublicFanProfilePage> createState() => _PublicFanProfilePageState();
}

class _PublicFanProfilePageState extends State<PublicFanProfilePage> {
  final _service = CommunityService();
  Map<String, dynamic>? _profile;
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
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuario bloqueado')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
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

    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: [
        Container(
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [
                Color(GarraColors.burgundyDeep),
                Color(GarraColors.surface),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            GarraAvatar(displayName: name.isEmpty ? username : name, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '@$username',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (level != null && level.isNotEmpty)
                    Text(
                      'Nivel $level',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(GarraColors.gold),
                          ),
                    ),
                  if (since != null && since.isNotEmpty)
                    Text(
                      'En Garra desde ${since.length >= 10 ? since.substring(0, 10) : since}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: GarraSpacing.md),
        Row(
          children: [
            _Stat(label: 'Publicaciones', value: '$postCount'),
            _Stat(label: 'Seguidores', value: '$followers'),
            _Stat(label: 'Siguiendo', value: '$following'),
          ],
        ),
        const SizedBox(height: GarraSpacing.md),
        if (isMe)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/passport/edit'),
              child: const Text('Editar perfil'),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: blocked
                ? const OutlinedButton(
                    onPressed: null,
                    child: Text('Bloqueado'),
                  )
                : FilledButton(
                    onPressed: _busy ? null : _toggleFollow,
                    style: FilledButton.styleFrom(
                      backgroundColor: followed
                          ? const Color(GarraColors.burgundyDeep)
                          : const Color(GarraColors.burgundy),
                      foregroundColor: const Color(GarraColors.cream),
                    ),
                    child: Text(followed ? 'Siguiendo' : 'Seguir'),
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
                onTap: () => context.push('/muro-crema/posts/${post.id}'),
                child: Text(
                  post.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
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
      backgroundColor: const Color(GarraColors.charcoal),
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
