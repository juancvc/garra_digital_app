import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../auth/session_events.dart';
import '../config/api_config.dart';
import 'dio_client.dart';

/// PLAY-03.9: private chat images are served only by the authenticated API
/// (`/chat/messages/{id}/media/{assetId}`, `/clans/{slug}/chat/...`).
///
/// A URL is private only when it is a relative API path ("/x", never "//x")
/// or an absolute URL whose scheme, host and port equal the API base and whose
/// path is under the API base path. Anything else is public and must never
/// receive the bearer token.
bool isPrivateApiMediaUrl(String url, {String? apiBaseUrl}) {
  final value = url.trim();
  if (value.isEmpty) return false;
  if (value.startsWith('/')) return !value.startsWith('//') && !value.contains('\\');
  final target = Uri.tryParse(value);
  if (target == null || !target.hasScheme || target.host.isEmpty) return false;
  String base;
  try {
    base = apiBaseUrl ?? ApiConfig.baseUrl;
  } catch (_) {
    return false;
  }
  final api = Uri.tryParse(base);
  if (api == null || api.host.isEmpty) return false;
  if (target.userInfo.isNotEmpty) return false;
  if (target.scheme.toLowerCase() != api.scheme.toLowerCase()) return false;
  if (target.host.toLowerCase() != api.host.toLowerCase()) return false;
  if (target.port != api.port) return false;
  final basePath = api.path.endsWith('/') ? api.path : '${api.path}/';
  return target.path.startsWith(basePath);
}

class PrivateMediaException implements Exception {
  const PrivateMediaException(this.statusCode);

  /// HTTP status (401 session, 403/404 not allowed or deleted), null = network.
  final int? statusCode;

  bool get unavailable => statusCode == 403 || statusCode == 404 || statusCode == 410;

  @override
  String toString() => 'PrivateMediaException($statusCode)';
}

/// Loads private API images through [DioClient] (bearer + refresh/expiry flow)
/// into a small in-memory cache. No disk cache; the key is the URL without any
/// token; the cache is dropped when the session ends or expires.
class PrivateMediaLoader {
  PrivateMediaLoader({Dio? client, String? apiBaseUrl, this.maxEntries = 40})
      : _client = client,
        _apiBaseUrl = apiBaseUrl {
    _sessionSub = SessionEvents.stream.listen((kind) {
      if (kind == SessionEventKind.ended || kind == SessionEventKind.expired) clear();
    });
  }

  static PrivateMediaLoader instance = PrivateMediaLoader();

  final Dio? _client;
  final String? _apiBaseUrl;
  final int maxEntries;
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final Map<String, Future<Uint8List>> _inFlight = <String, Future<Uint8List>>{};
  StreamSubscription<SessionEventKind>? _sessionSub;

  bool isPrivate(String url) => isPrivateApiMediaUrl(url, apiBaseUrl: _apiBaseUrl);

  Uint8List? cached(String url) => _cache[url.trim()];

  Future<Uint8List> load(String url) {
    final key = url.trim();
    if (!isPrivate(key)) {
      // Defense in depth: never route a foreign host through the authed client.
      return Future.error(const PrivateMediaException(null));
    }
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);
    // Block body: returning the removed Future from whenComplete would await itself.
    return _inFlight.putIfAbsent(key, () => _fetch(key).whenComplete(() {
      _inFlight.remove(key);
    }));
  }

  Future<Uint8List> _fetch(String key) async {
    try {
      final response = await (_client ?? DioClient.instance).get<List<int>>(
        key,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) throw const PrivateMediaException(404);
      final bytes = Uint8List.fromList(data);
      _cache.remove(key);
      _cache[key] = bytes;
      while (_cache.length > maxEntries) {
        _cache.remove(_cache.keys.first);
      }
      return bytes;
    } on DioException catch (error) {
      throw PrivateMediaException(error.response?.statusCode);
    }
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
  }

  Future<void> dispose() async {
    await _sessionSub?.cancel();
    clear();
  }
}