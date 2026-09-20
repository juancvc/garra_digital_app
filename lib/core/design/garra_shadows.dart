import 'package:flutter/material.dart';

import 'garra_colors.dart';

class GarraShadows {
  GarraShadows._();

  static List<BoxShadow> soft = [
    BoxShadow(
      color: const Color(GarraColors.charcoal).withValues(alpha: 0.45),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> glowGold = [
    BoxShadow(
      color: const Color(GarraColors.gold).withValues(alpha: 0.18),
      blurRadius: 28,
      offset: const Offset(0, 8),
    ),
  ];
}
