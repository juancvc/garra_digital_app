import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design/garra_colors.dart';
import '../network/private_media_loader.dart';
import '../theme/garra_semantic_colors.dart';

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
    this.memCacheWidth,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ?? const _GarraImageFallback();
    if (imageUrl.trim().isEmpty) return fallback;
    // PLAY-03.9: private chat images (relative API path / API origin) go
    // through the authenticated loader; public images are unchanged.
    final loader = PrivateMediaLoader.instance;
    if (loader.isPrivate(imageUrl)) {
      return _GarraPrivateImage(
        url: imageUrl,
        loader: loader,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        placeholder: placeholder ?? const _GarraImagePlaceholder(),
        fallback: fallback,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: fadeInDuration,
      memCacheWidth: memCacheWidth,
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => placeholder ?? const _GarraImagePlaceholder(),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _GarraPrivateImage extends StatefulWidget {
  const _GarraPrivateImage({
    required this.url,
    required this.loader,
    required this.fit,
    required this.placeholder,
    required this.fallback,
    this.width,
    this.height,
    this.memCacheWidth,
  });

  final String url;
  final PrivateMediaLoader loader;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final Widget placeholder;
  final Widget fallback;

  @override
  State<_GarraPrivateImage> createState() => _GarraPrivateImageState();
}

class _GarraPrivateImageState extends State<_GarraPrivateImage> {
  late Future<Uint8List> _future = widget.loader.load(widget.url);

  @override
  void didUpdateWidget(covariant _GarraPrivateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _future = widget.loader.load(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final cached = widget.loader.cached(widget.url);
    if (cached != null) return _image(cached);
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return _image(snapshot.data!);
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is PrivateMediaException && error.unavailable) {
            return const _GarraPrivateImageUnavailable();
          }
          return KeyedSubtree(key: const ValueKey('garra_private_image_error'), child: widget.fallback);
        }
        return SizedBox(width: widget.width, height: widget.height, child: widget.placeholder);
      },
    );
  }

  Widget _image(Uint8List bytes) => Image.memory(
        bytes,
        key: const ValueKey('garra_private_image'),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        cacheWidth: widget.memCacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      );
}

class _GarraPrivateImageUnavailable extends StatelessWidget {
  const _GarraPrivateImageUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garra_private_image_unavailable'),
      color: context.garraColors.surfaceRaised,
      alignment: Alignment.center,
      child: Semantics(
        label: 'Foto no disponible',
        child: Icon(Icons.hide_image_outlined, color: context.garraColors.textSecondary),
      ),
    );
  }
}

class _GarraImagePlaceholder extends StatelessWidget {
  const _GarraImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Container(
      key: const ValueKey('garra_cached_image_placeholder'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceRaised,
            const Color(GarraColors.garnetDeep),
            colors.surface,
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
      color: context.garraColors.surfaceRaised,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: context.garraColors.textSecondary,
      ),
    );
  }
}
