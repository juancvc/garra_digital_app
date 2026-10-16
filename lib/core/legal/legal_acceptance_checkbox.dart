import 'package:flutter/material.dart';

import '../theme/garra_semantic_colors.dart';
import 'garra_legal_documents.dart';
import 'garra_legal_modal.dart';

/// PLAY-02: explicit, never pre-checked acceptance of the Terms (/legal/terms)
/// and the Privacy Policy (/legal/privacy). The texts themselves are served by
/// the backend legal pages; this widget does not contain legal copy.
class LegalAcceptanceCheckbox extends StatelessWidget {
  const LegalAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.error,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transparent Material: the tile may sit on a decorated auth card.
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            key: const ValueKey('legal-accept-checkbox'),
            value: value,
            enabled: enabled,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => onChanged(v ?? false),
            title: Text(
              'Acepto los T\u00e9rminos y condiciones y la Pol\u00edtica de privacidad.',
              style: TextStyle(color: colors.textPrimary, height: 1.3),
            ),
          ),
        ),
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              key: const ValueKey('legal-terms-link'),
              onPressed: () => showGarraLegalDocumentModal(
                context,
                GarraLegalDocument.terms,
              ),
              child: const Text('Ver T\u00e9rminos'),
            ),
            TextButton(
              key: const ValueKey('legal-privacy-link'),
              onPressed: () => showGarraLegalDocumentModal(
                context,
                GarraLegalDocument.privacy,
              ),
              child: const Text('Ver Privacidad'),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Text(
              error!,
              key: const ValueKey('legal-accept-error'),
              style: TextStyle(color: colors.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
