import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../chat/data/chat_service.dart';

/// Consent-based chat with the fan who owns the listing.
class ConsultarPorChatButton extends StatefulWidget {
  const ConsultarPorChatButton({
    super.key,
    required this.sellerUserId,
    this.chatService,
  });

  final String sellerUserId;
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
      if (relationship.isActive && relationship.conversationId != null) {
        context.push('/chat/${relationship.conversationId}');
        return;
      }
      if (relationship.isPending) {
        _sent();
        return;
      }
      final created = await _chat.request(widget.sellerUserId);
      if (!mounted) return;
      if (created.status == 'ACTIVE') {
        context.push('/chat/${created.id}');
        return;
      }
      _sent();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos iniciar el chat')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sent() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud enviada')),
    );
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
