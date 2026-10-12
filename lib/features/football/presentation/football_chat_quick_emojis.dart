import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// PRODUCT-05-B2: quick Unicode emojis for Football Chat (TEXT messages only).
const List<String> footballChatQuickEmojis = [
  '⚽',
  '🔥',
  '❤️',
  '💛',
  '🙌',
  '🎉',
  '👏',
  '😍',
  '😂',
  '😢',
  '💪',
  '🏆',
];

const double _emojiCell = 44;

Future<void> showFootballChatEmojiPicker(
  BuildContext context,
  TextEditingController controller, {
  int maxLength = 280,
}) async {
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
        child: SafeArea(
          top: false,
          child: GridView.builder(
            key: const Key('football_chat_emoji_grid'),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisExtent: _emojiCell,
            ),
            itemCount: footballChatQuickEmojis.length,
            itemBuilder: (_, i) {
              final emoji = footballChatQuickEmojis[i];
              return Semantics(
                button: true,
                label: 'Emoji $emoji',
                child: IconButton(
                  key: Key('football_chat_emoji_$i'),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(ctx, emoji);
                  },
                  icon: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              );
            },
          ),
        ),
      );
    },
  );
  if (picked == null || !context.mounted) return;
  insertFootballChatEmoji(controller, picked, maxLength: maxLength);
}

void insertFootballChatEmoji(
  TextEditingController controller,
  String emoji, {
  int maxLength = 280,
}) {
  final text = controller.text;
  final sel = controller.selection;
  final start = sel.start >= 0 ? sel.start : text.length;
  final end = sel.end >= 0 ? sel.end : text.length;
  final nextLen = text.length - (end - start) + emoji.length;
  if (nextLen > maxLength) return;
  final updated = text.replaceRange(start, end, emoji);
  controller.value = TextEditingValue(
    text: updated,
    selection: TextSelection.collapsed(offset: start + emoji.length),
  );
}
