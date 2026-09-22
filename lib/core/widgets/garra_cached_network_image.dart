import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design/garra_colors.dart';

/// Shared cached image treatment for Garra network media.
class GarraCachedNetworkImage extends StatelessWidget {
  const GarraCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 240),
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ?? const _GarraImageFallback();
    if (imageUrl.trim().isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => placeholder ?? const _GarraImagePlaceholder(),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _GarraImagePlaceholder extends StatelessWidget {
  const _GarraImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garra_cached_image_placeholder'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(GarraColors.surfaceRaised),
            Color(GarraColors.garnetDeep),
            Color(GarraColors.surface),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.shield_outlined,
        color: Color(GarraColors.gold),
        size: 28,
      ),
    );
  }
}

class _GarraImageFallback extends StatelessWidget {
  const _GarraImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garra_cached_image_error'),
      color: const Color(GarraColors.surfaceRaised),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Color(GarraColors.creamMuted),
      ),
    );
  }
}
