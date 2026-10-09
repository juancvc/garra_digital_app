import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../chat/data/chat_service.dart';
import '../../chat/presentation/chat_unread_badge.dart';
import '../../football/presentation/football_chat_room_view.dart';

/// Tab Comunidad: conversación crema (Football Chat GENERAL).
class CommunitySocialPage extends StatelessWidget {
  const CommunitySocialPage({super.key, this.chatService});

  final ChatService? chatService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Comunidad Crema'),
        actions: [
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
      body: const FootballChatRoomView(
        key: ValueKey('comunidad_general_chat'),
        surface: FootballChatSurface.community,
      ),
    );
  }
}
