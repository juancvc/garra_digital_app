import 'package:shared_preferences/shared_preferences.dart';

/// Local favorites/recents for text-token sticker surfaces (no backend contract there).
/// Football Chat keeps its server-side favorites.
class GarraStickerPrefs {
  GarraStickerPrefs({this.maxRecents = 16});

  static const favoritesKey = 'garra_stickers_favorites_v1';
  static const recentsKey = 'garra_stickers_recents_v1';
  final int maxRecents;

  Future<List<String>> favorites() async =>
      (await SharedPreferences.getInstance()).getStringList(favoritesKey) ?? const [];

  Future<List<String>> recents() async =>
      (await SharedPreferences.getInstance()).getStringList(recentsKey) ?? const [];

  Future<List<String>> toggleFavorite(String id) async {
    final p = await SharedPreferences.getInstance();
    final list = [...?p.getStringList(favoritesKey)];
    list.contains(id) ? list.remove(id) : list.add(id);
    await p.setStringList(favoritesKey, list);
    return list;
  }

  Future<List<String>> pushRecent(String id) async {
    final p = await SharedPreferences.getInstance();
    final list = [id, ...?p.getStringList(recentsKey)?.where((e) => e != id)];
    final trimmed = list.take(maxRecents).toList();
    await p.setStringList(recentsKey, trimmed);
    return trimmed;
  }
}
