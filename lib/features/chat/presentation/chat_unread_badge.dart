import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/chat_models.dart';
import '../data/chat_service.dart';

/// CHAT_V2_A: shared chat service for badge consumers (overridable in tests).
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

/// Global unread from `GET /chat/unread-count`: total plus the private /
/// community split, in ONE call (COMMUNITY_GROUP_CHAT_14C). No local counter
/// and no polling: it refreshes on mount, on app resume, when returning from
/// the chat screens and after a conversation or community chat is marked
/// read. Failures show no badge.
final chatUnreadCountProvider = FutureProvider.autoDispose<ChatUnreadSummary>((
  ref,
) async {
  try {
    return await ref.watch(chatServiceProvider).unreadSummary();
  } catch (_) {
    return ChatUnreadSummary.zero;
  }
});

/// Backend total for consumers that only need one number (global badge).
final chatUnreadTotalProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(chatUnreadCountProvider).value?.unreadCount ?? 0,
);

final communityChatPreviewsProvider = FutureProvider.autoDispose<Map<String, CommunityChatPreview>>((ref) async {
  try {
    final rows = await ref.watch(chatServiceProvider).communityPreviews();
    return {for (final row in rows) row.slug: row};
  } catch (_) {
    return {};
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

/// Reconciles the existing backend unread total while the app is in use.
/// Chat screens already refresh on read; this catches messages received while
/// the user is elsewhere without adding a second unread counter.
class ChatUnreadReconciler extends ConsumerStatefulWidget {
  const ChatUnreadReconciler({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ChatUnreadReconciler> createState() => _ChatUnreadReconcilerState();
}

class _ChatUnreadReconcilerState extends ConsumerState<ChatUnreadReconciler>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(chatUnreadCountProvider);
      if (mounted) ref.invalidate(communityChatPreviewsProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(chatUnreadCountProvider);
      ref.invalidate(communityChatPreviewsProvider);
      _start();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    // The backend total (private + community); never re-summed locally.
    final count = ref.watch(chatUnreadTotalProvider);
    return IconButton(
      key: const Key('messages-entry'),
      tooltip: 'Mensajes',
      onPressed: _open,
      icon: Badge(
        key: const Key('messages-entry-badge'),
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}
