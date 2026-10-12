import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/presentation/football_chat_quick_emojis.dart';

void main() {
  test('FootballChatMessage parses STICKER payload', () {
    final m = FootballChatMessage.fromJson({
      'id': 'm1',
      'authorId': 'a',
      'authorName': 'H',
      'authorUsername': 'h',
      'body': ':garra_gol:',
      'messageType': 'STICKER',
      'stickerId': 'garra_gol',
      'sticker': {
        'id': 'garra_gol',
        'name': 'Gol',
        'category': 'celebracion',
        'glyph': '⚽',
      },
    });
    expect(m.isSticker, isTrue);
    expect(m.sticker?.glyph, '⚽');
  });

  test('insertFootballChatEmoji respects max length and cursor', () {
    final controller = TextEditingController(text: 'Hola ');
    controller.selection = const TextSelection.collapsed(offset: 5);
    insertFootballChatEmoji(controller, '⚽', maxLength: 8);
    expect(controller.text, 'Hola ⚽');
    insertFootballChatEmoji(controller, '🔥🔥🔥', maxLength: 8);
    expect(controller.text, 'Hola ⚽');
  });

  testWidgets('emoji picker inserts at cursor', (tester) async {
    final controller = TextEditingController(text: 'Vamos ');
    controller.selection = const TextSelection.collapsed(offset: 6);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFootballChatEmojiPicker(context, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('football_chat_emoji_0')));
    await tester.pumpAndSettle();
    expect(controller.text, contains('⚽'));
  });

  test('FootballChatStickerCatalog parses items', () {
    final catalog = FootballChatStickerCatalog.fromJson({
      'items': [
        {'id': 'garra_gol', 'name': 'Gol', 'category': 'celebracion', 'glyph': '⚽'},
      ],
    });
    expect(catalog.items.single.id, 'garra_gol');
  });
}
