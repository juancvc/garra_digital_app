import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'garra_sticker_assets.dart';

/// PRODUCT-07B: bounded, deduplicated warm-up of 128 px sticker thumbnails.
///
/// - Only thumbnails (`garra/stickers/v1/thumbs/{id}.webp`), never the 512 pack.
/// - Sequential (one download at a time) and at most [maxPerCall] new URLs per call.
/// - Each URL is requested at most once per app run (same URL = same cache key in the
///   shared `cached_network_image` disk cache used by [GarraStickerImage]).
/// - Fire-and-forget: never blocks the UI; failures are ignored (the renderer retries).
class GarraStickerPreloader {
  GarraStickerPreloader._();

  static const int maxPerCall = 16;
  static final Set<String> _requested = <String>{};
  static final List<(String, BuildContext)> _queue = <(String, BuildContext)>[];
  static Future<void>? _drain;

  @visibleForTesting
  static Future<void> Function(String url, BuildContext context)? debugFetch;

  @visibleForTesting
  static Set<String> get debugRequested => Set.unmodifiable(_requested);

  @visibleForTesting
  static void debugReset() {
    _requested.clear();
    _queue.clear();
    _drain = null;
    debugFetch = null;
  }

  /// Queues up to [limit] new thumbnail URLs; returns a future completing when the queue drains.
  static Future<void> warmThumbs(
    BuildContext context,
    Iterable<String?> assetKeys, {
    int limit = maxPerCall,
  }) {
    var added = 0;
    for (final key in assetKeys) {
      if (added >= limit) break;
      final url = GarraStickerAssets.thumbUrl(key);
      if (url == null || _requested.contains(url)) continue;
      _requested.add(url);
      _queue.add((url, context));
      added++;
    }
    return _drain ??= _run();
  }

  static Future<void> _run() async {
    try {
      // Sequential: one download at a time.
      while (_queue.isNotEmpty) {
        final (url, context) = _queue.removeAt(0);
        if (!context.mounted) continue;
        try {
          await (debugFetch ?? _precache)(url, context);
        } catch (_) {
          _requested.remove(url);
        }
      }
    } finally {
      _drain = null;
    }
  }

  static Future<void> _precache(String url, BuildContext context) =>
      precacheImage(
        CachedNetworkImageProvider(url),
        context,
        onError: (_, _) {},
      );
}
