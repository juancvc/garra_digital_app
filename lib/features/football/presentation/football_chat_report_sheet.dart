import 'package:flutter/material.dart';

import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_sheet.dart';
import '../../community/data/community_report.dart';
import '../data/football_chat_service.dart';

const _footballReportDetailMax = 300;

Future<bool> showFootballChatReportSheet(
  BuildContext context, {
  required FootballChatService service,
  required String messageId,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final sent = await showGarraSheet<bool>(
    context: context,
    builder: (_) => FootballChatReportSheet(service: service, messageId: messageId),
  );
  if (sent != true) return false;
  messenger?.showSnackBar(
    const SnackBar(content: Text(garraReportThanksMessage)),
  );
  return true;
}

class FootballChatReportSheet extends StatefulWidget {
  const FootballChatReportSheet({
    super.key,
    required this.service,
    required this.messageId,
  });

  final FootballChatService service;
  final String messageId;

  @override
  State<FootballChatReportSheet> createState() => _FootballChatReportSheetState();
}

class _FootballChatReportSheetState extends State<FootballChatReportSheet> {
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
    final detail = _detailController.text.trim();
    final result = await widget.service.reportMessage(
      messageId: widget.messageId,
      category: reason,
      reason: detail.isEmpty ? null : detail,
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
        key: const ValueKey('football_report_sheet'),
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.md,
          GarraSpacing.lg,
          GarraSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Denunciar mensaje',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: GarraSpacing.sm),
            Text('Elige un motivo. Tu denuncia es confidencial.',
                style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: GarraSpacing.lg),
            for (final r in garraReportReasons)
              Padding(
                padding: const EdgeInsets.only(bottom: GarraSpacing.xs),
                child: RadioListTile<String>(
                  value: r.code,
                  groupValue: _reason,
                  onChanged: _sending ? null : (v) => setState(() => _reason = v),
                  title: Text(r.label),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            TextField(
              controller: _detailController,
              enabled: !_sending,
              maxLength: _footballReportDetailMax,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Detalle (opcional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GarraRadius.md)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: GarraSpacing.sm),
              Text(_error!, style: textTheme.bodySmall?.copyWith(color: colors.danger)),
            ],
            const SizedBox(height: GarraSpacing.md),
            FilledButton(
              onPressed: _sending || _reason == null ? null : _submit,
              child: Text(_sending ? 'Enviando…' : 'Enviar denuncia'),
            ),
          ],
        ),
      ),
    );
  }
}
