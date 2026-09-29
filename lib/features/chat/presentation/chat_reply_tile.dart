import 'package:flutter/material.dart';
import '../data/chat_models.dart';

class ChatReplyTile extends StatelessWidget {
  const ChatReplyTile({
    super.key,
    required this.reply,
    this.onTap,
    this.onCancel,
  });
  final ChatReplyPreview reply;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    onCancel == null
                        ? reply.senderName
                        : 'Respondiendo a ${reply.senderName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    reply.deleted ? 'Mensaje eliminado' : reply.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onCancel != null)
              IconButton(
                tooltip: 'Cancelar respuesta',
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    ),
  );
}
