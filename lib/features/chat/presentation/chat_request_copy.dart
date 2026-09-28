import '../data/chat_models.dart';

/// Copy for a pending chat request (FIX_10).
///
/// Social requests (e.g. from a fan profile) must not talk about a
/// "vendedor"; Marketplace conversations keep their commercial copy.
class ChatRequestCopy {
  const ChatRequestCopy({required this.marketplace, this.otherDisplayName});

  /// Uses the real conversation context when a conversation exists and falls
  /// back to [marketplaceFallback] (e.g. the floating panel `marketplace`
  /// flag) before the first message creates it.
  factory ChatRequestCopy.resolve({
    ChatConversation? conversation,
    bool marketplaceFallback = false,
    String? fallbackDisplayName,
  }) {
    final context = conversation?.context.trim().toUpperCase() ?? '';
    final name = conversation?.otherDisplayName.trim() ?? '';
    return ChatRequestCopy(
      marketplace: context.isEmpty
          ? marketplaceFallback
          : context == marketplaceContext,
      otherDisplayName: name.isNotEmpty ? name : fallbackDisplayName,
    );
  }

  static const marketplaceContext = 'MARKETPLACE';
  static const _genericWaiting = 'Esperando que acepte tu solicitud';

  final bool marketplace;
  final String? otherDisplayName;

  /// First word of the other participant's display name, or '' if unknown.
  String get firstName {
    final trimmed = otherDisplayName?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get _socialWaiting => firstName.isEmpty
      ? _genericWaiting
      : 'Esperando que $firstName acepte tu solicitud';

  /// Pending banner of the floating chat panel.
  String get waitingForAcceptance => marketplace
      ? 'Esperando que el vendedor acepte tu solicitud'
      : _socialWaiting;

  /// Pending status line of the conversation page.
  String get pendingStatus => marketplace ? _genericWaiting : _socialWaiting;

  /// Shown under "Solicitud enviada" right after sending a request.
  String get replyAfterAcceptance => marketplace
      ? 'El vendedor podrá responder cuando acepte tu solicitud.'
      : 'Podrá responder cuando acepte tu solicitud.';

  /// Hint while composing the first message of a request.
  String get firstMessageHint => marketplace
      ? 'Escribe el primer mensaje. El vendedor lo verá con tu solicitud.'
      : 'Escribe el primer mensaje. Lo verá con tu solicitud.';

  /// Hint of the disabled composer. Names the other fan only while our own
  /// request is pending; any other blocked state keeps the generic text.
  String blockedComposerHint({required bool pendingOutgoing}) =>
      pendingOutgoing ? pendingStatus : _genericWaiting;
}
