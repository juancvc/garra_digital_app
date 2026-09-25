import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_cached_network_image.dart';
import '../data/chat_models.dart';
import '../data/chat_service.dart';

/// Short video stays off until physical QA. Images are the V1 attachment.
const bool chatShortVideoEnabled = false;

Future<void> showGarraFloatingChat({
  required BuildContext context,
  required String otherUserId,
  ChatService? chatService,
  String otherDisplayName = '',
  String? listingTitle,
  String? listingPrice,
  String? openingSuggestion,
  ChatRelationship? relationship,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.65,
        maxChildSize: 0.85,
        builder: (context, scroll) {
          return _FloatingChatPanel(
            otherUserId: otherUserId,
            chatService: chatService,
            otherDisplayName: otherDisplayName,
            listingTitle: listingTitle,
            listingPrice: listingPrice,
            openingSuggestion: openingSuggestion,
            relationship: relationship,
            scroll: scroll,
          );
        },
      );
    },
  );
}

class _FloatingChatPanel extends StatefulWidget {
  const _FloatingChatPanel({
    required this.otherUserId,
    required this.scroll,
    this.chatService,
    this.otherDisplayName = '',
    this.listingTitle,
    this.listingPrice,
    this.openingSuggestion,
    this.relationship,
  });

  final String otherUserId;
  final ScrollController scroll;
  final ChatService? chatService;
  final String otherDisplayName;
  final String? listingTitle;
  final String? listingPrice;
  final String? openingSuggestion;
  final ChatRelationship? relationship;

  @override
  State<_FloatingChatPanel> createState() => _FloatingChatPanelState();
}

class _FloatingChatPanelState extends State<_FloatingChatPanel> {
  late final ChatService _chat = widget.chatService ?? ChatService();
  final _input = TextEditingController();
  final _media = MediaUploadService();
  final List<MediaDraft> _drafts = [];
  ChatConversation? _conversation;
  List<ChatMessage> _messages = const [];
  var _loading = true;
  var _sending = false;
  var _composingRequest = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final relationship = widget.relationship;
    final title = widget.listingTitle?.trim() ?? '';
    if (relationship == null ||
        relationship.status == 'NONE' ||
        relationship.conversationId == null) {
      _composingRequest = true;
      _loading = false;
      final suggested = widget.openingSuggestion?.trim();
      _input.text = suggested != null && suggested.isNotEmpty
          ? suggested
          : (title.isEmpty
                ? 'Hola'
                : 'Hola, me interesa $title. ¿Sigue disponible?');
    } else {
      _load(relationship.conversationId!);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load(String conversationId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conversation = await _chat.conversation(conversationId);
      final messages = await _chat.messages(conversationId);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _messages = messages;
        _composingRequest = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos abrir la conversación';
        _loading = false;
      });
    }
  }

  Future<void> _sendRequest() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final created = await _chat.request(
        widget.otherUserId,
        initialMessage: text,
      );
      final messages = await _chat.messages(created.id);
      if (!mounted) return;
      setState(() {
        _conversation = created;
        _messages = messages.isEmpty
            ? [
                ChatMessage(
                  id: 'local-open',
                  conversationId: created.id,
                  senderId: 'me',
                  content: text,
                  mine: true,
                ),
              ]
            : messages;
        _composingRequest = false;
        _sending = false;
        _input.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos enviar la consulta')),
      );
    }
  }

  Future<void> _send() async {
    final conversation = _conversation;
    if (conversation == null || conversation.status != 'ACTIVE' || _sending) {
      return;
    }
    final text = _input.text.trim();
    final ready = _drafts.where((d) => d.isReady && d.assetId != null).toList();
    if (text.isEmpty && ready.isEmpty) return;
    setState(() => _sending = true);
    try {
      final message = await _chat.send(
        conversation.id,
        text,
        mediaAssetIds: ready.map((d) => d.assetId!).toList(),
      );
      if (!mounted) return;
      _input.clear();
      setState(() {
        _messages = [..._messages, message];
        _drafts.clear();
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos enviar el mensaje')),
      );
    }
  }

  Future<void> _pickPhotos() async {
    if (_drafts.length >= 4) return;
    final files = await _media.pickMultiImage(max: 4 - _drafts.length);
    for (final file in files) {
      if (_drafts.length >= 4) break;
      final uploaded = await _media.uploadFile(
        file: file,
        purpose: MediaUploadPurpose.chatImage,
      );
      if (!mounted) return;
      setState(() => _drafts.add(uploaded));
    }
  }

  Future<void> _accept() async {
    final conversation = _conversation;
    if (conversation == null || _sending) return;
    setState(() => _sending = true);
    try {
      final accepted = await _chat.accept(conversation.id);
      if (!mounted) return;
      setState(() {
        _conversation = accepted;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  Future<void> _reject() async {
    final conversation = _conversation;
    if (conversation == null) return;
    await _chat.reject(conversation.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final name = conversation?.otherDisplayName.isNotEmpty == true
        ? conversation!.otherDisplayName
        : (widget.otherDisplayName.isNotEmpty
              ? widget.otherDisplayName
              : 'Chat');
    return Material(
      key: const Key('floating-chat-panel'),
      color: const Color(GarraColors.charcoal),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(GarraColors.borderSubtle),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                GarraAvatar(displayName: name, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_contextLine().isNotEmpty)
                        Text(
                          _contextLine(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('floating-chat-close'),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(GarraColors.borderSubtle)),
          if (conversation != null) _banner(conversation),
          Expanded(child: _body()),
          _footer(conversation),
        ],
      ),
    );
  }

  String _contextLine() {
    final title = widget.listingTitle?.trim() ?? '';
    if (title.isEmpty) {
      final status = _conversation?.status;
      if (status == 'PENDING') return 'Solicitud de chat';
      if (status == 'ACTIVE') return 'Conversación activa';
      return '';
    }
    final price = widget.listingPrice?.trim() ?? '';
    final priceBit = price.isEmpty ? '' : ' · $price';
    return 'Consultando: $title$priceBit';
  }

  Widget _banner(ChatConversation conversation) {
    if (conversation.status != 'PENDING') return const SizedBox.shrink();
    final outgoing = conversation.outgoing || _messages.any((m) => m.mine);
    return Container(
      key: const Key('chat-pending-banner'),
      width: double.infinity,
      color: const Color(GarraColors.surfaceRaised),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (outgoing) ...[
            Text(
              'Solicitud enviada',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Esperando que el vendedor acepte tu solicitud'),
          ] else
            const Text('Solicitud de chat'),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_composingRequest) {
      return ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Escribe el primer mensaje. El vendedor lo verá con tu solicitud.',
          ),
        ],
      );
    }
    return ListView.builder(
      controller: widget.scroll,
      padding: const EdgeInsets.all(GarraSpacing.lg),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Align(
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.media.isNotEmpty)
                  ChatImageStrip(media: message.media),
                if (message.content.trim().isNotEmpty)
                  Text(
                    message.content,
                    style: const TextStyle(color: Color(GarraColors.cream)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _footer(ChatConversation? conversation) {
    final pendingIn =
        conversation?.status == 'PENDING' &&
        conversation?.outgoing == false &&
        !_composingRequest;
    if (pendingIn) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
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
        ),
      );
    }
    final active = conversation?.status == 'ACTIVE';
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          8,
          8 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_drafts.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _drafts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return Stack(
                      children: [
                        Container(
                          key: Key('chat-image-preview-$index'),
                          width: 64,
                          height: 64,
                          color: const Color(GarraColors.surface),
                          child: draft.localPath == null
                              ? const Icon(Icons.image_outlined)
                              : Image.file(
                                  File(draft.localPath!),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: 'Quitar',
                            onPressed: () =>
                                setState(() => _drafts.removeAt(index)),
                            icon: const Icon(Icons.close, size: 16),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Row(
              children: [
                if (active)
                  IconButton(
                    key: const Key('chat-attach-photo'),
                    tooltip: 'Adjuntar foto',
                    onPressed: _drafts.length >= 4 || _sending
                        ? null
                        : _pickPhotos,
                    icon: const Icon(Icons.photo_outlined),
                  ),
                Expanded(
                  child: TextField(
                    key: Key(
                      _composingRequest
                          ? 'marketplace-chat-draft'
                          : 'chat-composer',
                    ),
                    controller: _input,
                    enabled: _composingRequest || active,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: _composingRequest || active
                          ? 'Escribe un mensaje...'
                          : 'Esperando que acepte tu solicitud',
                      filled: true,
                      fillColor: const Color(GarraColors.surface),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('chat-send'),
                  tooltip: 'Enviar',
                  onPressed: _sending
                      ? null
                      : (_composingRequest
                            ? _sendRequest
                            : (active ? _send : null)),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
            if (_composingRequest)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('marketplace-chat-send'),
                  onPressed: _sending ? null : _sendRequest,
                  child: const Text('Enviar consulta'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChatImageStrip extends StatelessWidget {
  const ChatImageStrip({super.key, required this.media});

  final List<ChatMediaItem> media;

  @override
  Widget build(BuildContext context) {
    final images = media.where((item) => !item.isVideo && item.url.isNotEmpty);
    return Column(
      children: [
        for (final item in images)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(
                        backgroundColor: Colors.black,
                        foregroundColor: const Color(GarraColors.cream),
                      ),
                      body: Center(
                        child: GarraCachedNetworkImage(imageUrl: item.url),
                      ),
                    ),
                  ),
                );
              },
              child: GarraCachedNetworkImage(
                imageUrl: item.url,
                height: 140,
                memCacheWidth: 480,
              ),
            ),
          ),
      ],
    );
  }
}
