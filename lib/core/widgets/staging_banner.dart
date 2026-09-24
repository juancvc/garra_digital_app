import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../design/garra_colors.dart';

/// Non-intrusive staging indicator — no diagonal ribbon over the product UI.
class StagingBanner extends StatelessWidget {
  const StagingBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.showStagingBadge) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          right: 5,
          top: 3,
          child: IgnorePointer(
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(
                    GarraColors.burgundy,
                  ).withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'STAGING',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(GarraColors.cream),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
