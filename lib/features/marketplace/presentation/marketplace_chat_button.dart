import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/offline_action_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
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
    if (!allowNetworkAction(context)) return;
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
      // CHAT_V2_A: an ACTIVE thread opens the canonical chat screen; the
      // floating panel stays only for the first marketplace message.
      final conversationId = relationship.conversationId;
      final router = GoRouter.maybeOf(context);
      if (relationship.isActive && conversationId != null && router != null) {
        await router.push('/chat/$conversationId');
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
    // CHAT_V2_A_QA_FIX: theme tokens so the label stays visible in Crema and
    // Noche (the hardcoded cream label disappeared on the Crema background).
    // Secondary to the filled WhatsApp CTA: outlined, brand border.
    final colors = context.garraColors;
    return OutlinedButton.icon(
      key: const Key('marketplace-chat-cta'),
      onPressed: _busy ? null : _open,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.brandPrimary),
        minimumSize: const Size.fromHeight(48),
      ),
      icon: const Icon(Icons.chat_bubble_outline, size: 18),
      label: const Text('Consultar por chat'),
    );
  }
}
