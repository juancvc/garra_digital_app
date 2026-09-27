import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../data/reaction_type.dart';
import 'garra_comment_reactions.dart';

Future<ReactionType?> showGarraReactionPicker(
  BuildContext context, {
  String? currentReaction,
}) {
  return showModalBottomSheet<ReactionType>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.garraColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(GarraRadius.xl)),
    ),
    builder: (context) {
      return GarraReactionPicker(currentReaction: currentReaction);
    },
  );
}

/// Modal bottom sheet with the full Garra reaction catalog (Spanish labels)
/// in a compact 4x2 grid. LOVE / FIRE / CARE / GARRA use vector glyphs; GARRA
/// is the Garra Digital mark. Theme tokens only (Crema and Noche).
class GarraReactionPicker extends StatelessWidget {
  const GarraReactionPicker({super.key, this.currentReaction, this.onSelected});

  final String? currentReaction;
  final ValueChanged<ReactionType>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final selected = ReactionType.tryParse(currentReaction);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.lg,
            GarraSpacing.md,
            GarraSpacing.lg,
            GarraSpacing.lg,
          ),
          child: Column(
            key: const ValueKey('post_reaction_picker'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(GarraRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: GarraSpacing.lg),
              Text(
                'Reaccionar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: GarraSpacing.sm),
              Text(
                selected == null
                    ? 'Elige c\u00f3mo sientes esta arenga'
                    : 'Toca tu reacci\u00f3n otra vez para quitarla',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: GarraSpacing.md),
              GarraReactionGrid(
                selected: selected,
                onSelected: (type) {
                  HapticFeedback.lightImpact();
                  if (onSelected != null) {
                    onSelected!(type);
                  } else {
                    Navigator.of(context).pop(type);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}