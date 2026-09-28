import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../chat/data/chat_service.dart';
import '../../chat/presentation/chat_unread_badge.dart';
import '../../home/presentation/social_feed_tab.dart';

/// Root Community destination: live social activity first, groups second.
class CommunitySocialPage extends StatelessWidget {
  const CommunitySocialPage({super.key, this.chatService});

  final ChatService? chatService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Comunidad'),
        actions: [
          // CHAT_V2_A: shared Mensajes action + unread badge (same as Home).
          GarraMessagesAction(showBadge: chatService != null),
          IconButton(
            tooltip: 'Comunidades Cremas',
            onPressed: () => context.push('/clans'),
            icon: const Icon(Icons.groups_2_outlined),
          ),
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => context.push('/comunidad/buscar'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Actividad',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
        ],
      ),
      body: const SocialFeedTab(
        key: ValueKey('COMMUNITY_RECENT_FEED'),
        mode: 'RECENT',
      ),
    );
  }
}
