import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/design/garra_spacing.dart';

enum GarraShareCardStyle { nocheGarra, cremaClasico, borgona }

/// Local-only share card — never uploaded to backend.
class GarraShareCard extends StatelessWidget {
  const GarraShareCard({
    super.key,
    required this.username,
    required this.content,
    required this.style,
    this.imageBytes,
    this.dateLabel,
  });

  final String username;
  final String content;
  final GarraShareCardStyle style;
  final List<int>? imageBytes;
  final String? dateLabel;

  Color get _bg {
    switch (style) {
      case GarraShareCardStyle.nocheGarra:
        return const Color(GarraColors.charcoal);
      case GarraShareCardStyle.cremaClasico:
        return const Color(GarraColors.cream);
      case GarraShareCardStyle.borgona:
        return const Color(GarraColors.garnetDeep);
    }
  }

  Color get _fg {
    switch (style) {
      case GarraShareCardStyle.cremaClasico:
        return const Color(GarraColors.garnetDeep);
      case GarraShareCardStyle.nocheGarra:
      case GarraShareCardStyle.borgona:
        return const Color(GarraColors.cream);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(GarraSpacing.lg),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(GarraColors.gold), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Garra Digital',
            style: TextStyle(
              color: Color(GarraColors.gold),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '@$username',
            style: TextStyle(color: _fg, fontWeight: FontWeight.w700),
          ),
          if (dateLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              dateLabel!,
              style: TextStyle(color: _fg.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            content,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _fg, fontSize: 16, height: 1.35),
          ),
          if (imageBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                Uint8List.fromList(imageBytes!),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Comunidad independiente de hinchas',
            style: TextStyle(color: _fg.withValues(alpha: 0.55), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

Future<void> shareGarraCardPng({
  required GlobalKey boundaryKey,
  required String text,
}) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/garra_share_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(bytes.buffer.asUint8List());
  await Share.shareXFiles([XFile(file.path)], text: text);
}
