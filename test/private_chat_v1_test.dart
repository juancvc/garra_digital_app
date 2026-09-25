import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_conversation_page.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_inbox_page.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/marketplace_chat_button.dart';
import 'package:garra_digital_app/features/notifications/data/push_router.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('public profile shows Mensaje for another fan', (tester) async {
    await tester.pumpWidget(
      _app(
        PublicFanProfilePage(
          userId: 'fan-2',
          communityService: _FakeCommunity(_profile(me: false)),
          chatService: _FakeChat(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Seguir'), findsOneWidget);
    expect(find.text('Mensaje'), findsOneWidget);
  });

  testWidgets('own profile does not show Mensaje', (tester) async {
    await tester.pumpWidget(
      _app(
        PublicFanProfilePage(
          userId: 'fan-1',
          communityService: _FakeCommunity(_profile(me: true)),
          chatService: _FakeChat(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Editar perfil'), findsWidgets);
    expect(find.text('Mensaje'), findsNothing);
  });

  testWidgets('inbox renders conversation and unread badge', (tester) async {
    final chat = _FakeChat()
      ..conversationsResult = [
        ChatConversation(
          id: 'c-diego',
          otherUserId: 'u02',
          otherDisplayName: 'María Quispe',
          status: 'ACTIVE',
          lastMessagePreview: 'Nos vemos en la previa...',
          lastMessageAt: DateTime.now().subtract(const Duration(minutes: 5)),
          unreadCount: 2,
        ),
      ];

    await tester.pumpWidget(_app(ChatInboxPage(chatService: chat)));
    await tester.pump();

    expect(find.text('Mensajes'), findsOneWidget);
    expect(find.text('María Quispe'), findsOneWidget);
    expect(find.text('Nos vemos en la previa...'), findsOneWidget);
    expect(find.byKey(const Key('chat-unread-badge')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('requests tab renders an incoming request', (tester) async {
    final chat = _FakeChat()
      ..requestsResult = [
        const ChatConversation(
          id: 'req-miguel',
          otherUserId: 'u08',
          otherDisplayName: 'Miguel Rojas',
          status: 'PENDING',
        ),
      ];

    await tester.pumpWidget(_app(ChatInboxPage(chatService: chat)));
    await tester.pump();
    await tester.tap(find.text('Solicitudes'));
    await tester.pump();

    expect(find.text('Miguel Rojas'), findsOneWidget);
    expect(
      find.text('Quiere iniciar una conversación contigo'),
      findsOneWidget,
    );
    expect(find.text('Aceptar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  });

  testWidgets('accept action works', (tester) async {
    final chat = _FakeChat()
      ..requestsResult = [
        const ChatConversation(
          id: 'req-miguel',
          otherUserId: 'u08',
          otherDisplayName: 'Miguel Rojas',
          status: 'PENDING',
        ),
      ];

    await tester.pumpWidget(_app(ChatInboxPage(chatService: chat)));
    await tester.pump();
    await tester.tap(find.text('Solicitudes'));
    await tester.pump();
    await tester.tap(find.text('Aceptar'));
    await tester.pump();

    expect(chat.acceptedId, 'req-miguel');
  });

  testWidgets('reject action works', (tester) async {
    final chat = _FakeChat()
      ..requestsResult = [
        const ChatConversation(
          id: 'req-miguel',
          otherUserId: 'u08',
          otherDisplayName: 'Miguel Rojas',
          status: 'PENDING',
        ),
      ];

    await tester.pumpWidget(_app(ChatInboxPage(chatService: chat)));
    await tester.pump();
    await tester.tap(find.text('Solicitudes'));
    await tester.pump();
    await tester.tap(find.text('Rechazar'));
    await tester.pump();

    expect(chat.rejectedId, 'req-miguel');
  });

  testWidgets('conversation renders left and right bubbles', (tester) async {
    final chat = _scriptedConversation();
    await tester.pumpWidget(
      _app(
        ChatConversationPage(
          conversationId: 'c-diego',
          chatService: chat,
          pollInterval: const Duration(seconds: 30),
        ),
      ),
    );
    await tester.pump();

    final mine = tester.widget<Align>(find.byKey(const Key('chat-bubble-mine')));
    final other =
        tester.widget<Align>(find.byKey(const Key('chat-bubble-other')));
    expect(mine.alignment, Alignment.centerRight);
    expect(other.alignment, Alignment.centerLeft);
    expect(find.text('¿Vas a la previa este sábado?'), findsOneWidget);
    expect(
      find.text('Sí, estamos coordinando para llegar temprano.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sending appends a message', (tester) async {
    final chat = _scriptedConversation();
    await tester.pumpWidget(
      _app(
        ChatConversationPage(
          conversationId: 'c-diego',
          chatService: chat,
          pollInterval: const Duration(seconds: 30),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Listo, nos vemos');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();

    expect(chat.sent, ['Listo, nos vemos']);
    expect(find.text('Listo, nos vemos'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('CHAT_CONVERSATION notification routes to the conversation', () {
    const router = PushRouter();
    expect(
      router.resolveRoute(
        authenticated: true,
        referenceType: 'CHAT_CONVERSATION',
        referenceId: 'c-diego',
      ),
      '/chat/c-diego',
    );
    expect(
      router.resolveRoute(
        authenticated: true,
        referenceType: 'CHAT_CONVERSATION',
      ),
      '/notifications',
    );
    expect(
      router.resolveRoute(
        authenticated: true,
        type: 'CHAT',
        referenceType: 'UNKNOWN',
      ),
      '/notifications',
    );
  });

  testWidgets('marketplace composer opens with an editable listing message', (
    tester,
  ) async {
    final chat = _FakeChat();
    await tester.pumpWidget(_marketplaceApp(chat, listingTitle: 'Camiseta crema'));
    await tester.tap(find.byKey(const Key('marketplace-chat-cta')));
    await tester.pumpAndSettle();

    expect(find.text('Consultar al vendedor'), findsOneWidget);
    expect(find.text('Camiseta crema'), findsOneWidget);
    final draft = tester.widget<TextField>(
      find.byKey(const Key('marketplace-chat-draft')),
    );
    expect(
      draft.controller?.text,
      'Hola, me interesa Camiseta crema. ¿Sigue disponible?',
    );

    await tester.enterText(
      find.byKey(const Key('marketplace-chat-draft')),
      '¿La camiseta sigue disponible en talla M?',
    );
    await tester.tap(find.byKey(const Key('marketplace-chat-send')));
    await tester.pumpAndSettle();

    expect(chat.requestedUser, 'seller-lucia');
    expect(
      chat.requestedMessage,
      '¿La camiseta sigue disponible en talla M?',
    );
    expect(find.text('Solicitud enviada'), findsOneWidget);
    expect(
      find.text('El vendedor podrá responder cuando acepte tu solicitud.'),
      findsOneWidget,
    );
    expect(find.text('¿La camiseta sigue disponible en talla M?'), findsOneWidget);
    expect(find.text('Esperando que acepte tu solicitud'), findsWidgets);
    final composer = tester.widget<TextField>(find.byKey(const Key('chat-composer')));
    expect(composer.enabled, isFalse);
  });

  testWidgets('existing pending marketplace chat opens the thread', (tester) async {
    final chat = _FakeChat()
      ..relationshipResult = const ChatRelationship(
        conversationId: 'pending-1',
        status: 'PENDING',
        outgoing: true,
      )
      ..conversationResult = const ChatConversation(
        id: 'pending-1',
        otherUserId: 'seller-lucia',
        otherDisplayName: 'Lucía Vargas',
        status: 'PENDING',
        outgoing: true,
      )
      ..messagesResult = const [
        ChatMessage(
          id: 'm-open',
          conversationId: 'pending-1',
          senderId: 'me',
          content: 'Hola, me interesa la camiseta.',
          mine: true,
        ),
      ];

    await tester.pumpWidget(_marketplaceApp(chat));
    await tester.tap(find.byKey(const Key('marketplace-chat-cta')));
    await tester.pumpAndSettle();

    expect(find.text('Consultar al vendedor'), findsNothing);
    expect(find.text('Hola, me interesa la camiseta.'), findsOneWidget);
    expect(find.text('Esperando que acepte tu solicitud'), findsWidgets);
    expect(chat.requestedUser, isNull);
  });

  testWidgets('active marketplace relationship opens the chat directly', (
    tester,
  ) async {
    final chat = _FakeChat()
      ..relationshipResult = const ChatRelationship(
        conversationId: 'active-1',
        status: 'ACTIVE',
      )
      ..conversationResult = const ChatConversation(
        id: 'active-1',
        otherUserId: 'seller-lucia',
        otherDisplayName: 'Lucía Vargas',
        status: 'ACTIVE',
      )
      ..messagesResult = const [
        ChatMessage(
          id: 'm1',
          conversationId: 'active-1',
          senderId: 'seller-lucia',
          content: 'Sigue disponible',
          mine: false,
        ),
      ];

    await tester.pumpWidget(_marketplaceApp(chat));
    await tester.tap(find.byKey(const Key('marketplace-chat-cta')));
    await tester.pumpAndSettle();

    expect(find.text('Consultar al vendedor'), findsNothing);
    expect(find.text('Sigue disponible'), findsOneWidget);
    final composer = tester.widget<TextField>(find.byKey(const Key('chat-composer')));
    expect(composer.enabled, isTrue);
  });

  testWidgets('pending recipient sees the opening message and can accept', (
    tester,
  ) async {
    final chat = _FakeChat()
      ..conversationResult = const ChatConversation(
        id: 'pending-in',
        otherUserId: 'buyer-1',
        otherDisplayName: 'Ana',
        status: 'PENDING',
        outgoing: false,
      )
      ..messagesResult = const [
        ChatMessage(
          id: 'm-open',
          conversationId: 'pending-in',
          senderId: 'buyer-1',
          content: 'Hola, me interesa la camiseta.',
          mine: false,
        ),
      ];

    await tester.pumpWidget(
      _app(
        ChatConversationPage(
          conversationId: 'pending-in',
          chatService: chat,
          pollInterval: const Duration(minutes: 5),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Hola, me interesa la camiseta.'), findsOneWidget);
    expect(find.byKey(const Key('chat-composer')), findsNothing);
    expect(find.byKey(const Key('chat-accept-request')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-accept-request')));
    await tester.pump();

    expect(chat.acceptedId, 'pending-in');
    final composer = tester.widget<TextField>(find.byKey(const Key('chat-composer')));
    expect(composer.enabled, isTrue);
  });

  testWidgets('polling stops when the conversation page is disposed', (
    tester,
  ) async {
    final chat = _scriptedConversation();
    await tester.pumpWidget(
      _app(
        ChatConversationPage(
          conversationId: 'c-diego',
          chatService: chat,
          pollInterval: const Duration(milliseconds: 80),
        ),
      ),
    );
    await tester.pump();
    expect(chat.messageLoads, 1);

    await tester.pump(const Duration(milliseconds: 100));
    expect(chat.messageLoads, greaterThan(1));
    final afterPoll = chat.messageLoads;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));

    expect(chat.messageLoads, afterPoll);
  });
}

Widget _app(Widget home) {
  return MaterialApp(theme: AppTheme.darkTheme, home: home);
}

Widget _marketplaceApp(_FakeChat chat, {String listingTitle = 'Camiseta crema'}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ConsultarPorChatButton(
            sellerUserId: 'seller-lucia',
            listingTitle: listingTitle,
            chatService: chat,
          ),
        ),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) => ChatConversationPage(
          conversationId: state.pathParameters['conversationId']!,
          chatService: chat,
          requestJustSent: state.uri.queryParameters['sent'] == '1',
          pollInterval: const Duration(minutes: 5),
        ),
      ),
    ],
  );
  return MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router);
}

Map<String, dynamic> _profile({required bool me}) {
  return {
    'displayName': me ? 'Tú' : 'María Quispe',
    'username': me ? 'yo' : 'mariaquispe',
    'followerCount': 4,
    'followingCount': 2,
    'globalPostCount': 0,
    'isFollowedByMe': false,
    'isBlockedByMe': false,
    'isMe': me,
    'globalPosts': <dynamic>[],
  };
}

_FakeChat _scriptedConversation() {
  return _FakeChat()
    ..conversationResult = const ChatConversation(
      id: 'c-diego',
      otherUserId: 'u02',
      otherDisplayName: 'Diego Ramos',
      status: 'ACTIVE',
    )
    ..messagesResult = const [
      ChatMessage(
        id: 'm1',
        conversationId: 'c-diego',
        senderId: 'u01',
        content: '¿Vas a la previa este sábado?',
        mine: false,
      ),
      ChatMessage(
        id: 'm2',
        conversationId: 'c-diego',
        senderId: 'u02',
        content: 'Sí, estamos coordinando para llegar temprano.',
        mine: true,
      ),
    ];
}

class _FakeCommunity extends CommunityService {
  _FakeCommunity(this.profile) : super(dio: Dio());

  final Map<String, dynamic> profile;

  @override
  Future<Map<String, dynamic>> getPublicProfile(String userId) async => profile;
}

class _FakeChat extends ChatService {
  _FakeChat() : super(dio: Dio());

  List<ChatConversation> conversationsResult = const [];
  List<ChatConversation> requestsResult = const [];
  List<ChatMessage> messagesResult = const [];
  ChatConversation? conversationResult;
  ChatRelationship relationshipResult = ChatRelationship.none();
  String? requestedUser;
  String? requestedMessage;
  String? acceptedId;
  String? rejectedId;
  final List<String> sent = [];
  int messageLoads = 0;

  @override
  Future<ChatRelationship> relationship(String userId) async => relationshipResult;

  @override
  Future<ChatConversation> request(
    String recipientUserId, {
    String? initialMessage,
  }) async {
    requestedUser = recipientUserId;
    requestedMessage = initialMessage;
    final created = ChatConversation(
      id: 'requested',
      otherUserId: recipientUserId,
      otherDisplayName: 'Lucía Vargas',
      status: 'PENDING',
      outgoing: true,
    );
    conversationResult = created;
    messagesResult = [
      ChatMessage(
        id: 'm-open',
        conversationId: 'requested',
        senderId: 'me',
        content: initialMessage ?? '',
        mine: true,
      ),
    ];
    return created;
  }

  @override
  Future<List<ChatConversation>> incoming() async => requestsResult;

  @override
  Future<ChatConversation> accept(String conversationId) async {
    acceptedId = conversationId;
    return ChatConversation(
      id: conversationId,
      otherUserId: 'u08',
      otherDisplayName: 'Miguel Rojas',
      status: 'ACTIVE',
    );
  }

  @override
  Future<ChatConversation> reject(String conversationId) async {
    rejectedId = conversationId;
    return ChatConversation(
      id: conversationId,
      otherUserId: 'u08',
      otherDisplayName: 'Miguel Rojas',
      status: 'REJECTED',
    );
  }

  @override
  Future<List<ChatConversation>> conversations() async => conversationsResult;

  @override
  Future<ChatConversation> conversation(String conversationId) async {
    return conversationResult ??
        ChatConversation(
          id: conversationId,
          otherUserId: 'u02',
          otherDisplayName: 'Diego Ramos',
          status: 'ACTIVE',
        );
  }

  @override
  Future<List<ChatMessage>> messages(String conversationId) async {
    messageLoads += 1;
    return messagesResult;
  }

  @override
  Future<ChatMessage> send(String conversationId, String content) async {
    sent.add(content);
    return ChatMessage(
      id: 'sent',
      conversationId: conversationId,
      senderId: 'me',
      content: content,
      mine: true,
    );
  }

  @override
  Future<void> markRead(String conversationId) async {}

  @override
  Future<int> unreadCount() async => 0;
}
