import 'package:flutter/material.dart';

import '../design/garra_spacing.dart';
import '../theme/garra_semantic_colors.dart';

/// Consistent sheet chrome: 24px radius, handle, semantic surface.
Future<T?> showGarraSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showHandle = true,
}) {
  final colors = context.garraColors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final bottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle)
              Padding(
                padding: const EdgeInsets.only(top: GarraSpacing.md),
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            builder(sheetContext),
          ],
        ),
      );
    },
  );
}
