import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_assets.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/community/data/reaction_type.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/presentation/football_chat_room_view.dart';

class _Net extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

class _FanNotifier extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    userId: 'fan-me',
    email: 'me@test.local',
    username: 'me',
    fullName: 'Yo',
    status: 'ACTIVE',
  );
}

Future<void> _settle(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

const _carajo = FootballChatSticker(
  id: 'garra_gol_carajo',
  name: 'Gol Carajo',
  category: 'gol_celebracion',
  glyph: '*',
  assetKey: 'garra/stickers/v1/garra_gol_carajo.webp',
);

FootballChatMessage _msg(
  String id, {
  String author = 'fan-other',
  String body = 'vamos',
  bool sticker = false,
  FootballChatReplyPreview? replyTo,
  List<ChatMessageReactionSummary> reactions = const [],
}) => FootballChatMessage(
  id: id,
  authorId: author,
  authorName: author == 'fan-me' ? 'Yo' : 'Hincha',
  authorUsername: 'h',
  body: sticker ? ':garra_gol_carajo:' : body,
  createdAt: DateTime.utc(2026, 10, 10, 20),
  replyTo: replyTo,
  reactions: reactions,
  messageType: sticker ? 'STICKER' : 'TEXT',
  stickerId: sticker ? 'garra_gol_carajo' : null,
  sticker: sticker ? _carajo : null,
);

class _Chat extends FootballChatService {
  _Chat(this.items) : super(dio: Dio());
  final List<FootballChatMessage> items;
  final Completer<FootballChatMessage> pendingSticker = Completer();
  final List<Map<String, Object?>> stickerSends = [];
  Map<String, Object?>? lastSend;
  ReactionType? lastReact;

  @override
  Future<FootballChatPage> page(
    FootballChatContext context, {
    DateTime? before,
    String? beforeId,
    int size = 30,
  }) async {
    if (before != null) {
      return const FootballChatPage(items: [], hasMore: false);
    }
    return FootballChatPage(items: items, hasMore: false);
  }

  @override
  Future<FootballChatStickerCatalog>
  stickerCatalog() async => const FootballChatStickerCatalog(
    items: [
      // Server object WITHOUT assetKey: the pending tile must still resolve it from the local catalog.
      FootballChatSticker(
        id: 'garra_gol_carajo',
        name: 'Gol Carajo',
        category: 'gol_celebracion',
        glyph: '*',
      ),
    ],
  );

  @override
  Future<List<FootballChatSticker>> stickerFavorites() async => const [];

  @override
  Future<FootballChatMessage> sendSticker(
    String stickerId, {
    FootballChatContext context = const FootballChatContext.general(),
    String? clientMessageId,
    String? replyToMessageId,
  }) {
    stickerSends.add({
      'id': stickerId,
      'clientMessageId': clientMessageId,
      'reply': replyToMessageId,
    });
    return pendingSticker.future;
  }

  @override
  Future<FootballChatMessage> send(
    String body, {
    FootballChatContext context = const FootballChatContext.general(),
    String? clientMessageId,
    String? replyToMessageId,
  }) async {
    lastSend = {
      'body': body,
      'replyToMessageId': replyToMessageId,
      'clientMessageId': clientMessageId,
    };
    return _msg('sent-1', author: 'fan-me', body: body);
  }

  @override
  Future<FootballChatReactionsResult> reactToMessage(
    String messageId,
    ReactionType type,
  ) async {
    lastReact = type;
    return FootballChatReactionsResult(
      messageId: messageId,
      reactions: [
        ChatMessageReactionSummary(
          type: type.apiValue,
          count: 1,
          reactedByMe: true,
        ),
      ],
      myReaction: type.apiValue,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Chat chat, {
  bool match = false,
}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectivityStatusProvider.overrideWith(_Net.new),
        currentFanProvider.overrideWith(_FanNotifier.new),
        footballChatServiceProvider.overrideWithValue(chat),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MainShellBranchScope(
            activeBranch: 1,
            child: match
                ? const FootballChatRoomView(
                    surface: FootballChatSurface.futbolero,
                    matchId: 1406077,
                  )
                : const FootballChatRoomView(
                    surface: FootballChatSurface.community,
                  ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester, 20);
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUp(GarraStickerAssets.debugReset);
  tearDown(GarraStickerAssets.debugReset);

  for (final match in [false, true]) {
    final label = match ? 'MATCH' : 'GENERAL';

    testWidgets(
      '$label: sticker has no bubble, no duplicate label, 144 box, glyph fallback',
      (tester) async {
        final chat = _Chat([
          _msg('s2', sticker: true),
          _msg(
            's1',
            sticker: true,
            reactions: const [
              ChatMessageReactionSummary(
                type: 'LIKE',
                count: 2,
                reactedByMe: false,
              ),
            ],
          ),
          _msg('t1', body: 'texto normal'),
        ]);
        await _pump(tester, chat, match: match);
        final bubble = find.byKey(const ValueKey('chat_msg_bubble_s1'));
        expect(bubble, findsOneWidget);
        final box = find.descendant(
          of: bubble,
          matching: find.byKey(const ValueKey('chat_sticker_box')),
        );
        expect(box, findsOneWidget);
        expect(tester.getSize(box), const Size(144, 144));
        // No maroon/decorated container around the sticker (s2 has no reaction chips).
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('chat_msg_bubble_s2')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).shape == BoxShape.rectangle,
            ),
          ),
          findsNothing,
        );
        // Name not repeated below the image (semantics only).
        expect(
          find.descendant(of: bubble, matching: find.text('Gol Carajo')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: bubble,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Semantics && w.properties.label == 'Sticker Gol Carajo',
            ),
          ),
          findsOneWidget,
        );
        // No CDN configured -> large glyph fallback in the same box.
        expect(
          find.descendant(
            of: box,
            matching: find.byKey(
              const Key('garra-sticker-fallback-garra_gol_carajo'),
            ),
          ),
          findsOneWidget,
        );
        // Author, time, reactions still present.
        expect(
          find.descendant(of: bubble, matching: find.text('Hincha')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('football-chat-reaction-tap-s1-LIKE')),
          findsOneWidget,
        );
        // Text bubble unchanged (crema: still a decorated bubble; MATCH: text rendered as before).
        expect(find.text('texto normal'), findsOneWidget);
        if (!match) {
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('chat_msg_bubble_t1')),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration! as BoxDecoration).shape ==
                        BoxShape.rectangle,
              ),
            ),
            findsWidgets,
          );
        }
        await _dispose(tester);
      },
    );

    testWidgets(
      '$label: gestures + reactions on sticker (long-press menu, swipe reply, ⋮ menu)',
      (tester) async {
        final chat = _Chat([_msg('s1', sticker: true)]);
        await _pump(tester, chat, match: match);
        await tester.longPress(
          find.byKey(const ValueKey('chat_msg_bubble_s1')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('chat_action_reply')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('chat_action_reply')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('chat_reply_composer')),
          findsOneWidget,
        );
        // Composer shows the sticker thumbnail and never the raw token.
        expect(
          find.byKey(const ValueKey('chat_reply_composer_thumb')),
          findsOneWidget,
        );
        expect(find.textContaining(':garra_gol_carajo:'), findsNothing);
        expect(find.text('Sticker: Gol Carajo'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const ValueKey('chat_msg_bubble_s1')),
          const Offset(120, 0),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('chat_reply_composer')),
          findsOneWidget,
        );
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('chat_msg_menu_s1')));
        await tester.pumpAndSettle();
        final reply = tester.getTopLeft(
          find.byKey(const ValueKey('chat_action_reply')),
        );
        final react = tester.getTopLeft(
          find.byKey(const ValueKey('chat_action_react')),
        );
        expect(
          reply.dy,
          lessThan(react.dy),
          reason: 'Responder is the first action',
        );
        await tester.tap(find.byKey(const ValueKey('chat_action_reply')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('chat_input')),
          'que golazo',
        );
        await tester.tap(find.byKey(const ValueKey('chat_send')));
        await _settle(tester, 8);
        expect(chat.lastSend?['replyToMessageId'], 's1');
        expect(find.textContaining(':garra_gol_carajo:'), findsNothing);
        await _dispose(tester);
      },
    );
  }

  testWidgets(
    'quote of a sticker shows 40dp thumbnail; text quote unchanged; unavailable placeholder',
    (tester) async {
      final chat = _Chat([
        _msg('s1', sticker: true),
        _msg('t1', body: 'arenga original'),
        _msg(
          'r1',
          body: 'respuesta a sticker',
          replyTo: const FootballChatReplyPreview(
            id: 's1',
            authorId: 'fan-other',
            authorName: 'Hincha',
            preview: 'Sticker: Gol Carajo',
          ),
        ),
        _msg(
          'r2',
          body: 'respuesta a texto',
          replyTo: const FootballChatReplyPreview(
            id: 't1',
            authorId: 'fan-other',
            authorName: 'Hincha',
            preview: 'arenga original',
          ),
        ),
        _msg(
          'r3',
          body: 'respuesta a borrado',
          replyTo: const FootballChatReplyPreview(
            id: 'gone',
            authorId: 'x',
            authorName: 'Otro',
            preview: 'Este mensaje ya no está disponible.',
            unavailable: true,
          ),
        ),
        // Original not loaded: resolved from the server preview name via the local catalog.
        _msg(
          'r4',
          body: 'respuesta antigua',
          replyTo: const FootballChatReplyPreview(
            id: 'old',
            authorId: 'x',
            authorName: 'Otro',
            preview: ':garra_gol_carajo:',
          ),
        ),
      ]);
      await _pump(tester, chat);
      final thumb = find.byKey(const ValueKey('chat_quote_thumb_s1'));
      expect(thumb, findsOneWidget);
      expect(tester.getSize(thumb), const Size(40, 40));
      expect(find.byKey(const ValueKey('chat_quote_thumb_t1')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('chat_quote_t1')),
          matching: find.text('arenga original'),
        ),
        findsOneWidget,
      );
      expect(find.text('Mensaje no disponible'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_quote_thumb_gone')), findsNothing);
      expect(
        find.byKey(const ValueKey('chat_quote_thumb_old')),
        findsOneWidget,
      );
      expect(find.textContaining(':garra_gol_carajo:'), findsNothing);
      await _dispose(tester);
    },
  );

  testWidgets(
    'optimistic sticker renders the image (local assetKey) immediately, reply preview readable',
    (tester) async {
      GarraStickerAssets.debugReset();
      // Remote sticker config answered once by a stub Dio (no real network), memoized by GarraStickerAssets.
      final stub = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) => h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {
                  'data': {'assetBaseUrl': ''},
                },
              ),
            ),
          ),
        );
      await tester.runAsync(
        () => GarraStickerAssets.ensureRemoteConfig(dio: stub),
      );
      final chat = _Chat([_msg('s0', sticker: true)]);
      await _pump(tester, chat);
      await tester.tap(find.byKey(const ValueKey('football_chat_sticker_btn')));
      await tester.pump();
      // Let the (stubbed, memoized) config future and catalog load resolve on the real event loop.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await _settle(tester, 20);
      await tester.tap(
        find.byKey(const Key('football_chat_sticker_garra_gol_carajo')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(chat.stickerSends, hasLength(1));
      expect(chat.stickerSends.single['clientMessageId'], isNotNull);
      final pending = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('chat_out_'),
      );
      expect(pending, findsOneWidget);
      // The server catalog object had NO assetKey: the pending tile resolved it from the local catalog,
      // so with a CDN configured it goes straight to the image path (no glyph-only render).
      final img = tester.widget<GarraStickerImage>(
        find.descendant(of: pending, matching: find.byType(GarraStickerImage)),
      );
      expect(img.assetKey, 'garra/stickers/v1/garra_gol_carajo.webp');
      expect(img.size, 144);
      expect(
        GarraStickerAssets.fullUrl(
          img.assetKey,
          base: 'https://cdn.example.invalid',
        ),
        'https://cdn.example.invalid/garra/stickers/v1/garra_gol_carajo.webp',
      );
      final opacity = tester.widget<Opacity>(pending);
      expect(opacity.opacity, 0.6);
      chat.pendingSticker.complete(_msg('s9', author: 'fan-me', sticker: true));
      await _settle(tester, 6);
      expect(pending, findsNothing);
      await _dispose(tester);
    },
  );
}
