import 'package:flutter/material.dart';

import '../theme/garra_semantic_colors.dart';

/// Small local catalog. Tokens use existing text message contracts and can be
/// displayed by older clients as plain text without a storage dependency.
class GarraSticker {
  const GarraSticker(this.token, this.glyph, this.label);
  final String token;
  final String glyph;
  final String label;

  static const catalog = [
    GarraSticker(':garra_aliento:', '🙌', 'Aliento'),
    GarraSticker(':garra_gol:', '⚽', 'Gol'),
    GarraSticker(':garra_fuerza:', '💪', 'Fuerza'),
    GarraSticker(':garra_corazon:', '❤️', 'Corazón'),
    GarraSticker(':garra_fuego:', '🔥', 'Fuego'),
    GarraSticker(':garra_celebra:', '🎉', 'Celebra'),
  ];

  static GarraSticker? fromContent(String content) {
    final value = content.trim();
    for (final sticker in catalog) {
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
  Widget build(BuildContext context) => Semantics(
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

Future<GarraSticker?> showGarraStickerPicker(BuildContext context) =>
    showModalBottomSheet<GarraSticker>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Stickers Garra',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final sticker in GarraSticker.catalog)
                    InkWell(
                      key: Key('sticker-${sticker.token}'),
                      onTap: () => Navigator.of(sheetContext).pop(sticker),
                      child: GarraStickerView(sticker: sticker, compact: true),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

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
