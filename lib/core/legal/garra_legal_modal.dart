import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_spacing.dart';
import '../widgets/garra_ui.dart';
import 'garra_legal_documents.dart';

/// Modal in-app: título, contenido scrollable y botón Aceptar (solo cierra).
Future<void> showGarraLegalDocumentModal(
  BuildContext context,
  GarraLegalDocument document,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: const Color(GarraColors.surface),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GarraSpacing.lg,
                  GarraSpacing.md,
                  GarraSpacing.lg,
                  GarraSpacing.sm,
                ),
                child: Text(
                  document.title,
                  style: Theme.of(dialogContext).textTheme.headlineSmall?.copyWith(
                        color: const Color(GarraColors.cream),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(GarraSpacing.lg),
                  child: Text(
                    document.body,
                    style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                          color: const Color(GarraColors.creamMuted),
                          height: 1.45,
                        ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(GarraSpacing.lg),
                child: GarraPrimaryButton(
                  label: 'Aceptar',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
