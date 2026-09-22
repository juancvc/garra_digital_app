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
          left: 8,
          bottom: 8,
          child: IgnorePointer(
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(GarraColors.burgundy).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'STAGING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
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
