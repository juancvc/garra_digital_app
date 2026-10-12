import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../network/dio_client.dart';

import '../widgets/garra_cached_network_image.dart';

/// PRODUCT-06A: URL building for sticker WebP assets.
///
/// Base URL comes from `--dart-define=GARRA_STICKERS_ASSET_BASE_URL=...` or, at runtime,
/// from the backend `GET /api/v1/stickers/config` ([applyRemoteConfig]). No URL is
/// hardcoded: when empty, widgets render the glyph fallback (assets not published).
class GarraStickerAssets {
  GarraStickerAssets._();

  static const String _envBaseUrl = String.fromEnvironment('GARRA_STICKERS_ASSET_BASE_URL');
  static String? _runtimeBaseUrl;

  static String? get baseUrl {
    final v = _normalize(_runtimeBaseUrl) ?? _normalize(_envBaseUrl);
    return v;
  }

  static String? _normalize(String? raw) {
    if (raw == null) return null;
    var v = raw.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    // Only absolute http(s) origins/paths; no query, fragment or whitespace.
    return _validBase.hasMatch(v) ? v : null;
  }

  static final _validBase = RegExp(r'^https?://[^\s?#]+$');

  /// Only catalog-shaped object keys (no traversal, no absolute URLs, no client-made paths).
  static final validKey = RegExp(r'^garra/stickers/v\d+/(thumbs/)?[a-z0-9_]{1,64}\.webp$');

  /// Applies `data` of `GET /api/v1/stickers/config`. A null/empty base keeps the dart-define.
  static void applyRemoteConfig(Map<String, dynamic>? data) {
    final v = _normalize(data?['assetBaseUrl']?.toString());
    if (v != null) _runtimeBaseUrl = v;
  }

  static Future<void>? _remoteLoad;

  /// Fetches GET /stickers/config once per app run (best effort; failures keep fallback).
  static Future<void> ensureRemoteConfig({Dio? dio}) => _remoteLoad ??= () async {
        try {
          final res = await (dio ?? DioClient.instance).get('/stickers/config');
          final body = res.data;
          if (body is Map && body['data'] is Map) {
            applyRemoteConfig(Map<String, dynamic>.from(body['data'] as Map));
          }
        } catch (_) {
          _remoteLoad = null;
        }
      }();

  @visibleForTesting
  static void debugSetBaseUrl(String? value) => _runtimeBaseUrl = value;

  @visibleForTesting
  static void debugReset() {
    _runtimeBaseUrl = null;
    _remoteLoad = null;
  }

  /// 512 asset URL for [assetKey] (`garra/stickers/v1/{id}.webp`), or null.
  static String? fullUrl(String? assetKey, {String? base}) {
    final b = base == null ? baseUrl : _normalize(base);
    if (b == null || assetKey == null) return null;
    final key = assetKey.trim();
    if (!validKey.hasMatch(key)) return null;
    return '$b/$key';
  }

  /// 128 thumb URL: same folder + `thumbs/{id}.webp`, or null.
  static String? thumbUrl(String? assetKey, {String? base}) {
    if (assetKey == null) return null;
    final i = assetKey.lastIndexOf('/');
    if (i < 0) return null;
    return fullUrl('${assetKey.substring(0, i)}/thumbs/${assetKey.substring(i + 1)}', base: base);
  }
}

/// Shared renderer: cached WebP when published, glyph placeholder/fallback otherwise.
class GarraStickerImage extends StatelessWidget {
  const GarraStickerImage({
    super.key,
    required this.id,
    required this.assetKey,
    required this.glyph,
    this.size = 120,
    this.thumb = false,
  });

  final String id;
  final String? assetKey;
  final String glyph;
  final double size;
  final bool thumb;

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox(
      key: Key('garra-sticker-fallback-$id'),
      width: size,
      height: size,
      child: Center(
        child: Text(glyph.isEmpty ? '🦁' : glyph, style: TextStyle(fontSize: size * 0.45)),
      ),
    );
    final url = thumb ? GarraStickerAssets.thumbUrl(assetKey) : GarraStickerAssets.fullUrl(assetKey);
    if (url == null) return fallback;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    return SizedBox(
      key: Key('garra-sticker-image-$id'),
      width: size,
      height: size,
      child: GarraCachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        width: size,
        height: size,
        memCacheWidth: (size * dpr).round().clamp(64, thumb ? 128 : 512),
        placeholder: fallback,
        errorWidget: fallback,
      ),
    );
  }
}
