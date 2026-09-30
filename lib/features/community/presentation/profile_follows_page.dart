import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/garra_avatar.dart';
import '../data/community_service.dart';

class ProfileFollowsPage extends StatefulWidget {
  const ProfileFollowsPage({super.key, required this.userId, required this.followers, this.service});
  final String userId;
  final bool followers;
  final CommunityService? service;

  @override
  State<ProfileFollowsPage> createState() => _ProfileFollowsPageState();
}

class _ProfileFollowsPageState extends State<ProfileFollowsPage> {
  late final CommunityService _service = widget.service ?? CommunityService();
  late final Future<List<Map<String, dynamic>>> _people = _service.getProfileFollows(
      widget.userId, followers: widget.followers);

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
        final people = snapshot.data!;
        if (people.isEmpty) return const Center(child: Text('Todavía no hay personas aquí'));
        return ListView.builder(
          itemCount: people.length,
          itemBuilder: (context, index) {
            final person = people[index];
            final id = person['userId']?.toString() ?? '';
            final name = person['displayName']?.toString() ?? '';
            return ListTile(
              leading: GarraAvatar(displayName: name,
                  avatarUrl: person['avatarUrl']?.toString(), size: 40),
              title: Text(name),
              subtitle: Text('@${person['username'] ?? ''}'),
              onTap: id.isEmpty ? null : () => context.push('/comunidad/u/$id'),
            );
          },
        );
      },
    ),
  );
}
