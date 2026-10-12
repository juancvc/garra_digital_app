import 'package:flutter/material.dart';

import '../stickers/garra_sticker_assets.dart';
import '../stickers/garra_sticker_availability.dart';
import '../stickers/garra_sticker_prefs.dart';
import '../theme/garra_semantic_colors.dart';

part '../stickers/garra_sticker_catalog_v1.g.dart';

/// Single client catalog of Garra stickers (PRODUCT-06A).
///
/// * [catalog]: the 6 legacy Unicode stickers (V75), unchanged tokens.
/// * [all]: legacy 6 + Garra Stickers V1 (28 WebP, V77), same ids as the backend
///   catalog. Tokens `:{id}:` travel inside existing TEXT contracts (private chat,
///   community chat, comments) so older clients still see plain text.
class GarraSticker {
  const GarraSticker(this.token, this.glyph, this.label)
      : id = null,
        category = 'animo',
        sortOrder = 0,
        assetKey = null;

  const GarraSticker.v1(
    String this.id,
    this.glyph,
    this.label,
    this.category,
    this.sortOrder,
  )   : token = ':$id:',
        assetKey = 'garra/stickers/v1/$id.webp';

  final String token;
  final String glyph;
  final String label;
  final String? id;
  final String category;
  final int sortOrder;
  final String? assetKey;

  /// Stable id: V1 id, or the legacy token without colons.
  String get stableId => id ?? token.replaceAll(':', '');

  bool get hasAsset => assetKey != null;

  static const catalog = [
    GarraSticker(':garra_aliento:', '🙌', 'Aliento'),
    GarraSticker(':garra_gol:', '⚽', 'Gol'),
    GarraSticker(':garra_fuerza:', '💪', 'Fuerza'),
    GarraSticker(':garra_corazon:', '❤️', 'Corazón'),
    GarraSticker(':garra_fuego:', '🔥', 'Fuego'),
    GarraSticker(':garra_celebra:', '🎉', 'Celebra'),
  ];

  static const v1Catalog = _garraStickersV1;

  static const all = [...catalog, ..._garraStickersV1];

  static const categories = <String, String>{
    'gol_celebracion': 'Gol',
    'aliento': 'Aliento',
    'amor_crema': 'Amor crema',
    'humor_reaccion': 'Humor',
    'frustracion': 'Frustración',
    'animo': 'Clásicos',
  };

  static GarraSticker? byId(String id) {
    for (final s in all) {
      if (s.stableId == id) return s;
    }
    return null;
  }

  static GarraSticker? fromContent(String content) {
    final value = content.trim();
    for (final sticker in all) {
      if (sticker.token == value) return sticker;
    }
    return null;
  }
}

class GarraStickerView extends StatelessWidget {
  const GarraStickerView({
    super.key,
    required this.sticker,
    this.compact = false,
  });
  final GarraSticker sticker;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (sticker.hasAsset) {
      // Picker (compact) uses 128 thumbs; messages use the 512 asset.
      return Semantics(
        label: 'Sticker ${sticker.label}',
        child: GarraStickerImage(
          id: sticker.stableId,
          assetKey: sticker.assetKey,
          glyph: sticker.glyph,
          size: compact ? 64 : 132,
          thumb: compact,
        ),
      );
    }
    return Semantics(
      label: 'Sticker ${sticker.label}',
      child: Container(
        padding: EdgeInsets.all(compact ? 8 : 12),
        decoration: BoxDecoration(
          color: context.garraColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sticker.glyph, style: TextStyle(fontSize: compact ? 30 : 42)),
            Text(sticker.label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

Future<GarraSticker?> showGarraStickerPicker(BuildContext context) =>
    showModalBottomSheet<GarraSticker>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const GarraStickerPickerSheet(),
    );

/// Picker over [GarraSticker.all]: Favoritos / Recientes (local prefs) + categories.
class GarraStickerPickerSheet extends StatefulWidget {
  const GarraStickerPickerSheet({super.key, this.prefs});
  final GarraStickerPrefs? prefs;

  @override
  State<GarraStickerPickerSheet> createState() => _GarraStickerPickerSheetState();
}

class _GarraStickerPickerSheetState extends State<GarraStickerPickerSheet> {
  late final GarraStickerPrefs _prefs = widget.prefs ?? GarraStickerPrefs();
  String _tab = 'all';
  List<String> _favorites = const [];
  List<String> _recents = const [];

  @override
  void initState() {
    super.initState();
    _load();
    GarraStickerAvailability.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    final f = await _prefs.favorites();
    final r = await _prefs.recents();
    if (!mounted) return;
    setState(() {
      _favorites = f;
      _recents = r;
    });
  }

  List<GarraSticker> get _visible {
    List<GarraSticker> ids(List<String> list) =>
        GarraStickerAvailability.offered([for (final id in list) ?GarraSticker.byId(id)]);
    switch (_tab) {
      case 'all':
        return GarraStickerAvailability.offered(GarraSticker.all);
      case 'favorites':
        return ids(_favorites);
      case 'recents':
        return ids(_recents);
      default:
        return GarraStickerAvailability.offered(
            GarraSticker.all.where((s) => s.category == _tab));
    }
  }

  Widget _chip(String label, String value) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          key: Key('garra-sticker-tab-$value'),
          label: Text(label),
          selected: _tab == value,
          onSelected: (_) => setState(() => _tab = value),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Stickers Garra', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('Favoritos', 'favorites'),
                  _chip('Recientes', 'recents'),
                  _chip('Todos', 'all'),
                  for (final e in GarraSticker.categories.entries) _chip(e.value, e.key),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aún no hay stickers aquí.', textAlign: TextAlign.center),
              )
            else
              Flexible(
                child: GridView.count(
                  key: const Key('garra-sticker-grid'),
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final sticker in visible)
                      InkWell(
                        key: Key('sticker-${sticker.token}'),
                        onTap: () async {
                          await _prefs.pushRecent(sticker.stableId);
                          if (context.mounted) Navigator.of(context).pop(sticker);
                        },
                        onLongPress: () async {
                          final next = await _prefs.toggleFavorite(sticker.stableId);
                          if (mounted) setState(() => _favorites = next);
                        },
                        child: Center(
                          child: GarraStickerView(sticker: sticker, compact: true),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> insertGarraSticker(
  BuildContext context,
  TextEditingController controller,
) async {
  final sticker = await showGarraStickerPicker(context);
  if (sticker == null) return;
  if (!context.mounted) return;
  final old = controller.text.trim();
  if (old.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Envía el texto antes de elegir un sticker.'),
      ),
    );
    return;
  }
  controller.text = sticker.token;
  controller.selection = TextSelection.collapsed(
    offset: controller.text.length,
  );
}
