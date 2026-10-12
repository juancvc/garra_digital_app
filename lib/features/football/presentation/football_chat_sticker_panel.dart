import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/football_chat_service.dart';

/// PRODUCT-05-B3: sticker picker backed by Football Chat API catalog + favorites.
Future<FootballChatSticker?> showFootballChatStickerPanel(
  BuildContext context, {
  required Future<FootballChatStickerCatalog> Function() loadCatalog,
  required Future<List<FootballChatSticker>> Function() loadFavorites,
  required Future<List<FootballChatSticker>> Function(String id) toggleFavorite,
}) async {
  return showModalBottomSheet<FootballChatSticker>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _FootballChatStickerSheet(
      loadCatalog: loadCatalog,
      loadFavorites: loadFavorites,
      toggleFavorite: toggleFavorite,
    ),
  );
}

class _FootballChatStickerSheet extends StatefulWidget {
  const _FootballChatStickerSheet({
    required this.loadCatalog,
    required this.loadFavorites,
    required this.toggleFavorite,
  });

  final Future<FootballChatStickerCatalog> Function() loadCatalog;
  final Future<List<FootballChatSticker>> Function() loadFavorites;
  final Future<List<FootballChatSticker>> Function(String id) toggleFavorite;

  @override
  State<_FootballChatStickerSheet> createState() => _FootballChatStickerSheetState();
}

class _FootballChatStickerSheetState extends State<_FootballChatStickerSheet> {
  FootballChatStickerCatalog? _catalog;
  List<FootballChatSticker> _favorites = const [];
  String? _error;
  bool _loading = true;
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.loadCatalog(),
        widget.loadFavorites(),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0] as FootballChatStickerCatalog;
        _favorites = results[1] as List<FootballChatSticker>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos cargar los stickers.';
      });
    }
  }

  List<FootballChatSticker> get _visible {
    final catalog = _catalog?.items ?? const [];
    if (_category == 'favorites') return _favorites;
    if (_category == 'all') return catalog;
    return catalog.where((s) => s.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SafeArea(
        top: false,
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
                  _chip('Todos', 'all'),
                  _chip('Ánimo', 'animo'),
                  _chip('Celebración', 'celebracion'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            else if (_visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No hay stickers en esta categoría.'),
              )
            else
              Flexible(
                child: GridView.builder(
                  key: const Key('football_chat_sticker_grid'),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisExtent: 92,
                  ),
                  itemCount: _visible.length,
                  itemBuilder: (_, i) {
                    final sticker = _visible[i];
                    final fav = _favorites.any((f) => f.id == sticker.id);
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: InkWell(
                            key: Key('football_chat_sticker_${sticker.id}'),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context, sticker);
                            },
                            child: _StickerTile(sticker: sticker),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            key: Key('football_chat_sticker_fav_${sticker.id}'),
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              fav ? Icons.star : Icons.star_border,
                              size: 20,
                              color: fav ? Colors.amber : null,
                            ),
                            tooltip: fav ? 'Quitar de favoritos' : 'Agregar a favoritos',
                            onPressed: () async {
                              final next = await widget.toggleFavorite(sticker.id);
                              if (!mounted) return;
                              setState(() => _favorites = next);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _category = value),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({required this.sticker});
  final FootballChatSticker sticker;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Sticker ${sticker.name}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(sticker.glyph, style: const TextStyle(fontSize: 32)),
              Text(
                sticker.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      );
}
