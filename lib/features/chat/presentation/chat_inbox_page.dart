import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_states.dart';
import '../../community/presentation/widgets/garra_social_post_card.dart';
import '../data/chat_models.dart';
import '../data/chat_service.dart';

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tus mensajes';
        _loading = false;
      });
    }
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
      await _load();
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
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
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
                    selected: _requestsTab,
                    onTap: () => setState(() => _requestsTab = true),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(GarraColors.borderSubtle)),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return GarraErrorState(message: _error!, onRetry: _load);
    if (_requestsTab) return _requestsList();
    return _conversationList();
  }

  Widget _conversationList() {
    if (_conversations.isEmpty) {
      return const GarraEmptyState(
        title: 'Sin conversaciones',
        message: 'Cuando acepten tu solicitud, el chat aparece aquí.',
      );
    }
    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(GarraColors.borderSubtle)),
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final preview = conversation.lastMessagePreview?.trim();
        return InkWell(
          onTap: () => context.push('/chat/${conversation.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GarraSpacing.lg,
              vertical: 12,
            ),
            child: Row(
              children: [
                GarraAvatar(
                  displayName: conversation.otherDisplayName,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.otherDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview == null || preview.isEmpty
                            ? 'Conversación activa'
                            : preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _when(conversation.lastMessageAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (conversation.unreadCount > 0) ...[
                      const SizedBox(height: 6),
                      _UnreadBadge(count: conversation.unreadCount),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _requestsList() {
    if (_requests.isEmpty) {
      return const GarraEmptyState(
        title: 'Sin solicitudes',
        message: 'Las nuevas solicitudes de conversación llegan aquí.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: GarraSpacing.sm),
      itemCount: _requests.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(GarraColors.borderSubtle)),
      itemBuilder: (context, index) {
        final request = _requests[index];
        final busy = _busyId == request.id;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GarraSpacing.lg,
            vertical: GarraSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GarraAvatar(displayName: request.otherDisplayName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.otherDisplayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quiere iniciar una conversación contigo',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton(
                          key: Key('chat-request-reject-${request.id}'),
                          onPressed: busy
                              ? null
                              : () => _respond(request, accept: false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: const Color(GarraColors.cream),
                          ),
                          child: const Text('Rechazar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: Key('chat-request-accept-${request.id}'),
                          onPressed: busy
                              ? null
                              : () => _respond(request, accept: true),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: const Color(GarraColors.burgundy),
                            foregroundColor: const Color(GarraColors.cream),
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
        );
      },
    );
  }

  String _when(DateTime? value) {
    if (value == null) return '';
    return formatGarraRelativeTime(value.toUtc().toIso8601String());
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? const Color(GarraColors.burgundy)
            : const Color(GarraColors.surface),
        foregroundColor: const Color(GarraColors.cream),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      key: const Key('chat-unread-badge'),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(GarraColors.burgundy),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(GarraColors.cream),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
