import 'package:flutter/material.dart';

import '../../../core/design/garra_colors.dart';
import '../../chat/data/chat_service.dart';
import '../../chat/presentation/floating_chat_panel.dart';

/// Consent-based chat with the fan who owns the listing.
class ConsultarPorChatButton extends StatefulWidget {
  const ConsultarPorChatButton({
    super.key,
    required this.sellerUserId,
    this.listingTitle = '',
    this.listingPrice = '',
    this.storeName = '',
    this.chatService,
  });

  final String sellerUserId;
  final String listingTitle;
  final String listingPrice;
  final String storeName;
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
      final relationship = await _chat.relationship(
        widget.sellerUserId,
        context: 'MARKETPLACE',
      );
      if (!mounted) return;
      if (relationship.blocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No puedes escribirle a este hincha')),
        );
        return;
      }
      await showGarraFloatingChat(
        context: context,
        chatService: _chat,
        otherUserId: widget.sellerUserId,
        listingTitle: widget.listingTitle,
        listingPrice: widget.listingPrice,
        storeName: widget.storeName,
        relationship: relationship,
        marketplace: true,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos iniciar el chat')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
