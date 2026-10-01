import 'package:flutter/material.dart';

import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_cached_network_image.dart';
import '../../community/presentation/widgets/garra_post_media_grid.dart'
    show openGarraMediaViewer;
import '../data/chat_models.dart';
import 'chat_audio_player.dart';

/// CHAT_V2_A: chat photos (up to 4) in a fixed-size grid, so the transcript
/// layout is stable before images load. Tap opens the shared fullscreen
/// viewer (UX_06). Videos stay hidden while short video is disabled.
class ChatMediaGrid extends StatelessWidget {
  const ChatMediaGrid({super.key, required this.media, this.maxWidth = 240});

  final List<ChatMediaItem> media;
  final double maxWidth;

  static const double _gap = 4;

  @override
  Widget build(BuildContext context) {
    final audio = media.where((item) => item.kind == 'AUDIO' && item.url.isNotEmpty).toList();
    if (audio.isNotEmpty) return ChatAudioPlayer(url: audio.first.url);
    final images = media
        .where((item) => item.kind == 'IMAGE' && item.url.isNotEmpty)
        .take(4)
        .toList();
    if (images.isEmpty) return const SizedBox.shrink();
    final urls = images.map((item) => item.url).toList();
    final width = maxWidth.clamp(120.0, 240.0);
    final half = (width - _gap) / 2;

    Widget tile(int index, double w, double h) {
      return GestureDetector(
        key: Key('chat-media-image-$index'),
        onTap: () => openGarraMediaViewer(context, urls, initialIndex: index),
        child: Semantics(
          button: true,
          label: 'Ver foto ${index + 1} de ${urls.length}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: context.garraColors.surfaceMuted,
              child: GarraCachedNetworkImage(
                imageUrl: urls[index],
                width: w,
                height: h,
                memCacheWidth: 480,
              ),
            ),
          ),
        ),
      );
    }

    if (images.length == 1) return tile(0, width, width * 0.75);
    final rows = <Widget>[];
    for (var i = 0; i < images.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: _gap));
      if (i + 1 < images.length) {
        rows.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(i, half, half),
              const SizedBox(width: _gap),
              tile(i + 1, half, half),
            ],
          ),
        );
      } else {
        rows.add(tile(i, width, half));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
