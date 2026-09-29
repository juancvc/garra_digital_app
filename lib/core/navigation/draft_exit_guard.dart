import 'package:flutter/material.dart';

/// Guards only exits that would discard locally prepared content.
class DraftExitGuard {
  bool _discardConfirmed = false;

  void permitExit() => _discardConfirmed = true;

  bool canPop({required bool dirty, required bool busy}) =>
      _discardConfirmed || (!dirty && !busy);

  Future<void> leave(
    BuildContext context, {
    required bool dirty,
    required bool busy,
    required VoidCallback pop,
    required VoidCallback refresh,
  }) async {
    if (busy) return;
    if (dirty && !await confirmDiscardDraft(context)) return;
    if (!context.mounted) return;
    permitExit();
    refresh();
    pop();
  }
}

Future<bool> confirmDiscardDraft(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Descartar borrador?'),
        content: const Text('Si sales ahora, perderás lo que estabas preparando.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    ) ??
    false;
