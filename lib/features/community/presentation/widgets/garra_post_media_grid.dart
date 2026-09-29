import 'package:flutter/material.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/theme/garra_semantic_colors.dart';
import '../../../../core/widgets/garra_cached_network_image.dart';
import '../../data/wall_post_model.dart';

/// Opens the single fullscreen photo viewer (root navigator, above the shell
/// and bottom navigation). Black backdrop is intentional in both themes.
Future<void> openGarraMediaViewer(
  BuildContext context,
  List<String> urls, {
  int initialIndex = 0,
  VoidCallback? onViewPost,
}) {
  if (urls.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => _MediaViewer(
        urls: urls,
        initialIndex: initialIndex,
        onViewPost: onViewPost,
      ),
    ),
  );
}

/// Social media grid: 1 full / 2 split / 3 hero+2 / 4 2x2.
class GarraPostMediaGrid extends StatelessWidget {
  const GarraPostMediaGrid({
    super.key,
    required this.media,
    this.legacyImageUrl,
    this.onViewPost,
  });

  final List<WallPostMediaItem> media;
  final String? legacyImageUrl;
  final VoidCallback? onViewPost;

  List<String> get _urls {
    if (media.isNotEmpty) {
      final sorted = [...media]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return sorted.map((m) => m.url).where((u) => u.isNotEmpty).toList();
    }
    if (legacyImageUrl != null && legacyImageUrl!.isNotEmpty) {
      return [legacyImageUrl!];
    }
    return const [];
  }

  void _openViewer(BuildContext context, int index) {
    openGarraMediaViewer(
      context,
      _urls,
      initialIndex: index,
      onViewPost: onViewPost,
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) return const SizedBox.shrink();
    final backdrop = context.garraColors.mediaBackdrop;

    Widget image(int i) {
      return GestureDetector(
        key: ValueKey('post_media_$i'),
        // Opaque: the whole tile opens the viewer even while the image loads,
        // instead of falling through to the card's "open detail" tap.
        behavior: HitTestBehavior.opaque,
        onTap: () => _openViewer(context, i),
        child: GarraCachedNetworkImage(
          imageUrl: urls[i],
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: 960,
        ),
      );
    }

    switch (urls.length) {
      case 1:
        return ColoredBox(
          color: backdrop,
          child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            // Large editorial treatment without forcing a portrait crop.
            aspectRatio: 4 / 3,
            child: image(0),
          ),
          ),
        );
      case 2:
        return ColoredBox(
          color: backdrop,
          child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Row(
              children: [
                Expanded(child: image(0)),
                const SizedBox(width: 2),
                Expanded(child: image(1)),
              ],
            ),
          ),
          ),
        );
      case 3:
        // Bound height via AspectRatio so the right Column Expanded children
        // never receive unbounded constraints (overflow on narrow devices).
        return ColoredBox(
          color: backdrop,
          child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Row(
              children: [
                Expanded(flex: 2, child: image(0)),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: image(1)),
                      const SizedBox(height: 2),
                      Expanded(child: image(2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      default:
        final extra = urls.length - 4;
        return ColoredBox(
          color: backdrop,
          child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: image(0)),
                      const SizedBox(width: 2),
                      Expanded(child: image(1)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: image(2)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            image(3),
                            if (extra > 0)
                              Container(
                                color: Colors.black54,
                                alignment: Alignment.center,
                                child: Text(
                                  '+$extra',
                                  style: const TextStyle(
                                    color: Color(GarraColors.cream),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        );
    }
  }
}

class _MediaViewer extends StatefulWidget {
  const _MediaViewer({
    required this.urls,
    required this.initialIndex,
    this.onViewPost,
  });

  final List<String> urls;
  final int initialIndex;
  final VoidCallback? onViewPost;

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('garra_media_viewer'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: const Color(GarraColors.cream),
        actions: [
          if (widget.onViewPost != null)
            TextButton(
              key: const ValueKey('viewer_view_post'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(GarraColors.cream),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onViewPost!();
              },
              child: const Text('Ver publicación'),
            ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: GarraCachedNetworkImage(
              imageUrl: widget.urls[i],
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}
