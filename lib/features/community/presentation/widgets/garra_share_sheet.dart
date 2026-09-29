import 'package:flutter/material.dart';

import '../../../../core/network/offline_action_guard.dart';
import '../../data/community_service.dart';
import '../../data/wall_post_model.dart';

class GarraShareOutcome {
  const GarraShareOutcome({this.sharedPost, this.undoCount, this.external = false});

  final WallPostModel? sharedPost;
  final int? undoCount;
  final bool external;
}

/// Entry point shared by feed and detail. The caller owns local reconciliation.
Future<GarraShareOutcome?> showGarraShareSheet(
  BuildContext context, {
  required WallPostModel post,
  required CommunityService service,
}) {
  final original = post.originalPost;
  final postId = original?.id ?? post.id;
  final sharedByMe = post.sharedByMe;
  return showModalBottomSheet<GarraShareOutcome>(
    context: context,
    builder: (sheetContext) {
      var busy = false;
      String? error;
      return StatefulBuilder(builder: (context, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Compartir', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : () async {
                if (busy) return;
                if (!allowNetworkAction(context)) return;
                setState(() { busy = true; error = null; });
                try {
                  if (sharedByMe) {
                    final count = await service.undoGlobalShare(postId);
                    if (count == null) throw StateError('Respuesta de share inválida');
                    if (sheetContext.mounted) Navigator.pop(sheetContext, GarraShareOutcome(undoCount: count));
                  } else {
                    final result = await service.shareGlobalPost(postId);
                    if (!result.success || result.post == null) {
                      if (sheetContext.mounted) {
                        setState(() => error = result.message.isEmpty
                            ? 'No pudimos actualizar el compartido. Reintenta.'
                            : result.message);
                      }
                      return;
                    }
                    if (sheetContext.mounted) Navigator.pop(sheetContext, GarraShareOutcome(sharedPost: result.post));
                  }
                } catch (_) {
                  if (sheetContext.mounted) setState(() => error = 'No pudimos actualizar el compartido. Reintenta.');
                } finally {
                  if (sheetContext.mounted) setState(() => busy = false);
                }
              },
              icon: const Icon(Icons.repeat_rounded),
              label: Text(busy ? 'Procesando...' : sharedByMe ? 'Deshacer compartido' : 'Compartir en Garra'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : () => Navigator.pop(sheetContext, const GarraShareOutcome(external: true)),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Compartir en otras apps'),
            ),
            if (error != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ]),
        ),
      ));
    },
  );
}
