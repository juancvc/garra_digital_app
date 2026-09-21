import 'package:flutter/material.dart';

import '../config/api_config.dart';

/// Discrete STAGING badge — never shown for true production release hosts.
class StagingBanner extends StatelessWidget {
  const StagingBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.showStagingBadge) return child;
    return Banner(
      message: 'STAGING',
      location: BannerLocation.topEnd,
      color: const Color(0xCC8B1E2D),
      textStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: Color(0xFFF5F0E6),
      ),
      child: child,
    );
  }
}
