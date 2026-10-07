import 'package:flutter/material.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/solidarity_service.dart';

/// Short "\u00bfC\u00f3mo funciona?" explanation of the real lifecycle. A plain bottom
/// sheet: no onboarding framework, no first-run flags.
Future<void> showSolidariaHowItWorks(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => const SolidariaHowItWorksSheet(),
  );
}

class SolidariaHowItWorksSheet extends StatelessWidget {
  const SolidariaHowItWorksSheet({super.key});

  static const _steps = <(IconData, String, String)>[
    (
      Icons.edit_note_outlined,
      'Prop\u00f3n una iniciativa',
      'Cuenta qu\u00e9 ayuda se necesita, d\u00f3nde y c\u00f3mo pueden contactarte.',
    ),
    (
      Icons.hourglass_top_outlined,
      'Garra la revisa',
      'Queda \u201cEn revisi\u00f3n\u201d y no es p\u00fablica hasta que el equipo de Garra la apruebe.',
    ),
    (
      Icons.volunteer_activism_outlined,
      'Se publica',
      'Si se aprueba, aparece en Garra Solidaria con tu contacto para que la comunidad te ayude.',
    ),
    (
      Icons.replay_outlined,
      'Si no se aprueba',
      'Ver\u00e1s el motivo en \u201cMis iniciativas\u201d y podr\u00e1s corregirla y reenviarla.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('solidaria_how_it_works'),
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          0,
          GarraSpacing.lg,
          GarraSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\u00bfC\u00f3mo funciona Garra Solidaria?',
              style: text.titleLarge,
            ),
            const SizedBox(height: GarraSpacing.sm),
            Text(
              'Garra Solidaria conecta a la comunidad para apoyar iniciativas y '
              'casos que necesitan ayuda.',
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: GarraSpacing.md),
            for (final step in _steps)
              Padding(
                padding: const EdgeInsets.only(bottom: GarraSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(step.$1, color: colors.brandPrestige),
                    const SizedBox(width: GarraSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.$2, style: text.titleSmall),
                          const SizedBox(height: 2),
                          Text(step.$3, style: text.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Garra no procesa dinero, donaciones ni pagos. La ayuda se coordina '
              'directamente con quien publica la iniciativa.',
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: GarraSpacing.lg),
            GarraPrimaryButton(
              label: 'Entendido',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Solidaria initiative reviewed and approved by Garra. Deliberately a
/// different icon/colour/wording from the "Garra Oficial" account badge.
class SolidarityVerifiedChip extends StatelessWidget {
  const SolidarityVerifiedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.garraColors.success;
    return Row(
      key: const ValueKey('solidarity_verified_chip'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.volunteer_activism_outlined, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'Iniciativa verificada',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Owner-facing state (Borrador / En revisi\u00f3n / Publicada / No aprobada /
/// Finalizada). Non-public campaigns are only ever shown to their owner
/// (and staff); PENDING never looks verified and REJECTED is explicit.
class SolidarityStateChip extends StatelessWidget {
  const SolidarityStateChip(this.campaign, {super.key});

  final SolidarityCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final state = campaign.ownerState;
    final (IconData icon, Color color) = switch (state) {
      SolidarityOwnerState.draft => (Icons.edit_outlined, colors.textSecondary),
      SolidarityOwnerState.inReview => (
        Icons.hourglass_top_outlined,
        colors.warning,
      ),
      SolidarityOwnerState.published => (
        Icons.volunteer_activism_outlined,
        colors.success,
      ),
      SolidarityOwnerState.rejected => (Icons.block_outlined, colors.danger),
      SolidarityOwnerState.closed => (
        Icons.check_circle_outline,
        colors.textSecondary,
      ),
    };
    return Row(
      key: ValueKey(
        'solidarity_review_${campaign.verificationStatus.toLowerCase()}',
      ),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            solidarityStateLabel(state),
            key: ValueKey('solidarity_state_${state.name}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
