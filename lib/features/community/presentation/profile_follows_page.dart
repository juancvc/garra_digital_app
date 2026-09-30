import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_fan_provider.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/widgets/garra_avatar.dart';
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
      if (ownerIsMe && !widget.followers) {
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
        if (people.isEmpty) return const Center(child: Text('Todavía no hay personas aquí'));
        return ListView.builder(
          itemCount: people.length,
          itemBuilder: (context, index) {
            final person = people[index];
            final id = person['userId']?.toString() ?? '';
            final username = person['username']?.toString().trim() ?? '';
            final displayName = person['displayName']?.toString().trim() ?? '';
            final name = displayName.isNotEmpty ? displayName :
                username.isNotEmpty ? username : 'Hincha';
            return ListTile(
              leading: GarraAvatar(displayName: name,
                  avatarUrl: person['avatarUrl']?.toString(), size: 40),
              title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (username.isNotEmpty) Text('@$username', maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (person['isMe'] != true)
                    Align(alignment: Alignment.centerRight, child: OutlinedButton(
                      onPressed: _busyId != null || id.isEmpty
                          ? null : () => _toggle(person),
                      child: Text(_busyId == id ? '...' :
                          person['followedByMe'] == true ? 'Siguiendo' : 'Seguir'),
                    )),
                ],
              ),
              onTap: id.isEmpty ? null : () => context.push('/comunidad/u/$id'),
            );
          },
        );
      },
    ),
  );
}
