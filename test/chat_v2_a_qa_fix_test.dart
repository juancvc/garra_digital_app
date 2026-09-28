import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_conversation_page.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_unread_badge.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/data/home_service.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/marketplace/presentation/marketplace_chat_button.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// CHAT_V2_A_QA_FIX: physical QA findings (bell refresh, marketplace chat CTA,
/// composer keyboard config and send button state).
void main() {
  group('bell and unread refresh', () {
    testWidgets(
      'A successful mark-read refetches the Home bell and chat unread',
      (tester) async {
        final home = _Home([7, 5]);
        final chat = _Chat()..unreadSequence = [2, 1];
        final router = _shellRouter(chat);
        await tester.pumpWidget(_scope(home, chat, router));
        await _settle(tester);
        expect(_bell('7'), findsOneWidget);
        expect(_messages('2'), findsOneWidget);
        expect(home.calls, 1);

        router.push('/chat/c1');
        await _transition(tester);
        expect(chat.markReads, 1);

        router.pop();
        await _transition(tester);
        expect(home.calls, 2);
        expect(chat.unreadCalls, greaterThanOrEqualTo(2));
        expect(_bell('5'), findsOneWidget);
        expect(_messages('1'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('B badges show the server value, never a local zero', (
      tester,
    ) async {
      // 5 legit non-chat notifications stay after reading the chat.
      final home = _Home([7, 5]);
      final chat = _Chat()..unreadSequence = [2, 1];
      final router = _shellRouter(chat);
      await tester.pumpWidget(_scope(home, chat, router));
      await _settle(tester);

      router.push('/chat/c1');
      await _transition(tester);
      router.pop();
      await _transition(tester);

      expect(_bell('7'), findsNothing);
      expect(_bell('0'), findsNothing);
      expect(_bell('5'), findsOneWidget);
      expect(_messages('0'), findsNothing);
      expect(_messages('1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('failed mark-read does not refetch or touch the badges', (
      tester,
    ) async {
      final home = _Home([7, 5]);
      final chat = _Chat()
        ..unreadSequence = [2, 1]
        ..failMarkRead = true;
      final router = _shellRouter(chat);
      await tester.pumpWidget(_scope(home, chat, router));
      await _settle(tester);

      router.push('/chat/c1');
      await _transition(tester);
      expect(home.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('marketplace chat CTA', () {
    testWidgets('C secondary CTA has a visible natural label', (tester) async {
      await tester.pumpWidget(_ctaApp(AppTheme.darkTheme));
      await tester.pump();

      final cta = find.byKey(const Key('marketplace-chat-cta'));
      expect(cta, findsOneWidget);
      expect(
        find.descendant(of: cta, matching: find.text('Consultar por chat')),
        findsOneWidget,
      );
      expect(find.textContaining('Contactar vendedor'), findsNothing);
      expect(
        find.descendant(
          of: cta,
          matching: find.byIcon(Icons.chat_bubble_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('D label is readable in Crema', (tester) async {
      await _expectReadableCta(
        tester,
        AppTheme.lightTheme,
        GarraSemanticColors.crema,
      );
    });

    testWidgets('E label is readable in Noche', (tester) async {
      await _expectReadableCta(
        tester,
        AppTheme.darkTheme,
        GarraSemanticColors.noche,
      );
    });
  });

  group('composer', () {
    testWidgets('F composer keyboard configuration', (tester) async {
      await tester.pumpWidget(_conversationApp(_Chat()));
      await _settle(tester);

      final field = tester.widget<TextField>(
        find.byKey(const Key('chat-composer')),
      );
      expect(field.keyboardType, TextInputType.multiline);
      expect(field.textInputAction, TextInputAction.send);
      expect(field.minLines, 1);
      expect(field.maxLines, 4);
      expect(field.maxLength, 1000);
      expect(field.autocorrect, isTrue);
      expect(field.enableSuggestions, isTrue);
      expect(field.textCapitalization, TextCapitalization.sentences);
    });

    testWidgets('G send is disabled with empty text and no media', (
      tester,
    ) async {
      final chat = _Chat();
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      expect(_sendButton(tester).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('chat-composer')), '   ');
      await tester.pump();
      expect(_sendButton(tester).onPressed, isNull);
      await tester.tap(find.byTooltip('Enviar'), warnIfMissed: false);
      await tester.pump();
      expect(chat.sent, isEmpty);
    });

    testWidgets('H send is enabled with valid text', (tester) async {
      final chat = _Chat();
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      await tester.enterText(
        find.byKey(const Key('chat-composer')),
        'Nos vemos en la puerta 5',
      );
      await tester.pump();
      expect(_sendButton(tester).onPressed, isNotNull);
      await tester.tap(find.byTooltip('Enviar'));
      await _settle(tester);
      expect(chat.sent, ['Nos vemos en la puerta 5']);
      expect(_sendButton(tester).onPressed, isNull);
    });

    testWidgets('I send is enabled with a ready photo and empty text', (
      tester,
    ) async {
      final chat = _Chat();
      await tester.pumpWidget(_conversationApp(chat, media: _Media()));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('chat-attach-photo')));
      await _settle(tester);
      expect(find.byKey(const Key('chat-image-preview-0')), findsOneWidget);
      expect(_sendButton(tester).onPressed, isNotNull);

      await tester.tap(find.byTooltip('Enviar'));
      await _settle(tester);
      expect(chat.sent, ['']);
      expect(chat.sentMedia.single, ['asset-photo-0.jpg']);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

Finder _bell(String count) => find.descendant(
  of: find.byTooltip('Notificaciones'),
  matching: find.text(count),
);

Finder _messages(String count) => find.descendant(
  of: find.byKey(const Key('messages-entry')),
  matching: find.text(count),
);

IconButton _sendButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(const Key('chat-send')));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<void> _transition(WidgetTester tester) async {
  await _settle(tester);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await _settle(tester);
}

/// Mirrors the app: Home lives in an IndexedStack shell branch and the
/// conversation is pushed above the shell on the root navigator.
GoRouter _shellRouter(_Chat chat) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/other',
                builder: (context, state) => const Scaffold(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) => ChatConversationPage(
          conversationId: state.pathParameters['conversationId']!,
          chatService: chat,
          pollInterval: const Duration(minutes: 5),
        ),
      ),
    ],
  );
}

Widget _scope(_Home home, _Chat chat, GoRouter router) {
  return ProviderScope(
    overrides: [
      homeServiceProvider.overrideWithValue(home),
      chatServiceProvider.overrideWithValue(chat),
    ],
    child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  );
}

Widget _conversationApp(_Chat chat, {MediaUploadService? media}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: ChatConversationPage(
      conversationId: 'c1',
      chatService: chat,
      mediaService: media,
      pollInterval: const Duration(minutes: 5),
    ),
  );
}

Widget _ctaApp(ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ConsultarPorChatButton(
          sellerUserId: 'seller-1',
          listingTitle: 'Camiseta retro',
          chatService: _Chat(),
        ),
      ),
    ),
  );
}

Future<void> _expectReadableCta(
  WidgetTester tester,
  ThemeData theme,
  GarraSemanticColors expected,
) async {
  await tester.pumpWidget(_ctaApp(theme));
  await tester.pump();

  final cta = find.byKey(const Key('marketplace-chat-cta'));
  final label = tester.widget<RichText>(
    find.descendant(of: cta, matching: find.byType(RichText)).first,
  );
  final color = label.text.style?.color;
  expect(color, expected.textPrimary);
  expect(_contrast(color!, expected.background), greaterThanOrEqualTo(4.5));
  final button = tester.widget<ButtonStyleButton>(cta);
  expect(
    button.style?.side?.resolve(<WidgetState>{})?.color,
    expected.brandPrimary,
  );
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

class _Home extends HomeService {
  _Home(this.counts) : super(dio: Dio());

  final List<int> counts;
  int calls = 0;

  @override
  Future<HomeModel> getHome() async {
    final count = counts[calls < counts.length ? calls : counts.length - 1];
    calls += 1;
    return HomeModel.fromJson({
      'fan': {'displayName': 'Hincha'},
      'notifications': {'unreadCount': count},
    });
  }
}

class _Chat extends ChatService {
  _Chat() : super(dio: Dio());

  List<int> unreadSequence = const [0];
  int unreadCalls = 0;
  int markReads = 0;
  bool failMarkRead = false;
  final List<String> sent = [];
  final List<List<String>> sentMedia = [];

  @override
  Future<ChatRelationship> relationship(
    String userId, {
    String context = 'SOCIAL',
  }) async => ChatRelationship.none();

  @override
  Future<ChatConversation> conversation(String conversationId) async =>
      const ChatConversation(
        id: 'c1',
        otherUserId: 'u2',
        otherDisplayName: 'Diego Ramos',
        status: 'ACTIVE',
      );

  @override
  Future<List<ChatMessage>> messages(String conversationId) async => const [
    ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      senderId: 'u2',
      content: 'Hola',
      mine: false,
    ),
  ];

  @override
  Future<void> markRead(String conversationId) async {
    if (failMarkRead) throw ChatException('offline');
    markReads += 1;
  }

  @override
  Future<int> unreadCount() async {
    final index = unreadCalls < unreadSequence.length
        ? unreadCalls
        : unreadSequence.length - 1;
    unreadCalls += 1;
    return unreadSequence[index];
  }

  @override
  Future<ChatMessage> send(
    String conversationId,
    String content, {
    List<String> mediaAssetIds = const [],
  }) async {
    sent.add(content);
    sentMedia.add(mediaAssetIds);
    return ChatMessage(
      id: 'sent-${sent.length}',
      conversationId: conversationId,
      senderId: 'me',
      content: content,
      mine: true,
      createdAt: DateTime.now(),
    );
  }
}

class _Media extends MediaUploadService {
  _Media() : super(dio: Dio(), binaryClient: Dio());

  @override
  Future<List<XFile>> pickMultiImage({int max = 4}) async => [
    XFile('photo-0.jpg'),
  ];

  @override
  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
  }) async {
    final draft = MediaDraft(
      localId: file.path,
      state: MediaUploadState.uploading,
    );
    onUpdate?.call(draft);
    draft
      ..assetId = 'asset-${file.path}'
      ..mediaUrl = 'https://example.invalid/${file.path}'
      ..state = MediaUploadState.ready
      ..progress = 1;
    onUpdate?.call(draft);
    return draft;
  }
}
