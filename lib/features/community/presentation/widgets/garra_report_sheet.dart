import 'package:flutter/material.dart';

import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_sheet.dart';
import '../../data/community_report.dart';
import '../../data/community_service.dart';

/// Default sheet titles per target.
String garraReportTitle(GarraReportTarget target) {
  switch (target) {
    case GarraReportTarget.post:
      return 'Denunciar publicaci\u00f3n';
    case GarraReportTarget.comment:
      return 'Denunciar comentario';
    case GarraReportTarget.profile:
      return 'Denunciar perfil';
  }
}

/// MODERATION_11: shared report flow for posts, comments and profiles.
///
/// Opens [GarraReportSheet]; on success the sheet closes and the snackbar
/// "Gracias. Revisaremos tu denuncia." is shown. Returns true when the report
/// was accepted by the backend.
Future<bool> showGarraReportSheet(
  BuildContext context, {
  required CommunityService service,
  required GarraReportTarget target,
  required String targetId,
  String? title,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final sent = await showGarraSheet<bool>(
    context: context,
    builder: (_) => GarraReportSheet(
      service: service,
      target: target,
      targetId: targetId,
      title: title,
    ),
  );
  if (sent != true) return false;
  messenger?.showSnackBar(
    const SnackBar(content: Text(garraReportThanksMessage)),
  );
  return true;
}

/// Reason list, optional detail and "Enviar denuncia". Errors keep the sheet
/// open with the backend message (e.g. "Ya denunciaste este contenido.").
class GarraReportSheet extends StatefulWidget {
  const GarraReportSheet({
    super.key,
    required this.service,
    required this.target,
    required this.targetId,
    this.title,
  });

  final CommunityService service;
  final GarraReportTarget target;
  final String targetId;
  final String? title;

  @override
  State<GarraReportSheet> createState() => _GarraReportSheetState();
}

class _GarraReportSheetState extends State<GarraReportSheet> {
  final _detailController = TextEditingController();
  String? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (_sending || reason == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await widget.service.createReport(
      target: widget.target,
      targetId: widget.targetId,
      reason: reason,
      detail: _detailController.text,
    );
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        key: const ValueKey('report_sheet'),
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.md,
          GarraSpacing.lg,
          GarraSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title ?? garraReportTitle(widget.target),
                style: textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: GarraSpacing.xs),
              Text(
                '\u00bfPor qu\u00e9 quieres denunciar esto?',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: GarraSpacing.sm),
              for (final reason in garraReportReasons)
                _ReasonTile(
                  reason: reason,
                  selected: _reason == reason.code,
                  onTap: _sending
                      ? null
                      : () => setState(() {
                          _reason = reason.code;
                          _error = null;
                        }),
                ),
              if (_reason != null) ...[
                const SizedBox(height: GarraSpacing.md),
                TextField(
                  key: const ValueKey('report_detail_field'),
                  controller: _detailController,
                  enabled: !_sending,
                  maxLength: garraReportDetailMaxLength,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Cu\u00e9ntanos un poco m\u00e1s',
                    hintText: 'Opcional',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  _error!,
                  key: const ValueKey('report_error'),
                  style: textTheme.bodyMedium?.copyWith(color: colors.danger),
                ),
              ],
              const SizedBox(height: GarraSpacing.md),
              FilledButton(
                key: const ValueKey('report_submit'),
                onPressed: _reason == null || _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brandPrimary,
                  foregroundColor: colors.onBrand,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _sending
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onBrand,
                        ),
                      )
                    : const Text('Enviar denuncia'),
              ),
              TextButton(
                key: const ValueKey('report_cancel'),
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final GarraReportReason reason;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('report_reason_${reason.code}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(GarraRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.brandPrimary : colors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: GarraSpacing.md),
              Expanded(
                child: Text(
                  reason.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
