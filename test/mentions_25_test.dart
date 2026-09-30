import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/widgets/mention_autocomplete.dart';
import 'package:garra_digital_app/core/widgets/mention_span.dart';
import 'package:garra_digital_app/core/widgets/linked_text.dart';
import 'package:garra_digital_app/features/notifications/data/push_router.dart';

void main() {
  test('legacy usernames that cannot round-trip are not suggested', () {
    expect(isMentionableUsername('juan'), isTrue);
    expect(isMentionableUsername('jóse_25'), isTrue);
    expect(isMentionableUsername('juan.perez'), isFalse);
    expect(isMentionableUsername('ab'), isFalse);
  });

  test('mention notification routes preserve comment and chat identity', () {
    const router = PushRouter();
    expect(router.resolveRoute(authenticated: true,
      referenceType: 'POST_COMMENT:post-uuid', referenceId: 'comment-uuid'),
      '/muro-crema/posts/post-uuid?commentId=comment-uuid');
    expect(router.resolveRoute(authenticated: true,
      referenceType: 'COMMUNITY_CHAT:cremas-lima', referenceId: 'message-uuid'),
      '/clans/cremas-lima/chat?messageId=message-uuid');
  });

  test('active token and insertion preserve text after cursor, emoji and multiline', () {
    final controller = TextEditingController(text: '😀 Hola\n@ju final');
    controller.selection = const TextSelection.collapsed(offset: 11);
    final token = activeMentionToken(controller.value);
    expect(token, isNotNull);
    expect(token!.query, 'ju');
    insertMention(controller, token, const MentionCandidate(
      id: 'fan', username: 'juan', displayName: 'Juan'));
    expect(controller.text, '😀 Hola\n@juan final');
    expect(controller.selection.baseOffset, 14);
  });

  test('selection in the middle and deleted token are safe', () {
    final controller = TextEditingController(text: 'Hola @ju mundo');
    controller.selection = const TextSelection.collapsed(offset: 8);
    expect(activeMentionToken(controller.value)?.query, 'ju');
    controller.text = 'Hola mundo';
    expect(activeMentionToken(controller.value), isNull);
  });

  testWidgets('autocomplete debounces @, @j, @ju and keeps plain text on no result',
      (tester) async {
    final controller = TextEditingController();
    final queries = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      TextField(controller: controller),
      MentionAutocomplete(controller: controller, search: (query) async {
        queries.add(query);
        return query == 'ju' ? const [MentionCandidate(
          id: 'fan-id', username: 'juan', displayName: 'Juan')] : const [];
      }),
    ]))));
    controller.value = const TextEditingValue(text: '@',
        selection: TextSelection.collapsed(offset: 1));
    await tester.pump(const Duration(milliseconds: 100));
    controller.value = const TextEditingValue(text: '@j',
        selection: TextSelection.collapsed(offset: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(queries, isEmpty);
    controller.value = const TextEditingValue(text: '@ju',
        selection: TextSelection.collapsed(offset: 3));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(queries, ['ju']);
    await tester.tap(find.text('Juan'));
    expect(controller.text, '@juan ');
    controller.value = const TextEditingValue(text: '@unknown',
        selection: TextSelection.collapsed(offset: 8));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(controller.text, '@unknown');
    expect(find.text('Juan'), findsNothing);
  });

  testWidgets('only confirmed mention metadata is tappable alongside URLs', (tester) async {
    const value = 'Hola @juan https://site.test/@fake @nadie';
    var opened = '';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LinkedText(value,
      style: const TextStyle(),
      mentions: const [MentionSpan(userId: 'stable-uuid',
        usernameSnapshot: 'juan', start: 5, end: 10),
        MentionSpan(userId: 'wrong', usernameSnapshot: 'otro', start: 36, end: 42)],
      onOpenMention: (id) => opened = id,
    ))));
    final rich = tester.widget<RichText>(find.descendant(
      of: find.byType(LinkedText), matching: find.byType(RichText)));
    Iterable<TextSpan> flatten(InlineSpan span) sync* {
      if (span is TextSpan) {
        yield span;
        for (final child in span.children ?? const <InlineSpan>[]) {
          yield* flatten(child);
        }
      }
    }
    final spans = flatten(rich.text);
    final mention = spans.singleWhere((span) => span.text == '@juan');
    (mention.recognizer as TapGestureRecognizer).onTap!.call();
    expect(opened, 'stable-uuid');
    expect(const MentionSpan(userId: 'x', usernameSnapshot: 'otro',
      start: 5, end: 10).validFor(value), isFalse);
  });
}
