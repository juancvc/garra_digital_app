import 'package:flutter/material.dart';

import '../../../../core/network/offline_action_guard.dart';
import '../../../../core/navigation/draft_exit_guard.dart';
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
  if ((post.originalPost?.asPost() ?? post).isFollowersOnly) {
    return Future.value(null);
  }
  final original = post.originalPost;
  final postId = original?.id ?? post.id;
  final sharedByMe = post.sharedByMe;
  var caption = '';
  var permitExit = false;
  return showModalBottomSheet<GarraShareOutcome>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    isDismissible: false,
    builder: (sheetContext) {
      var busy = false;
      String? error;
      return StatefulBuilder(builder: (context, setState) => PopScope(
        canPop: !busy && (caption.trim().isEmpty || permitExit),
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || busy) return;
          if (await confirmDiscardDraft(context) && sheetContext.mounted) {
            permitExit = true;
            Navigator.pop(sheetContext);
          }
        },
        child: SafeArea(
        child: SingleChildScrollView(child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20,
              MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Compartir', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: busy ? null : () async {
                  if (caption.trim().isNotEmpty &&
                      !await confirmDiscardDraft(sheetContext)) {
                    return;
                  }
                  if (!sheetContext.mounted) {
                    return;
                  }
                  permitExit = true;
                  Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.close),
              ),
            ]),
            const SizedBox(height: 16),
            if (!sharedByMe) ...[
              TextFormField(
                maxLength: 220,
                maxLines: 3,
                minLines: 1,
                onChanged: (value) => setState(() => caption = value),
                decoration: const InputDecoration(hintText: 'Agrega un comentario (opcional)'),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: busy ? null : () async {
                if (busy) return;
                if (!allowNetworkAction(context)) return;
                setState(() { busy = true; error = null; });
                try {
                  if (sharedByMe) {
                    final count = await service.undoGlobalShare(postId);
                    if (count == null) throw StateError('Respuesta de share inválida');
                    if (sheetContext.mounted) { permitExit = true; Navigator.pop(sheetContext, GarraShareOutcome(undoCount: count)); }
                  } else {
                    final result = await service.shareGlobalPost(postId,
                        caption: caption.trim());
                    if (!result.success || result.post == null) {
                      if (sheetContext.mounted) {
                        setState(() => error = result.message.isEmpty
                            ? 'No pudimos actualizar el compartido. Reintenta.'
                            : result.message);
                      }
                      return;
                    }
                    if (sheetContext.mounted) { permitExit = true; Navigator.pop(sheetContext, GarraShareOutcome(sharedPost: result.post)); }
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
              onPressed: busy ? null : () async {
                if (caption.trim().isNotEmpty &&
                    !await confirmDiscardDraft(sheetContext)) {
                  return;
                }
                if (!sheetContext.mounted) {
                  return;
                }
                permitExit = true;
                Navigator.pop(sheetContext, const GarraShareOutcome(external: true));
              },
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Compartir en otras apps'),
            ),
            if (error != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ]),
        ),
      ))));
    },
  );
}
