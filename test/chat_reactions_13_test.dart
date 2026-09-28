import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_conversation_page.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_message_reactions.dart';
import 'package:garra_digital_app/features/chat/presentation/floating_chat_panel.dart';
import 'package:garra_digital_app/features/community/data/reaction_type.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_comment_reactions.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

const _poll = Duration(seconds: 5);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_PE');
  });

  group('CHAT_REACTIONS_13 picker', () {
    testWidgets('1 long press on an own text message opens the picker', (
      tester,
    ) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: true)];
      await _open(tester, chat);

      await _longPress(tester, 'm1');

      expect(find.byKey(const Key('chat-reaction-picker')), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('2 long press on the other person text opens the picker', (
      tester,
    ) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false)];
      await _open(tester, chat);

      await _longPress(tester, 'm1');

      expect(find.byKey(const Key('chat-reaction-picker')), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('3 picker shows exactly six reactions in chat order', (
      tester,
    ) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false)];
      await _open(tester, chat);
      await _longPress(tester, 'm1');

      expect(_options(), findsNWidgets(6));
      final order = ['LIKE', 'LOVE', 'HAHA', 'FIRE', 'GARRA', 'SAD'];
      final xs = [for (final t in order) tester.getCenter(_option(t)).dx];
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]));
      }
      expect(chatReactionTypes.map((t) => t.apiValue), order);
      // Compact horizontal row (no 4x2 sheet), >= 44dp targets.
      expect(find.byKey(const ValueKey('post_reaction_picker')), findsNothing);
      expect(
        find.byKey(const ValueKey('comment_reaction_picker')),
        findsNothing,
      );
      final size = tester.getSize(_option('LIKE'));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      await _dispose(tester);
    });

    testWidgets('4 picker never offers ANGER', (tester) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false)];
      await _open(tester, chat);
      await _longPress(tester, 'm1');

      expect(_option('ANGER'), findsNothing);
      expect(chatReactionTypes, isNot(contains(ReactionType.anger)));
      await _dispose(tester);
    });

    testWidgets('5 picker never offers CARE', (tester) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false)];
      await _open(tester, chat);
      await _longPress(tester, 'm1');

      expect(_option('CARE'), findsNothing);
      expect(chatReactionTypes, isNot(contains(ReactionType.care)));
      await _dispose(tester);
    });

    testWidgets('tap outside closes the picker without reacting', (
      tester,
    ) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false)];
      await _open(tester, chat);
      await _longPress(tester, 'm1');

      await tester.tapAt(const Offset(5, 300));
      await _transition(tester);

      expect(find.byKey(const Key('chat-reaction-picker')), findsNothing);
      expect(chat.calls, isEmpty);
      await _dispose(tester);
    });

    testWidgets('picker stays on screen and flips below near the top', (
      tester,
    ) async {
      const screen = Size(360, 640);
      final above = chatReactionPickerOrigin(
        anchor: const Rect.fromLTWH(200, 300, 140, 60),
        alignEnd: true,
        size: screen,
      );
      expect(above.dy, lessThan(300));
      expect(above.dx + chatReactionPickerWidth, lessThanOrEqualTo(352));
      final below = chatReactionPickerOrigin(
        anchor: const Rect.fromLTWH(10, 20, 140, 60),
        alignEnd: false,
        size: screen,
        padding: const EdgeInsets.only(top: 24),
      );
      expect(below.dy, greaterThanOrEqualTo(80));
      expect(below.dx, greaterThanOrEqualTo(8));
    });

    testWidgets('PENDING conversation does not open the picker', (
      tester,
    ) async {
      final chat = _Chat()
        ..conversationResult = _conversation(status: 'PENDING')
        ..messagesResult = [_msg('m1', mine: true)];
      await _open(tester, chat);

      await _longPress(tester, 'm1');

      expect(find.byKey(const Key('chat-reaction-picker')), findsNothing);
      await _dispose(tester);
    });
  });

  group('CHAT_REACTIONS_13 select / toggle', () {
    testWidgets('6 select LIKE adds the chip and calls PUT', (tester) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false)];
      await _open(tester, chat);

      await _react(tester, 'm1', 'LIKE');

      expect(chat.calls, ['PUT m1 LIKE']);
      expect(_chip('m1', 'LIKE'), findsOneWidget);
      expect(_countText('m1', 'LIKE'), '1');
      await _dispose(tester);
    });

    testWidgets('7 select LOVE adds the chip', (tester) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: true)];
      await _open(tester, chat);

      await _react(tester, 'm1', 'LOVE');

      expect(chat.calls, ['PUT m1 LOVE']);
      expect(_chip('m1', 'LOVE'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('8 choosing the same reaction removes it (DELETE)', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, reactions: [_r('LOVE', 1, mine: true)]),
        ];
      await _open(tester, chat);
      expect(_chip('m1', 'LOVE'), findsOneWidget);

      await _react(tester, 'm1', 'LOVE');

      expect(chat.calls, ['DELETE m1']);
      expect(_chip('m1', 'LOVE'), findsNothing);
      expect(find.byKey(const Key('chat-reactions-m1')), findsNothing);
      await _dispose(tester);
    });

    testWidgets('9 choosing another reaction replaces it (PUT)', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, reactions: [_r('LIKE', 1, mine: true)]),
        ];
      await _open(tester, chat);

      await _react(tester, 'm1', 'LOVE');

      expect(chat.calls, ['PUT m1 LOVE']);
      expect(_chip('m1', 'LIKE'), findsNothing);
      expect(_chip('m1', 'LOVE'), findsOneWidget);
      expect(_countText('m1', 'LOVE'), '1');
      await _dispose(tester);
    });

    testWidgets('10 my reaction is highlighted in the chip and the picker', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg(
            'm1',
            mine: false,
            reactions: [_r('LOVE', 1, mine: true), _r('HAHA', 1)],
          ),
        ];
      await _open(tester, chat, theme: AppTheme.lightTheme);
      final accent = GarraSemanticColors.crema.brandPrimary;

      final mine = _segmentDecoration(tester, 'm1', 'LOVE');
      final other = _segmentDecoration(tester, 'm1', 'HAHA');
      expect((mine.border! as Border).top.color, accent);
      expect(mine.color, accent.withValues(alpha: 0.16));
      expect((other.border! as Border).top.color, Colors.transparent);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('chat-reaction-count-m1-LOVE')))
            .style
            ?.fontWeight,
        FontWeight.w800,
      );

      await _longPress(tester, 'm1');
      final selected = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.selected == true,
      );
      expect(selected, findsOneWidget);
      expect(tester.widget<Semantics>(selected).properties.label, 'Me encanta');
      await _dispose(tester);
    });
  });

  group('CHAT_REACTIONS_13 chips', () {
    testWidgets('11 chip shows the count of one type', (tester) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: true, reactions: [_r('LOVE', 2, mine: true)]),
        ];
      await _open(tester, chat);

      expect(_chip('m1', 'LOVE'), findsOneWidget);
      expect(_countText('m1', 'LOVE'), '2');
      await _dispose(tester);
    });

    testWidgets('12 two different types render as two segments', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, reactions: [_r('HAHA', 1), _r('LOVE', 1)]),
          _msg('m2', mine: true),
        ];
      await _open(tester, chat);

      expect(_chip('m1', 'LOVE'), findsOneWidget);
      expect(_chip('m1', 'HAHA'), findsOneWidget);
      // Same count: chat picker order (LOVE before HAHA).
      expect(
        tester.getCenter(_chip('m1', 'LOVE')).dx,
        lessThan(tester.getCenter(_chip('m1', 'HAHA')).dx),
      );
      expect(find.byKey(const Key('chat-reactions-m2')), findsNothing);
      await _dispose(tester);
    });

    testWidgets('chips align to the bubble side and overlap its bottom edge', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, reactions: [_r('FIRE', 1)]),
          _msg('m2', mine: true, reactions: [_r('LIKE', 1)]),
        ];
      await _open(tester, chat);

      final otherBubble = tester.getRect(_bubbleBox('m1'));
      final otherChip = tester.getRect(
        find.byKey(const Key('chat-reactions-m1')),
      );
      expect(otherChip.left, closeTo(otherBubble.left + 12, 1));
      expect(otherChip.top, lessThan(otherBubble.bottom));
      expect(otherChip.bottom, greaterThan(otherBubble.bottom));
      final mineBubble = tester.getRect(_bubbleBox('m2'));
      final mineChip = tester.getRect(
        find.byKey(const Key('chat-reactions-m2')),
      );
      expect(mineChip.right, closeTo(mineBubble.right - 12, 1));
      await _dispose(tester);
    });

    testWidgets('unknown types are skipped and global types render read-only', (
      tester,
    ) async {
      final parsed = ChatMessage.fromJson({
        'id': 'm1',
        'conversationId': 'c1',
        'senderId': 'u2',
        'content': 'Hola',
        'mine': false,
        'reactions': [
          {'type': 'ANGER', 'count': 1, 'reactedByMe': false},
          {'type': 'CARE', 'count': 2, 'reactedByMe': false},
          {'type': 'WEIRD', 'count': 5, 'reactedByMe': true},
          {'type': 'LOVE', 'count': 0},
          {'type': 'LIKE', 'count': 'x'},
          'garbage',
          null,
        ],
      });
      expect(parsed.reactions.map((r) => r.type), ['ANGER', 'CARE']);
      expect(parseChatReactions('nope'), isEmpty);

      final chat = _Chat()..messagesResult = [parsed];
      await _open(tester, chat);
      expect(tester.takeException(), isNull);
      expect(_chip('m1', 'ANGER'), findsOneWidget);
      expect(_chip('m1', 'CARE'), findsOneWidget);

      await _longPress(tester, 'm1');
      expect(_option('ANGER'), findsNothing);
      expect(_option('CARE'), findsNothing);
      await _dispose(tester);
    });
  });

  group('CHAT_REACTIONS_13 media', () {
    testWidgets('13 long press on a media-only message opens the picker', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, content: '', media: [_image('a1')]),
        ];
      await _open(tester, chat);

      await _longPress(tester, 'm1');

      expect(find.byKey(const Key('chat-reaction-picker')), findsOneWidget);
      await tester.tap(_option('FIRE'));
      await _transition(tester);
      expect(chat.calls, ['PUT m1 FIRE']);
      expect(_chip('m1', 'FIRE'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('14 tapping a photo still opens the media viewer', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg(
            'm1',
            mine: true,
            content: 'Mira',
            media: [_image('a1'), _image('a2')],
            reactions: [_r('GARRA', 1)],
          ),
        ];
      await _open(tester, chat);

      await tester.tap(find.byKey(const Key('chat-media-image-1')));
      await _transition(tester);

      expect(find.byKey(const ValueKey('garra_media_viewer')), findsOneWidget);
      expect(find.byKey(const Key('chat-reaction-picker')), findsNothing);
      expect(chat.calls, isEmpty);
      await _dispose(tester);
    });
  });

  group('CHAT_REACTIONS_13 polling', () {
    testWidgets(
      '15-17 reaction-only poll repaints without scroll, pill or read',
      (tester) async {
        final chat = _Chat()..messagesResult = _longThread();
        await _open(tester, chat, poll: _poll);
        _position(tester).jumpTo(200);
        await tester.pump();
        expect(chat.markReads, 1);
        final visible = chat.messagesResult.firstWhere(
          (m) => find
              .byKey(Key('chat-bubble-gesture-${m.id}'))
              .evaluate()
              .isNotEmpty,
        );

        chat.messagesResult = [
          for (final m in chat.messagesResult)
            m.id == visible.id
                ? m.copyWith(
                    reactions: const [
                      ChatMessageReactionSummary(type: 'LOVE', count: 1),
                    ],
                  )
                : m,
        ];
        await _pollOnce(tester);

        expect(_chip(visible.id, 'LOVE'), findsOneWidget);
        expect(_position(tester).pixels, 200);
        expect(find.byKey(const Key('chat-new-messages-pill')), findsNothing);
        expect(chat.markReads, 1);
        await _dispose(tester);
      },
    );

    testWidgets('an unchanged poll does not repaint reactions', (tester) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, reactions: [_r('LIKE', 1)]),
        ];
      await _open(tester, chat, poll: _poll);
      await _pollOnce(tester);

      expect(_countText('m1', 'LIKE'), '1');
      expect(chat.markReads, 1);
      await _dispose(tester);
    });
  });

  group('CHAT_REACTIONS_13 optimistic', () {
    testWidgets('18 optimistic success shows immediately then reconciles', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, reactions: [_r('LOVE', 1)]),
        ]
        ..gate = Completer<void>();
      await _open(tester, chat, poll: _poll);

      await _react(tester, 'm1', 'LOVE');
      // In flight: optimistic LOVE 2 (mine) before the server answers.
      expect(_countText('m1', 'LOVE'), '2');

      // A poll during the request must not overwrite the optimistic state.
      await _pollOnce(tester);
      expect(_countText('m1', 'LOVE'), '2');

      chat.gate!.complete();
      await _settle(tester);
      expect(chat.calls, ['PUT m1 LOVE']);
      expect(_countText('m1', 'LOVE'), '2');
      expect(
        (_segmentDecoration(tester, 'm1', 'LOVE').border! as Border).top.width,
        1.2,
      );
      await _dispose(tester);
    });

    testWidgets('19 optimistic failure rolls back and shows a snackbar', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, reactions: [_r('LIKE', 1, mine: true)]),
        ]
        ..gate = Completer<void>()
        ..fail = true;
      await _open(tester, chat);

      await _react(tester, 'm1', 'LOVE');
      expect(_chip('m1', 'LOVE'), findsOneWidget);
      expect(_chip('m1', 'LIKE'), findsNothing);

      chat.gate!.complete();
      await _settle(tester);

      expect(_chip('m1', 'LOVE'), findsNothing);
      expect(_chip('m1', 'LIKE'), findsOneWidget);
      expect(
        find.text('No pudimos actualizar la reacci\u00f3n'),
        findsOneWidget,
      );
      await _dispose(tester);
    });
  });

  group('CHAT_REACTIONS_13 GARRA animation', () {
    testWidgets('20 selecting GARRA plays the compact chat animation', (
      tester,
    ) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false)];
      await _open(tester, chat);
      await _longPress(tester, 'm1');

      await tester.tap(_option('GARRA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final pulse = find.byKey(const Key('chat-garra-pulse'));
      expect(pulse, findsOneWidget);
      expect(tester.getSize(pulse).width, chatGarraPulseSize);
      expect(chatGarraPulseDuration, const Duration(milliseconds: 320));
      expect(chatGarraPulseSize, inInclusiveRange(32, 40));

      await tester.pump(const Duration(milliseconds: 400));
      expect(pulse, findsNothing);
      expect(chat.calls, ['PUT m1 GARRA']);
      await _dispose(tester);
    });

    testWidgets('other reactions never play the GARRA animation', (
      tester,
    ) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false)];
      await _open(tester, chat);
      await _longPress(tester, 'm1');

      await tester.tap(_option('FIRE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byKey(const Key('chat-garra-pulse')), findsNothing);
      await _dispose(tester);
    });

    testWidgets('21 reduce motion skips the GARRA animation', (tester) async {
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false)];
      await _open(tester, chat, reduceMotion: true);
      await _longPress(tester, 'm1');

      await tester.tap(_option('GARRA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byKey(const Key('chat-garra-pulse')), findsNothing);
      await _settle(tester);
      expect(chat.calls, ['PUT m1 GARRA']);
      expect(_chip('m1', 'GARRA'), findsOneWidget);
      await _dispose(tester);
    });
  });

  group('CHAT_REACTIONS_13 floating panel', () {
    testWidgets('22 floating panel shows reactions read-only', (tester) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, reactions: [_r('LOVE', 2, mine: true)]),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showGarraFloatingChat(
                  context: context,
                  otherUserId: 'u2',
                  chatService: chat,
                  relationship: const ChatRelationship(
                    conversationId: 'c1',
                    status: 'ACTIVE',
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await _transition(tester);

      expect(find.byKey(const Key('floating-chat-panel')), findsOneWidget);
      expect(_chip('m1', 'LOVE'), findsOneWidget);
      expect(_countText('m1', 'LOVE'), '2');

      await tester.longPress(find.text(_msg('m1', mine: false).content));
      await _transition(tester);
      expect(find.byKey(const Key('chat-reaction-picker')), findsNothing);
      expect(chat.calls, isEmpty);
    });
  });

  group('CHAT_REACTIONS_13 themes and accessibility', () {
    testWidgets('23 Crema: surface chip and garnet GARRA', (tester) async {
      await _expectTheme(
        tester,
        AppTheme.lightTheme,
        GarraSemanticColors.crema,
        garra: GarraSemanticColors.crema.brandPrimary,
      );
    });

    testWidgets('24 Noche: surface chip and gold GARRA', (tester) async {
      await _expectTheme(
        tester,
        AppTheme.darkTheme,
        GarraSemanticColors.noche,
        garra: GarraSemanticColors.noche.brandPrestige,
      );
    });

    testWidgets('25 semantics: bubble action, chip labels and picker items', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final chat = _Chat()
        ..messagesResult = [
          _msg(
            'm1',
            mine: false,
            reactions: [_r('LOVE', 2, mine: true), _r('HAHA', 1)],
          ),
        ];
      await _open(tester, chat);

      final action = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.customSemanticsActions?.keys.any(
                  (a) => a.label == 'Reaccionar al mensaje',
                ) ??
                false),
      );
      expect(action, findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Me encanta, 2 reacciones. Tu reacci\u00f3n: Me encanta',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Me divierte, 1 reacci\u00f3n'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(_chip('m1', 'LOVE')),
        isSemantics(isSelected: true),
      );

      await _longPress(tester, 'm1');
      for (final label in [
        'Me gusta',
        'Me encanta',
        'Me divierte',
        'Est\u00e1 que arde',
        'Garra',
        'Me entristece',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(
        tester.getSemantics(_option('LOVE')),
        isSemantics(label: 'Me encanta', isButton: true, isSelected: true),
      );
      handle.dispose();
      await _dispose(tester);
    });

    testWidgets('PENDING bubbles expose no reaction action', (tester) async {
      final chat = _Chat()
        ..conversationResult = _conversation(status: 'PENDING')
        ..messagesResult = [_msg('m1', mine: true)];
      await _open(tester, chat);

      final action = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.customSemanticsActions?.isNotEmpty ?? false),
      );
      expect(action, findsNothing);
      await _dispose(tester);
    });
  });

  group('CHAT_REACTIONS_13 model', () {
    test('withMyChatReaction adds, replaces and removes only my reaction', () {
      final base = [_r('LOVE', 1), _r('LIKE', 1, mine: true)];

      final replaced = withMyChatReaction(base, 'LOVE');
      expect(chatReactionSignature(replaced), 'LOVE:2:1');

      final removed = withMyChatReaction(replaced, null);
      expect(chatReactionSignature(removed), 'LOVE:1:0');

      final added = withMyChatReaction(removed, 'GARRA');
      expect(chatReactionSignature(added), 'GARRA:1:1|LOVE:1:0');
      expect(myChatReaction(added), 'GARRA');
    });

    test('small reaction response parses safely', () {
      final result = ChatMessageReactionsResult.fromJson({
        'messageId': 'm1',
        'reactions': [
          {'type': 'LOVE', 'count': 2, 'reactedByMe': true},
        ],
        'myReaction': 'LOVE',
      });
      expect(result.messageId, 'm1');
      expect(result.myReaction, 'LOVE');
      expect(result.reactions.single.count, 2);
      final empty = ChatMessageReactionsResult.fromJson({'messageId': 'm1'});
      expect(empty.reactions, isEmpty);
      expect(empty.myReaction, isNull);
    });
  });
}

// --- Helpers -----------------------------------------------------------------

Future<void> _open(
  WidgetTester tester,
  _Chat chat, {
  ThemeData? theme,
  Duration poll = const Duration(minutes: 5),
  bool reduceMotion = false,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => ChatConversationPage(
          conversationId: 'c1',
          chatService: chat,
          pollInterval: poll,
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      theme: theme ?? AppTheme.darkTheme,
      routerConfig: router,
      builder: reduceMotion
          ? (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
          : null,
    ),
  );
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<void> _transition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pollOnce(WidgetTester tester) async {
  await tester.pump(_poll);
  await _settle(tester);
  await tester.pump(const Duration(milliseconds: 300));
  await _settle(tester);
}

Future<void> _longPress(WidgetTester tester, String id) async {
  await tester.longPress(find.byKey(Key('chat-bubble-gesture-$id')));
  await _transition(tester);
}

Future<void> _react(WidgetTester tester, String id, String type) async {
  await _longPress(tester, id);
  await tester.tap(_option(type));
  await _transition(tester);
}

Finder _options() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('chat-reaction-option-'),
);

Finder _option(String type) => find.byKey(Key('chat-reaction-option-$type'));

Finder _chip(String id, String type) =>
    find.byKey(Key('chat-reaction-chip-$id-$type'));

Finder _bubbleBox(String id) => find
    .descendant(
      of: find.byKey(Key('chat-bubble-gesture-$id')),
      matching: find.byType(Container),
    )
    .first;

String? _countText(String id, String type) =>
    (find.byKey(Key('chat-reaction-count-$id-$type')).evaluate().single.widget
            as Text)
        .data;

BoxDecoration _segmentDecoration(WidgetTester tester, String id, String type) {
  return tester.widget<DecoratedBox>(_chip(id, type)).decoration
      as BoxDecoration;
}

ScrollPosition _position(WidgetTester tester) {
  final list = find.byWidgetPredicate(
    (w) => w is ListView && w.scrollDirection == Axis.vertical,
  );
  return tester
      .state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      )
      .position;
}

Future<void> _expectTheme(
  WidgetTester tester,
  ThemeData theme,
  GarraSemanticColors expected, {
  required Color garra,
}) async {
  final chat = _Chat()
    ..messagesResult = [
      _msg('m1', mine: true, reactions: [_r('GARRA', 1, mine: true)]),
      _msg('m2', mine: false, reactions: [_r('LIKE', 1)]),
    ];
  await _open(tester, chat, theme: theme);

  for (final id in ['m1', 'm2']) {
    final chip = tester.widget<DecoratedBox>(
      find.byKey(Key('chat-reactions-$id')),
    );
    final decoration = chip.decoration as BoxDecoration;
    // Theme surface (not the bubble color) keeps contrast on both bubbles.
    expect(decoration.color, expected.surface);
    expect((decoration.border! as Border).top.color, expected.border);
  }
  final chipGlyph = tester.widget<GarraClawReactionGlyph>(
    find.descendant(
      of: _chip('m1', 'GARRA'),
      matching: find.byType(GarraClawReactionGlyph),
    ),
  );
  expect(chipGlyph.color, garra);
  expect(
    (_segmentDecoration(tester, 'm1', 'GARRA').border! as Border).top.color,
    garra,
  );

  await _longPress(tester, 'm2');
  final picker = tester.widget<Material>(
    find.byKey(const Key('chat-reaction-picker')),
  );
  expect(picker.color, expected.surfaceRaised);
  final pickerGlyph = tester.widget<GarraClawReactionGlyph>(
    find.descendant(
      of: _option('GARRA'),
      matching: find.byType(GarraClawReactionGlyph),
    ),
  );
  expect(pickerGlyph.color, garra);
  await _dispose(tester);
}

ChatConversation _conversation({String status = 'ACTIVE'}) {
  return ChatConversation(
    id: 'c1',
    otherUserId: 'u2',
    otherDisplayName: 'Diego Ramos',
    otherUsername: 'diegor',
    status: status,
  );
}

ChatMessageReactionSummary _r(String type, int count, {bool mine = false}) {
  return ChatMessageReactionSummary(
    type: type,
    count: count,
    reactedByMe: mine,
  );
}

ChatMessage _msg(
  String id, {
  required bool mine,
  String? content,
  List<ChatMediaItem> media = const [],
  List<ChatMessageReactionSummary> reactions = const [],
  DateTime? at,
}) {
  return ChatMessage(
    id: id,
    conversationId: 'c1',
    senderId: mine ? 'me' : 'u2',
    content: content ?? 'Mensaje $id para coordinar la previa',
    mine: mine,
    createdAt: at ?? DateTime.now(),
    media: media,
    reactions: reactions,
  );
}

ChatMediaItem _image(String id) {
  return ChatMediaItem(
    assetId: id,
    url: 'https://example.invalid/$id.jpg',
    contentType: 'image/jpeg',
    kind: 'IMAGE',
  );
}

List<ChatMessage> _longThread() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return [
    for (var i = 0; i < 30; i++)
      _msg(
        'm$i',
        mine: i.isOdd,
        at: start.add(Duration(minutes: 10 * i)),
      ),
  ];
}

class _Chat extends ChatService {
  _Chat() : super(dio: Dio());

  ChatConversation? conversationResult;
  List<ChatMessage> messagesResult = const [];
  int markReads = 0;
  final List<String> calls = [];
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<ChatRelationship> relationship(
    String userId, {
    String context = 'SOCIAL',
  }) async => ChatRelationship.none();

  @override
  Future<ChatConversation> conversation(String conversationId) async =>
      conversationResult ?? _conversation();

  @override
  Future<List<ChatMessage>> messages(String conversationId) async =>
      messagesResult;

  @override
  Future<void> markRead(String conversationId) async {
    markReads += 1;
  }

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<ChatMessageReactionsResult> reactToMessage(
    String messageId,
    ReactionType type,
  ) async {
    calls.add('PUT $messageId ${type.apiValue}');
    return _apply(messageId, type.apiValue);
  }

  @override
  Future<ChatMessageReactionsResult> removeMessageReaction(
    String messageId,
  ) async {
    calls.add('DELETE $messageId');
    return _apply(messageId, null);
  }

  Future<ChatMessageReactionsResult> _apply(String id, String? next) async {
    if (gate != null) await gate!.future;
    if (fail) throw ChatException('Blocked users cannot chat');
    final current = messagesResult.firstWhere((m) => m.id == id).reactions;
    final updated = withMyChatReaction(current, next);
    messagesResult = [
      for (final m in messagesResult)
        m.id == id ? m.copyWith(reactions: updated) : m,
    ];
    return ChatMessageReactionsResult(
      messageId: id,
      reactions: updated,
      myReaction: next,
    );
  }
}
