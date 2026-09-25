import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/chat_models.dart';
import '../data/chat_service.dart';
import 'floating_chat_panel.dart';

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.conversationId,
    this.chatService,
    this.pollInterval = const Duration(seconds: 5),
    this.requestJustSent = false,
  });

  final String conversationId;
  final ChatService? chatService;
  final Duration pollInterval;
  final bool requestJustSent;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage>
    with WidgetsBindingObserver {
  late final ChatService _chat = widget.chatService ?? ChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  ChatConversation? _conversation;
  List<ChatMessage> _messages = const [];
  var _loading = true;
  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _refresh();
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(widget.pollInterval, (_) => _refresh());
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conversation = await _chat.conversation(widget.conversationId);
      final messages = await _chat.messages(widget.conversationId);
      await _chat.markRead(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _messages = messages;
        _loading = false;
      });
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos abrir la conversación';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (!mounted || _sending) return;
    try {
      final conversation = await _chat.conversation(widget.conversationId);
      final messages = await _chat.messages(widget.conversationId);
      if (!mounted) return;
      final changed =
          messages.length != _messages.length ||
          (messages.isNotEmpty &&
              _messages.isNotEmpty &&
              messages.last.id != _messages.last.id);
      final statusChanged = conversation.status != _conversation?.status;
      if (!changed && !statusChanged && _conversation != null) return;
      setState(() {
        _conversation = conversation;
        _messages = messages;
      });
      if (changed) {
        await _chat.markRead(widget.conversationId);
        _scrollToEnd();
      }
    } catch (_) {
      // Keep the open transcript if a refresh fails.
    }
  }

  Future<void> _accept() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final accepted = await _chat.accept(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _conversation = accepted;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos aceptar la solicitud')),
      );
    }
  }

  Future<void> _reject() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _chat.reject(widget.conversationId);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos rechazar la solicitud')),
      );
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await _chat.send(widget.conversationId, text);
      if (!mounted) return;
      _input.clear();
      setState(() {
        _messages = [..._messages, message];
        _sending = false;
      });
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos enviar el mensaje')),
      );
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: conversation == null
            ? const Text('Mensajes')
            : InkWell(
                onTap: () =>
                    context.push('/comunidad/u/${conversation.otherUserId}'),
                child: Row(
                  children: [
                    GarraAvatar(
                      displayName: conversation.otherDisplayName,
                      avatarUrl: conversation.otherAvatarUrl,
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        conversation.otherDisplayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
      ),
      body: Column(
        children: [
          if (conversation != null) _statusBanner(conversation),
          Expanded(child: _transcript()),
          const Divider(height: 1, color: Color(GarraColors.borderSubtle)),
          SafeArea(top: false, child: _footer(conversation)),
        ],
      ),
    );
  }

  Widget _statusBanner(ChatConversation conversation) {
    if (conversation.status != 'PENDING') return const SizedBox.shrink();
    final waiting = conversation.outgoing
        ? 'Esperando que acepte tu solicitud'
        : 'Solicitud de chat';
    return Material(
      key: const Key('chat-pending-banner'),
      color: const Color(GarraColors.surfaceRaised),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GarraSpacing.lg,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.requestJustSent && conversation.outgoing) ...[
              Text(
                'Solicitud enviada',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'El vendedor podrá responder cuando acepte tu solicitud.',
              ),
              const SizedBox(height: 8),
            ],
            Text(waiting),
          ],
        ),
      ),
    );
  }

  Widget _footer(ChatConversation? conversation) {
    final pendingIncoming =
        conversation?.status == 'PENDING' && conversation?.outgoing == false;
    if (pendingIncoming) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('chat-reject-request'),
                onPressed: _sending ? null : _reject,
                child: const Text('Rechazar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('chat-accept-request'),
                onPressed: _sending ? null : _accept,
                child: const Text('Aceptar'),
              ),
            ),
          ],
        ),
      );
    }
    final canWrite = conversation?.status == 'ACTIVE';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat-composer'),
              controller: _input,
              enabled: canWrite && !_sending,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: canWrite ? (_) => _send() : null,
              decoration: InputDecoration(
                hintText: canWrite
                    ? 'Escribe un mensaje...'
                    : 'Esperando que acepte tu solicitud',
                filled: true,
                fillColor: const Color(GarraColors.surface),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: GarraSpacing.lg,
                  vertical: 12,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Enviar',
            onPressed: canWrite && !_sending ? _send : null,
            icon: const Icon(Icons.send_rounded),
            color: const Color(GarraColors.burgundy),
          ),
        ],
      ),
    );
  }

  Widget _transcript() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return GarraErrorState(message: _error!, onRetry: _load);
    if (_messages.isEmpty) {
      return const GarraEmptyState(
        title: 'Conversación lista',
        message: 'Escribe el primer mensaje.',
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(
        horizontal: GarraSpacing.lg,
        vertical: GarraSpacing.md,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Align(
          key: Key(message.mine ? 'chat-bubble-mine' : 'chat-bubble-other'),
          alignment: message.mine
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: message.mine
                  ? const Color(GarraColors.burgundy)
                  : const Color(GarraColors.surfaceRaised),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(message.mine ? 16 : 4),
                bottomRight: Radius.circular(message.mine ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.media.isNotEmpty)
                  ChatImageStrip(media: message.media),
                if (message.content.trim().isNotEmpty)
                  Text(
                    message.content,
                    style: const TextStyle(
                      color: Color(GarraColors.cream),
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
