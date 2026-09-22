import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/design/garra_radius.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../data/reaction_type.dart';

Future<ReactionType?> showGarraReactionPicker(
  BuildContext context, {
  String? currentReaction,
}) {
  return showModalBottomSheet<ReactionType>(
    context: context,
    backgroundColor: const Color(GarraColors.surface),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(GarraRadius.xl)),
    ),
    builder: (context) {
      return GarraReactionPicker(currentReaction: currentReaction);
    },
  );
}

/// Modal bottom sheet with the 6 Garra reaction options (Spanish labels).
class GarraReactionPicker extends StatelessWidget {
  const GarraReactionPicker({super.key, this.currentReaction, this.onSelected});

  final String? currentReaction;
  final ValueChanged<ReactionType>? onSelected;

  @override
  Widget build(BuildContext context) {
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(
                      GarraColors.cream,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(GarraRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: GarraSpacing.lg),
              Text(
                'Reaccionar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(GarraColors.cream),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: GarraSpacing.sm),
              Text(
                'Elige cómo sientes esta arenga',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(GarraColors.textSecondary),
                ),
              ),
              const SizedBox(height: GarraSpacing.lg),
              ...ReactionType.all.map((type) {
                final isSelected = selected == type;
                return Padding(
                  padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
                  child: Material(
                    color: isSelected
                        ? const Color(
                            GarraColors.garnet,
                          ).withValues(alpha: 0.35)
                        : const Color(GarraColors.surfaceRaised),
                    borderRadius: BorderRadius.circular(GarraRadius.md),
                    child: InkWell(
                      key: ValueKey('reaction_option_${type.apiValue}'),
                      borderRadius: BorderRadius.circular(GarraRadius.md),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (onSelected != null) {
                          onSelected!(type);
                        } else {
                          Navigator.of(context).pop(type);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: GarraSpacing.lg,
                          vertical: GarraSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Text(
                              type.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: GarraSpacing.md),
                            Expanded(
                              child: Text(
                                type.labelEs,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: const Color(GarraColors.cream),
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(GarraColors.gold),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
