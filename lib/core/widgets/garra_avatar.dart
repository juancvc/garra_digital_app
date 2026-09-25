import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../design/garra_typography.dart';
import 'garra_cached_network_image.dart';

class GarraAvatar extends StatelessWidget {
  const GarraAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.size = 72,
  });

  final String displayName;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(displayName);
    final hasUrl = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(GarraColors.garnetDeep),
            Color(GarraColors.garnet),
            Color(GarraColors.surfaceRaised),
          ],
        ),
        border: Border.all(color: const Color(GarraColors.gold), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? GarraCachedNetworkImage(
              imageUrl: avatarUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              memCacheWidth: (size * 2).round().clamp(48, 192),
              placeholder: _Initials(initials: initials, size: size),
              errorWidget: _Initials(initials: initials, size: size),
            )
          : _Initials(initials: initials, size: size),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'GC';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: GarraTypography.numeric(
          size: size * 0.32,
        ).copyWith(color: const Color(GarraColors.cream)),
      ),
    );
  }
}
