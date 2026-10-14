import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/chat_message_reactions.dart';
import '../../data/community_report.dart';
import '../../data/community_service.dart';
import '../providers/community_provider.dart';
import 'garra_report_sheet.dart';

/// PLAY-02: safety actions on someone else's chat message (private chat and
/// community chat): "Denunciar mensaje", "Denunciar usuario" and "Bloquear
/// usuario". Reuses the shared report sheet and the existing block endpoint.
/// Never offered on own messages.
List<ChatMessageAction> chatMessageSafetyActions({
  required BuildContext context,
  required GarraReportTarget messageTarget,
  required String messageId,
  required String authorId,
  required String authorName,
  required String keyPrefix,
  CommunityService? service,
  VoidCallback? onBlocked,
}) {
  if (messageId.isEmpty || authorId.isEmpty) return const [];
  CommunityService resolveService() =>
      service ??
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(communityServiceProvider);
  return [
    ChatMessageAction(
      key: Key('$keyPrefix-action-report-message'),
      label: 'Denunciar mensaje',
      icon: Icons.flag_outlined,
      onSelected: () => showGarraReportSheet(
        context,
        service: resolveService(),
        target: messageTarget,
        targetId: messageId,
      ),
    ),
    ChatMessageAction(
      key: Key('$keyPrefix-action-report-user'),
      label: 'Denunciar usuario',
      icon: Icons.person_off_outlined,
      onSelected: () => showGarraReportSheet(
        context,
        service: resolveService(),
        target: GarraReportTarget.profile,
        targetId: authorId,
        title: 'Denunciar usuario',
      ),
    ),
    ChatMessageAction(
      key: Key('$keyPrefix-action-block-user'),
      label: 'Bloquear usuario',
      icon: Icons.block,
      destructive: true,
      onSelected: () => confirmAndBlockChatUser(
        context,
        service: resolveService(),
        userId: authorId,
        userName: authorName,
        onBlocked: onBlocked,
      ),
    ),
  ];
}

/// Confirmation + existing `POST /community/users/{id}/block`.
Future<bool> confirmAndBlockChatUser(
  BuildContext context, {
  required CommunityService service,
  required String userId,
  required String userName,
  VoidCallback? onBlocked,
}) async {
  final name = userName.trim().isEmpty ? 'este hincha' : userName.trim();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('\u00bfBloquear a $name?'),
      content: const Text(
        'No podr\u00e1 escribirte por privado ni ver\u00e1s su contenido. '
        'Puedes desbloquearlo desde tu perfil.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('chat-block-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Bloquear'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await service.blockUser(userId);
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('No pudimos bloquear. Int\u00e9ntalo de nuevo.'),
      ),
    );
    return false;
  }
  messenger?.showSnackBar(SnackBar(content: Text('Bloqueaste a $name.')));
  onBlocked?.call();
  return true;
}
