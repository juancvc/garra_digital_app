import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/chat_service.dart';

/// CHAT_V2_A: shared chat service for badge consumers (overridable in tests).
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

/// Global unread count from `GET /chat/unread-count`. No local counter and no
/// polling: it refreshes on mount, on app resume, when returning from the chat
/// screens and after a conversation is marked read. Failures show no badge.
final chatUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    return await ref.watch(chatServiceProvider).unreadCount();
  } catch (_) {
    return 0;
  }
});

/// Re-fetches the unread badge if a [ProviderScope] is available.
void refreshChatUnreadBadge(BuildContext context) {
  try {
    ProviderScope.containerOf(
      context,
      listen: false,
    ).invalidate(chatUnreadCountProvider);
  } on StateError {
    // Pumped without a ProviderScope (widget tests): nothing to refresh.
  }
}

/// App bar "Mensajes" action (Home and Comunidad) with the unread badge.
class GarraMessagesAction extends StatelessWidget {
  const GarraMessagesAction({super.key, this.showBadge = true});

  /// When false renders the plain icon and never calls the backend.
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    if (!showBadge) {
      return IconButton(
        key: const Key('messages-entry'),
        tooltip: 'Mensajes',
        onPressed: () => context.push('/chat'),
        icon: const Icon(Icons.chat_bubble_outline),
      );
    }
    return const _BadgedMessagesAction();
  }
}

class _BadgedMessagesAction extends ConsumerStatefulWidget {
  const _BadgedMessagesAction();

  @override
  ConsumerState<_BadgedMessagesAction> createState() =>
      _BadgedMessagesActionState();
}

class _BadgedMessagesActionState extends ConsumerState<_BadgedMessagesAction> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted) ref.invalidate(chatUnreadCountProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await context.push('/chat');
    if (mounted) ref.invalidate(chatUnreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(chatUnreadCountProvider).value ?? 0;
    return IconButton(
      key: const Key('messages-entry'),
      tooltip: 'Mensajes',
      onPressed: _open,
      icon: Badge(
        key: const Key('messages-entry-badge'),
        isLabelVisible: count > 0,
        label: Text(count > 9 ? '9+' : '$count'),
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}
