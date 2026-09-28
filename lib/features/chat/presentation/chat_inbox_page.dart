import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/utils/garra_message_time.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/chat_models.dart';
import '../data/chat_service.dart';
import 'chat_unread_badge.dart';

/// CHAT_V2_A: professional inbox. Conversaciones (ACTIVE) and Solicitudes
/// (incoming PENDING). No permanent polling: loads on open, pull-to-refresh
/// and silently again when returning from a conversation.
class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({super.key, this.chatService});

  final ChatService? chatService;

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  late final ChatService _chat = widget.chatService ?? ChatService();
  var _requestsTab = false;
  var _loading = true;
  String? _error;
  List<ChatConversation> _conversations = const [];
  List<ChatConversation> _requests = const [];
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _chat.conversations(),
        _chat.incoming(),
      ]);
      if (!mounted) return;
      setState(() {
        _conversations = results[0];
        _requests = results[1];
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent && !_loading && _error == null) return;
      setState(() {
        _error = 'No pudimos cargar tus mensajes';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _load(silent: true);
    if (mounted) refreshChatUnreadBadge(context);
  }

  Future<void> _open(ChatConversation conversation) async {
    await context.push('/chat/${conversation.id}');
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _respond(
    ChatConversation request, {
    required bool accept,
  }) async {
    setState(() => _busyId = request.id);
    try {
      if (accept) {
        await _chat.accept(request.id);
      } else {
        await _chat.reject(request.id);
      }
      if (!mounted) return;
      setState(() {
        _busyId = null;
        if (accept) _requestsTab = false;
      });
      await _load();
      if (mounted) refreshChatUnreadBadge(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos responder la solicitud')),
      );
      setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Mensajes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              GarraSpacing.sm,
              GarraSpacing.lg,
              GarraSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Segment(
                    label: 'Conversaciones',
                    selected: !_requestsTab,
                    onTap: () => setState(() => _requestsTab = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Segment(
                    label: 'Solicitudes',
                    count: _requests.length,
                    selected: _requestsTab,
                    onTap: () => setState(() => _requestsTab = true),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return GarraErrorState(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      key: const Key('chat-inbox-refresh'),
      onRefresh: _refresh,
      child: _requestsTab ? _requestsList() : _conversationList(),
    );
  }

  Widget _scrollableEmpty(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: constraints.maxHeight, child: child)],
      ),
    );
  }

  Widget _conversationList() {
    if (_conversations.isEmpty) {
      return _scrollableEmpty(
        const GarraEmptyState(
          title: 'A\u00fan no tienes conversaciones',
          message:
              'Escr\u00edbele a otro hincha desde su perfil o consulta un '
              'producto en Marketplace. Tus chats aparecer\u00e1n aqu\u00ed.',
        ),
      );
    }
    final colors = context.garraColors;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _conversations.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 76, color: colors.border),
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        return _ConversationRow(
          conversation: conversation,
          onTap: () => _open(conversation),
        );
      },
    );
  }

  Widget _requestsList() {
    if (_requests.isEmpty) {
      return _scrollableEmpty(
        const GarraEmptyState(
          title: 'Sin solicitudes',
          message:
              'Cuando otro hincha quiera conversar contigo, lo ver\u00e1s aqu\u00ed.',
        ),
      );
    }
    final colors = context.garraColors;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: GarraSpacing.sm),
      itemCount: _requests.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 76, color: colors.border),
      itemBuilder: (context, index) {
        final request = _requests[index];
        return _RequestRow(
          request: request,
          busy: _busyId == request.id,
          onOpen: () => _open(request),
          onAccept: () => _respond(request, accept: true),
          onReject: () => _respond(request, accept: false),
        );
      },
    );
  }
}

String _conversationPreview(ChatConversation conversation, String fallback) {
  final preview = conversation.lastMessagePreview?.trim() ?? '';
  return preview.isEmpty ? fallback : preview;
}

/// "Marketplace · {listingTitle}" only for MARKETPLACE threads with a title.
String? chatMarketplaceContextLabel(ChatConversation conversation) {
  if (conversation.context != 'MARKETPLACE') return null;
  final title = conversation.listingTitle?.trim() ?? '';
  if (title.isEmpty) return null;
  return 'Marketplace \u00b7 $title';
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final unread = conversation.unreadCount > 0;
    final marketplace = chatMarketplaceContextLabel(conversation);
    final time = formatGarraInboxTime(conversation.lastMessageAt);
    return InkWell(
      key: Key('chat-inbox-row-${conversation.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GarraSpacing.lg,
          vertical: 12,
        ),
        child: Row(
          children: [
            GarraAvatar(
              displayName: conversation.otherDisplayName,
              avatarUrl: conversation.otherAvatarUrl,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.otherDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          time,
                          key: Key('chat-inbox-time-${conversation.id}'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: unread
                                ? colors.brandPrimary
                                : colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (marketplace != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      marketplace,
                      key: Key('chat-inbox-context-${conversation.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _conversationPreview(
                            conversation,
                            'Conversaci\u00f3n activa',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: unread
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: unread
                                ? colors.textPrimary
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: conversation.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.busy,
    required this.onOpen,
    required this.onAccept,
    required this.onReject,
  });

  final ChatConversation request;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final time = formatGarraInboxTime(request.lastMessageAt);
    return InkWell(
      key: Key('chat-request-row-${request.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GarraSpacing.lg,
          vertical: 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GarraAvatar(
              displayName: request.otherDisplayName,
              avatarUrl: request.otherAvatarUrl,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.otherDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _conversationPreview(
                      request,
                      'Quiere iniciar una conversaci\u00f3n contigo',
                    ),
                    key: Key('chat-request-preview-${request.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        key: Key('chat-request-state-${request.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Solicitud pendiente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        key: Key('chat-request-reject-${request.id}'),
                        onPressed: busy ? null : onReject,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.border),
                        ),
                        child: const Text('Rechazar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: Key('chat-request-accept-${request.id}'),
                        onPressed: busy ? null : onAccept,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: colors.brandPrimary,
                          foregroundColor: colors.onBrand,
                        ),
                        child: const Text('Aceptar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: selected ? colors.brandPrimary : colors.surface,
        foregroundColor: selected ? colors.onBrand : colors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected ? BorderSide.none : BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              key: const Key('chat-requests-count'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? colors.onBrand : colors.brandPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.brandPrimary : colors.onBrand,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final label = count > 9 ? '9+' : '$count';
    return Semantics(
      label: '$count sin leer',
      excludeSemantics: true,
      child: Container(
        key: const Key('chat-unread-badge'),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.brandPrimary,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.onBrand,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
