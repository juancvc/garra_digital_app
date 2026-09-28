import 'package:flutter/material.dart';

import '../../../core/theme/garra_semantic_colors.dart';

/// Confirmation dialog for community administration / moderation actions.
Future<bool> showClanConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final colors = context.garraColors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      title: Text(title, style: TextStyle(color: colors.textPrimary)),
      content: Text(message, style: TextStyle(color: colors.textSecondary)),
      actions: [
        TextButton(
          key: const ValueKey('clan_confirm_cancel'),
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('clan_confirm_accept'),
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? colors.danger : colors.brandPrimary,
            foregroundColor: colors.onBrand,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Result of the "Expulsar y bloquear" dialog. Null when cancelled.
class ClanBanChoice {
  const ClanBanChoice(this.reason);

  final String? reason;
}

/// "Expulsar y bloquear" confirmation with an optional short reason.
Future<ClanBanChoice?> showClanBanDialog(
  BuildContext context, {
  required String name,
}) {
  return showDialog<ClanBanChoice>(
    context: context,
    builder: (_) => _ClanBanDialog(name: name),
  );
}

class _ClanBanDialog extends StatefulWidget {
  const _ClanBanDialog({required this.name});

  final String name;

  @override
  State<_ClanBanDialog> createState() => _ClanBanDialogState();
}

class _ClanBanDialogState extends State<_ClanBanDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        '\u00bfExpulsar y bloquear a ${widget.name}?',
        style: TextStyle(color: colors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No podr\u00e1 volver a unirse ni solicitar ingreso hasta que quites el bloqueo.',
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('clan_ban_reason'),
            controller: _reason,
            maxLength: 280,
            maxLines: 2,
            style: TextStyle(color: colors.textPrimary),
            decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('clan_confirm_cancel'),
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('clan_confirm_accept'),
          onPressed: () {
            final text = _reason.text.trim();
            Navigator.pop(context, ClanBanChoice(text.isEmpty ? null : text));
          },
          style: FilledButton.styleFrom(
            backgroundColor: colors.danger,
            foregroundColor: colors.onBrand,
          ),
          child: const Text('Expulsar y bloquear'),
        ),
      ],
    );
  }
}

String clanShortDate(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return '$dd/$mm/${local.year}';
}
