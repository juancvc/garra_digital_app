import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_fan_provider.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/community_service.dart';

class ProfileFollowsPage extends ConsumerStatefulWidget {
  const ProfileFollowsPage({super.key, required this.userId, required this.followers,
    this.service, this.ownerIsMe, this.onOwnFollowingCountChanged});
  final String userId;
  final bool followers;
  final CommunityService? service;
  final bool? ownerIsMe;
  final ValueChanged<int>? onOwnFollowingCountChanged;

  @override
  ConsumerState<ProfileFollowsPage> createState() => _ProfileFollowsPageState();
}

class _ProfileFollowsPageState extends ConsumerState<ProfileFollowsPage> {
  late final CommunityService _service = widget.service ?? CommunityService();
  late final Future<List<Map<String, dynamic>>> _people = _service.getProfileFollows(
      widget.userId, followers: widget.followers);
  List<Map<String, dynamic>>? _visiblePeople;
  String? _busyId;

  Future<void> _toggle(Map<String, dynamic> person) async {
    final id = person['userId']?.toString() ?? '';
    if (id.isEmpty || _busyId != null || !allowNetworkAction(context)) return;
    final wasFollowing = person['followedByMe'] == true;
    setState(() => _busyId = id);
    try {
      if (wasFollowing) {
        await _service.unfollowUser(id);
      } else {
        await _service.followUser(id);
      }
      if (!mounted) return;
      final ownerIsMe = widget.ownerIsMe ??
          isSameFanId(currentFanIdOf(ref), widget.userId);
      setState(() {
        if (ownerIsMe && !widget.followers && wasFollowing) {
          _visiblePeople!.removeWhere((row) => row['userId']?.toString() == id);
        } else {
          person['followedByMe'] = !wasFollowing;
        }
      });
      if (ownerIsMe) {
        widget.onOwnFollowingCountChanged?.call(wasFollowing ? -1 : 1);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el seguimiento')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.followers ? 'Seguidores' : 'Siguiendo')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _people,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) return const Center(child: Text('No pudimos cargar esta lista'));
          return const Center(child: CircularProgressIndicator());
        }
        final people = _visiblePeople ??= snapshot.data!.map((person) =>
            Map<String, dynamic>.from(person)).toList();
        if (people.isEmpty) {
          // GARRA38: no dead end - one clear way to find people.
          return Center(
            child: GarraEmptyState(
              title: 'Todav\u00eda no hay personas aqu\u00ed',
              message: 'Descubre hinchas de Garra y sigue a quien quieras.',
              actionLabel: 'Descubrir personas',
              onAction: () => context.push('/comunidad/buscar'),
            ),
          );
        }
        return ListView.builder(
          itemCount: people.length,
          itemBuilder: (context, index) {
            final person = people[index];
            final id = person['userId']?.toString() ?? '';
            final username = person['username']?.toString().trim() ?? '';
            final displayName = person['displayName']?.toString().trim() ?? '';
            final name = displayName.isNotEmpty ? displayName :
                username.isNotEmpty ? username : 'Hincha';
            final isSelf = person['isMe'] == true ||
                (widget.ownerIsMe == true && isSameFanId(id, widget.userId));
            final followed = person['followedByMe'] == true;
            final action = _busyId != null || id.isEmpty
                ? null : () => _toggle(person);
            final colors = context.garraColors;
            final button = followed
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.border),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: action,
                    child: Text(_busyId == id ? '...' : 'Dejar de seguir'),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.brandPrimary,
                      foregroundColor: colors.onBrand,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: action,
                    child: Text(_busyId == id ? '...' : 'Seguir'),
                  );
            return LayoutBuilder(builder: (context, constraints) {
              final inline = !isSelf && constraints.maxWidth >= 350 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 17;
              return ListTile(
              leading: GarraAvatar(displayName: name,
                  avatarUrl: person['avatarUrl']?.toString(), size: 40),
              title: inline ? Row(children: [
                Expanded(child: Text(name, maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                SizedBox(width: 136, child: button),
              ]) : Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: inline
                  ? username.isEmpty ? null : Text('@$username', maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (username.isNotEmpty) Text('@$username', maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (!isSelf)
                    Align(alignment: Alignment.centerRight, child:
                        ConstrainedBox(constraints: const BoxConstraints(
                            maxWidth: 190), child: button)),
                ],
              ),
              onTap: id.isEmpty ? null : () => context.push('/comunidad/u/$id'),
            );
            });
          },
        );
      },
    ),
  );
}
