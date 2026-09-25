import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../data/first_launch_experience_service.dart';

/// Staging and debug replay of the first-use intro.
/// Hidden when [visible] is false so production builds stay quiet.
class IntroReplayAction extends StatelessWidget {
  const IntroReplayAction({
    super.key,
    required this.visible,
    this.intro,
    this.onReplay,
  });

  final bool visible;
  final FirstLaunchExperienceService? intro;
  final Future<void> Function()? onReplay;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return TextButton(
      onPressed: () async {
        if (onReplay != null) {
          await onReplay!();
          return;
        }
        await (intro ?? FirstLaunchExperienceService()).resetIntro();
        if (context.mounted) context.go('/intro');
      },
      child: const Text(
        'Reproducir introducción',
        style: TextStyle(color: Color(GarraColors.creamMuted)),
      ),
    );
  }
}
