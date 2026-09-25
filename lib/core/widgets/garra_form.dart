import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_spacing.dart';

class GarraFormIntro extends StatelessWidget {
  const GarraFormIntro({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(GarraColors.creamMuted),
            ),
          ),
        ],
      ),
    );
  }
}
