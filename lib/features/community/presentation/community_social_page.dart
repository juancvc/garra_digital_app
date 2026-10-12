import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../chat/data/chat_service.dart';
import '../../chat/presentation/chat_unread_badge.dart';
import '../../football/presentation/football_chat_room_view.dart';
import '../../../core/navigation/main_shell_branch_scope.dart';
import 'crema_chat_ambient_background.dart';

/// Tab Comunidad: conversación crema (Football Chat GENERAL).
class CommunitySocialPage extends StatelessWidget {
  const CommunitySocialPage({super.key, this.chatService});

  final ChatService? chatService;

  @override
  Widget build(BuildContext context) {
    final ambientActive = MainShellBranchScope.maybeOf(context)?.activeBranch == 1;
    final width = MediaQuery.sizeOf(context).width;
    final compactToolbar = width < 420;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: compactToolbar ? 12 : 16,
        title: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width - (compactToolbar ? 168 : 220),
          ),
          child: const Text(
            'Comunidad Crema',
            key: ValueKey('comunidad_crema_title'),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        ),
        actions: [
          GarraMessagesAction(showBadge: chatService != null),
          if (compactToolbar)
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) => _openMenuAction(context, value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'clans', child: Text('Comunidades Cremas')),
                PopupMenuItem(value: 'search', child: Text('Buscar')),
                PopupMenuItem(value: 'activity', child: Text('Actividad')),
              ],
            )
          else ...[
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
        ],
      ),
      backgroundColor: Colors.transparent,
      body: CremaChatAmbientBackground(
        active: ambientActive,
        child: FootballChatRoomView(
          key: const ValueKey('comunidad_general_chat'),
          surface: FootballChatSurface.community,
          focusMessageId: FootballChatRoomView.routeMessageId(context),
        ),
      ),
    );
  }

  void _openMenuAction(BuildContext context, String value) {
    switch (value) {
      case 'clans':
        context.push('/clans');
      case 'search':
        context.push('/comunidad/buscar');
      case 'activity':
        context.push('/notifications');
    }
  }
}
