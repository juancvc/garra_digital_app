import 'package:flutter/material.dart';

/// Supplied puma identity plates, shared by the intro and the entry crest.
abstract final class GarraIntroAssets {
  static const puma = 'assets/brand/intro/garra_puma.png';
  static const garra = 'assets/brand/intro/garra_wordmark.png';
  static const digital = 'assets/brand/intro/digital_wordmark.png';

  static const all = [puma, garra, digital];
}

/// Compact puma crest cropped from the cinematic plate.
class GarraPumaCrest extends StatelessWidget {
  const GarraPumaCrest({super.key, this.size = 88});

  final double size;

  static const _lumaToAlpha = ColorFilter.matrix(<double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0.25,
    0.65,
    0.10,
    0,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('garra-puma-crest'),
      width: size,
      height: size,
      child: ClipOval(
        child: ColorFiltered(
          colorFilter: _lumaToAlpha,
          child: Image(
            image: ResizeImage(
              const AssetImage(GarraIntroAssets.puma),
              width: 640,
            ),
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.08),
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
