import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_linked_text.dart';

void main() {
  Future<List<TextSpan>> render(
    WidgetTester tester,
    String value, {
    double width = 320,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: ChatLinkedText(value, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(ChatLinkedText),
        matching: find.byType(Text),
      ),
    );
    return (text.textSpan! as TextSpan).children!.cast<TextSpan>();
  }

  testWidgets('HTTP and HTTPS links are clickable, ordinary text is not', (
    tester,
  ) async {
    final spans = await render(
      tester,
      'Mira http://garra.test y https://garra.test/partido.',
    );
    expect(
      spans
          .where((span) => span.recognizer is TapGestureRecognizer)
          .map((span) => span.text),
      ['http://garra.test', 'https://garra.test/partido'],
    );
    expect(
      spans
          .where((span) => span.recognizer == null)
          .map((span) => span.text)
          .join(),
      'Mira  y .',
    );
  });

  testWidgets('non HTTP schemes stay plain text', (tester) async {
    final spans = await render(
      tester,
      'javascript:alert(1) ftp://garra.test solo texto',
    );
    expect(spans.every((span) => span.recognizer == null), isTrue);
  });

  testWidgets('long link wraps without overflow on a narrow screen', (
    tester,
  ) async {
    await render(
      tester,
      'https://garra.test/partido/fotos/larguisimo y texto',
      width: 130,
    );
    expect(tester.takeException(), isNull);
  });
}
