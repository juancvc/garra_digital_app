import 'package:flutter/material.dart';

import '../../../../core/design/garra_colors.dart';
import '../../data/wall_post_model.dart';

/// Social media grid: 1 full / 2 split / 3 hero+2 / 4 2x2.
class GarraPostMediaGrid extends StatelessWidget {
  const GarraPostMediaGrid({
    super.key,
    required this.media,
    this.legacyImageUrl,
  });

  final List<WallPostMediaItem> media;
  final String? legacyImageUrl;

  List<String> get _urls {
    if (media.isNotEmpty) {
      final sorted = [...media]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return sorted
          .map((m) => m.url)
          .where((u) => u.isNotEmpty)
          .toList();
    }
    if (legacyImageUrl != null && legacyImageUrl!.isNotEmpty) {
      return [legacyImageUrl!];
    }
    return const [];
  }

  void _openViewer(BuildContext context, int index) {
    final urls = _urls;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MediaViewer(urls: urls, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) return const SizedBox.shrink();

    Widget tile(int i, {double? aspect}) {
      return GestureDetector(
        onTap: () => _openViewer(context, i),
        child: AspectRatio(
          aspectRatio: aspect ?? 1,
          child: Image.network(
            urls[i],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(GarraColors.surfaceRaised),
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      );
    }

    switch (urls.length) {
      case 1:
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: tile(0, aspect: 4 / 5),
        );
      case 2:
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Expanded(child: tile(0)),
              const SizedBox(width: 2),
              Expanded(child: tile(1)),
            ],
          ),
        );
      case 3:
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Expanded(flex: 2, child: tile(0, aspect: 3 / 4)),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: tile(1)),
                    const SizedBox(height: 2),
                    Expanded(child: tile(2)),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: tile(0)),
                  const SizedBox(width: 2),
                  Expanded(child: tile(1)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: tile(2)),
                  const SizedBox(width: 2),
                  Expanded(child: tile(3)),
                ],
              ),
            ],
          ),
        );
    }
  }
}

class _MediaViewer extends StatefulWidget {
  const _MediaViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: const Color(GarraColors.cream),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.network(widget.urls[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
