import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_conversation_page.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_request_copy.dart';
import 'package:garra_digital_app/features/chat/presentation/floating_chat_panel.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';

const _maria = 'María Campos';
const _waitingMaria = 'Esperando que María acepte tu solicitud';

ChatConversation _conversation({
  String status = 'PENDING',
  bool outgoing = true,
  String context = 'SOCIAL',
}) {
  return ChatConversation(
    id: 'c-maria',
    otherUserId: 'u-maria',
    otherDisplayName: _maria,
    status: status,
    outgoing: outgoing,
    context: context,
  );
}

List<ChatMessage> _opening() => const [
  ChatMessage(
    id: 'm-open',
    conversationId: 'c-maria',
    senderId: 'me',
    content: 'Hola xd',
    mine: true,
  ),
];

Finder _inBanner(String text) => find.descendant(
  of: find.byKey(const Key('chat-pending-banner')),
  matching: find.text(text),
);

void main() {
  group('FIX_10 ChatRequestCopy', () {
    test('SOCIAL copy never mentions the seller and names the fan', () {
      final copy = ChatRequestCopy.resolve(conversation: _conversation());

      expect(copy.marketplace, isFalse);
      expect(copy.waitingForAcceptance, _waitingMaria);
      expect(copy.pendingStatus, _waitingMaria);
      expect(
        copy.replyAfterAcceptance,
        'Podrá responder cuando acepte tu solicitud.',
      );
      expect(
        copy.firstMessageHint,
        'Escribe el primer mensaje. Lo verá con tu solicitud.',
      );
      for (final text in [
        copy.waitingForAcceptance,
        copy.pendingStatus,
        copy.replyAfterAcceptance,
        copy.firstMessageHint,
      ]) {
        expect(text.toLowerCase(), isNot(contains('vendedor')));
      }
    });

    test('SOCIAL copy without a name falls back to the generic text', () {
      const copy = ChatRequestCopy(marketplace: false, otherDisplayName: ' ');

      expect(copy.waitingForAcceptance, 'Esperando que acepte tu solicitud');
      expect(copy.pendingStatus, 'Esperando que acepte tu solicitud');
    });

    test('MARKETPLACE keeps the commercial copy', () {
      final copy = ChatRequestCopy.resolve(
        conversation: _conversation(context: 'MARKETPLACE'),
      );

      expect(copy.marketplace, isTrue);
      expect(
        copy.waitingForAcceptance,
        'Esperando que el vendedor acepte tu solicitud',
      );
      expect(copy.pendingStatus, 'Esperando que acepte tu solicitud');
      expect(
        copy.replyAfterAcceptance,
        'El vendedor podrá responder cuando acepte tu solicitud.',
      );
      expect(
        copy.firstMessageHint,
        'Escribe el primer mensaje. El vendedor lo verá con tu solicitud.',
      );
    });

    test('conversation context wins; the flag is only a fallback', () {
      expect(ChatRequestCopy.resolve().marketplace, isFalse);
      expect(
        ChatRequestCopy.resolve(marketplaceFallback: true).marketplace,
        isTrue,
      );
      expect(
        ChatRequestCopy.resolve(
          conversation: _conversation(),
          marketplaceFallback: true,
        ).marketplace,
        isFalse,
      );
    });

    test('blocked composer names the fan only for our pending request', () {
      final copy = ChatRequestCopy.resolve(conversation: _conversation());

      expect(copy.blockedComposerHint(pendingOutgoing: true), _waitingMaria);
      expect(
        copy.blockedComposerHint(pendingOutgoing: false),
        'Esperando que acepte tu solicitud',
      );
    });
  });

  testWidgets('FIX_10: profile chat request sheet shows no vendedor copy', (
    tester,
  ) async {
    final chat = _Fix10Chat()
      ..requestResult = _conversation()
      ..messagesResult = _opening();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showGarraFloatingChat(
                  context: context,
                  otherUserId: 'u-maria',
                  chatService: chat,
                  otherDisplayName: _maria,
                ),
                child: const Text('Mensaje'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mensaje'));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe el primer mensaje. Lo verá con tu solicitud.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('marketplace-chat-draft')),
      'Hola xd',
    );
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();

    expect(chat.requestedMessage, 'Hola xd');
    expect(find.text('Solicitud enviada'), findsOneWidget);
    expect(_inBanner(_waitingMaria), findsOneWidget);
    expect(find.textContaining('vendedor'), findsNothing);
    expect(find.text('Hola xd'), findsOneWidget);
    final composer = tester.widget<TextField>(
      find.byKey(const Key('chat-composer')),
    );
    expect(composer.enabled, isFalse);
    expect(composer.decoration?.hintText, _waitingMaria);
  });

  testWidgets(
    'FIX_10: pending SOCIAL conversation keeps the composer blocked',
    (tester) async {
      final chat = _Fix10Chat()
        ..conversationResult = _conversation()
        ..messagesResult = _opening();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChatConversationPage(
            conversationId: 'c-maria',
            chatService: chat,
            pollInterval: const Duration(seconds: 30),
            requestJustSent: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Solicitud enviada'), findsOneWidget);
      expect(
        find.text('Podrá responder cuando acepte tu solicitud.'),
        findsOneWidget,
      );
      expect(_inBanner(_waitingMaria), findsOneWidget);
      expect(find.textContaining('vendedor'), findsNothing);
      expect(find.text('Hola xd'), findsOneWidget);
      final composer = tester.widget<TextField>(
        find.byKey(const Key('chat-composer')),
      );
      expect(composer.enabled, isFalse);
      expect(composer.decoration?.hintText, _waitingMaria);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('FIX_10: opening a conversation refreshes the Home badge once', (
    tester,
  ) async {
    var homeBuilds = 0;
    final chat = _Fix10Chat()
      ..conversationResult = _conversation(status: 'ACTIVE')
      ..messagesResult = _opening();
    await tester.pumpWidget(_badgeHarness(chat, () => homeBuilds += 1));
    await tester.pump();
    await tester.pump();

    expect(chat.markReads, 1);
    expect(homeBuilds, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('FIX_10: a failed mark-read does not refresh the Home badge', (
    tester,
  ) async {
    var homeBuilds = 0;
    final chat = _Fix10Chat()
      ..conversationResult = _conversation(status: 'ACTIVE')
      ..messagesResult = _opening()
      ..failMarkRead = true;
    await tester.pumpWidget(_badgeHarness(chat, () => homeBuilds += 1));
    await tester.pump();
    await tester.pump();

    expect(chat.markReads, 1);
    expect(homeBuilds, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _badgeHarness(ChatService chat, void Function() onHomeBuild) {
  return ProviderScope(
    overrides: [
      homeProvider.overrideWith((ref) {
        onHomeBuild();
        return Completer<HomeModel>().future;
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Column(
        children: [
          Consumer(
            builder: (context, ref, _) {
              ref.watch(homeProvider);
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: ChatConversationPage(
              conversationId: 'c-maria',
              chatService: chat,
              pollInterval: const Duration(seconds: 30),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Fix10Chat extends ChatService {
  _Fix10Chat() : super(dio: Dio());

  ChatConversation? requestResult;
  ChatConversation? conversationResult;
  List<ChatMessage> messagesResult = const [];
  String? requestedMessage;
  bool failMarkRead = false;
  int markReads = 0;

  @override
  Future<ChatConversation> request(
    String recipientUserId, {
    String? initialMessage,
  }) async {
    requestedMessage = initialMessage;
    conversationResult = requestResult;
    return requestResult!;
  }

  @override
  Future<ChatConversation> conversation(String conversationId) async =>
      conversationResult!;

  @override
  Future<List<ChatMessage>> messages(String conversationId) async =>
      messagesResult;

  @override
  Future<void> markRead(String conversationId) async {
    markReads += 1;
    if (failMarkRead) throw ChatException('offline');
  }

  @override
  Future<int> unreadCount() async => 0;
}
