import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_appearance.dart';
import '../../../core/theme/garra_semantic_colors.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(garraAppearanceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.md,
          GarraSpacing.lg,
          GarraSpacing.section,
        ),
        children: [
          _AppearanceOption(
            title: 'Sistema',
            subtitle: 'Usa la configuración de tu teléfono',
            selected: selected == GarraAppearance.system,
            preview: const _SplitPreview(),
            onTap: () => ref
                .read(garraAppearanceProvider.notifier)
                .select(GarraAppearance.system),
          ),
          _AppearanceOption(
            title: 'Crema',
            subtitle: 'Tema claro inspirado en la camiseta crema',
            selected: selected == GarraAppearance.crema,
            preview: const _ThemePreview(colors: GarraSemanticColors.crema),
            onTap: () => ref
                .read(garraAppearanceProvider.notifier)
                .select(GarraAppearance.crema),
          ),
          _AppearanceOption(
            title: 'Noche Monumental',
            subtitle: 'Tema oscuro para vivir la tribuna de noche',
            selected: selected == GarraAppearance.nocheMonumental,
            preview: const _ThemePreview(colors: GarraSemanticColors.noche),
            onTap: () => ref
                .read(garraAppearanceProvider.notifier)
                .select(GarraAppearance.nocheMonumental),
          ),
        ],
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(GarraRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GarraRadius.lg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GarraRadius.lg),
              border: Border.all(
                color: selected ? colors.brandPrimary : colors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(GarraSpacing.md),
              child: Row(
                children: [
                  preview,
                  const SizedBox(width: GarraSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected
                        ? colors.brandPrimary
                        : colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.colors});

  final GarraSemanticColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 88,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(GarraRadius.sm),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
          ),
          const Spacer(),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: colors.brandPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 28,
            height: 6,
            decoration: BoxDecoration(
              color: colors.brandPrestige,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitPreview extends StatelessWidget {
  const _SplitPreview();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(GarraRadius.sm),
      child: const SizedBox(
        width: 72,
        height: 88,
        child: Row(
          children: [
            Expanded(child: ColoredBox(color: Color(0xFFF5EAD5))),
            Expanded(child: ColoredBox(color: Color(0xFF0E0C0B))),
          ],
        ),
      ),
    );
  }
}
