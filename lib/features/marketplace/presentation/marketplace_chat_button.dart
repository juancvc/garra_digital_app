import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../chat/data/chat_service.dart';

/// Consent-based chat with the fan who owns the listing.
class ConsultarPorChatButton extends StatefulWidget {
  const ConsultarPorChatButton({
    super.key,
    required this.sellerUserId,
    this.listingTitle = '',
    this.chatService,
  });

  final String sellerUserId;
  final String listingTitle;
  final ChatService? chatService;

  @override
  State<ConsultarPorChatButton> createState() => _ConsultarPorChatButtonState();
}

class _ConsultarPorChatButtonState extends State<ConsultarPorChatButton> {
  late final ChatService _chat = widget.chatService ?? ChatService();
  var _busy = false;

  Future<void> _open() async {
    if (_busy || widget.sellerUserId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final relationship = await _chat.relationship(widget.sellerUserId);
      if (!mounted) return;
      if (relationship.blocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No puedes escribirle a este hincha')),
        );
        return;
      }
      if (relationship.conversationId != null &&
          (relationship.isActive || relationship.isPending)) {
        context.push('/chat/${relationship.conversationId}');
        return;
      }
      final message = await _compose();
      if (message == null || !mounted) return;
      final created = await _chat.request(
        widget.sellerUserId,
        initialMessage: message,
      );
      if (!mounted) return;
      final sent = created.status == 'PENDING' ? '?sent=1' : '';
      context.push('/chat/${created.id}$sent');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos iniciar el chat')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _compose() {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(GarraColors.surface),
      builder: (ctx) => _ConsultarComposer(
        listingTitle: widget.listingTitle.trim(),
        suggestion: _suggestion(widget.listingTitle),
      ),
    );
  }

  String _suggestion(String title) {
    final name = title.trim();
    if (name.isEmpty) {
      return 'Hola, me interesa este anuncio. ¿Sigue disponible?';
    }
    return 'Hola, me interesa $name. ¿Sigue disponible?';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sellerUserId.isEmpty) return const SizedBox.shrink();
    return OutlinedButton(
      key: const Key('marketplace-chat-cta'),
      onPressed: _busy ? null : _open,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(GarraColors.cream),
        side: const BorderSide(color: Color(GarraColors.burgundy)),
        minimumSize: const Size.fromHeight(48),
      ),
      child: const Text('Consultar por chat'),
    );
  }
}

class _ConsultarComposer extends StatefulWidget {
  const _ConsultarComposer({
    required this.listingTitle,
    required this.suggestion,
  });

  final String listingTitle;
  final String suggestion;

  @override
  State<_ConsultarComposer> createState() => _ConsultarComposerState();
}

class _ConsultarComposerState extends State<_ConsultarComposer> {
  late final TextEditingController _draft = TextEditingController(
    text: widget.suggestion,
  );

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Consultar al vendedor',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (widget.listingTitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.listingTitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const Key('marketplace-chat-draft'),
            controller: _draft,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Color(GarraColors.charcoal),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('marketplace-chat-send'),
            onPressed: () {
              final text = _draft.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context, text);
            },
            child: const Text('Enviar consulta'),
          ),
        ],
      ),
    );
  }
}
