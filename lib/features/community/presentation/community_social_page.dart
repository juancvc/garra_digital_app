import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../chat/data/chat_service.dart';
import '../../home/presentation/social_feed_tab.dart';

/// Root Community destination: live social activity first, groups second.
class CommunitySocialPage extends StatelessWidget {
  const CommunitySocialPage({super.key, this.chatService});

  final ChatService? chatService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Comunidad'),
        actions: [
          IconButton(
            tooltip: 'Mensajes',
            onPressed: () => context.push('/chat'),
            icon: chatService == null
                ? const Icon(Icons.chat_bubble_outline)
                : _ChatBadge(chatService: chatService!),
          ),
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

class _ChatBadge extends StatefulWidget {
  const _ChatBadge({required this.chatService});

  final ChatService chatService;

  @override
  State<_ChatBadge> createState() => _ChatBadgeState();
}

class _ChatBadgeState extends State<_ChatBadge> {
  var _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final count = await widget.chatService.unreadCount();
      if (!mounted) return;
      setState(() => _count = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: _count > 0,
      label: Text(_count > 9 ? '9+' : '$_count'),
      backgroundColor: const Color(GarraColors.burgundy),
      textColor: const Color(GarraColors.cream),
      child: const Icon(Icons.chat_bubble_outline),
    );
  }
}
