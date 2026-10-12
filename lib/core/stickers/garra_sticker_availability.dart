import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/dio_client.dart';
import '../widgets/garra_stickers.dart';

/// Which stickers pickers may OFFER (PRODUCT-06 visibility gate).
///
/// Source of truth: the backend active catalog (GET /football/chat/stickers,
/// returns only `active = true` rows). Fetched once per app run, no polling.
/// * Offered = 6 legacy (always) + local catalog entries whose id is active on the server.
/// * Fetch failure → 6 legacy only.
/// Not tied to the CDN base URL or assetKey. Rendering of received/historic
/// messages is NOT gated: [GarraSticker.byId]/[GarraSticker.fromContent] resolve
/// all 34 ids regardless of active state. Stored favorites are kept, only hidden.
class GarraStickerAvailability {
  GarraStickerAvailability._();

  static Set<String>? _serverActive;
  static Future<Set<String>>? _load;

  static Set<String> get legacyIds =>
      {for (final s in GarraSticker.catalog) s.stableId};

  /// Ids currently offered (legacy-only until/unless the server answered).
  static Set<String> get offeredIds => {...legacyIds, ...?_serverActive};

  static bool isOffered(GarraSticker s) => offeredIds.contains(s.stableId);

  static List<GarraSticker> offered(Iterable<GarraSticker> list) =>
      list.where(isOffered).toList();

  static Future<Set<String>> ensureLoaded({
    Dio? dio,
    Future<Set<String>> Function()? fetch,
  }) =>
      _load ??= () async {
        try {
          final ids =
              fetch != null ? await fetch() : await _fetch(dio ?? DioClient.instance);
          _serverActive = ids;
        } catch (_) {
          _serverActive = const {};
        }
        return offeredIds;
      }();

  static Future<Set<String>> _fetch(Dio dio) async {
    final res = await dio.get('/football/chat/stickers');
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (items is! List) {
      throw const FormatException('sticker availability: unexpected payload');
    }
    return {
      for (final i in items)
        if (i is Map && (i['id']?.toString() ?? '').isNotEmpty) i['id'].toString(),
    };
  }

  @visibleForTesting
  static void debugReset() {
    _serverActive = null;
    _load = null;
  }
}