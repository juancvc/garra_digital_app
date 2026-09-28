import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/core/widgets/garra_avatar.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_conversation_page.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_inbox_page.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_unread_badge.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/marketplace/presentation/marketplace_chat_button.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_PE');
  });

  group('CHAT_V2_A inbox', () {
    testWidgets('1 row shows avatar, name and preview', (tester) async {
      final chat = _Chat()
        ..conversationsResult = [
          _row(preview: 'Nos vemos en la previa', at: _today(20, 42)),
        ];
      await tester.pumpWidget(_inboxApp(chat));
      await _settle(tester);

      expect(find.text('Mensajes'), findsOneWidget);
      expect(find.text('Mar\u00eda Quispe'), findsOneWidget);
      expect(find.text('Nos vemos en la previa'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is GarraAvatar && w.displayName == 'Mar\u00eda Quispe',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chat-inbox-refresh')), findsOneWidget);
    });

    testWidgets('2 today shows the local time (es_PE, no seconds)', (
      tester,
    ) async {
      final at = _today(20, 42);
      final chat = _Chat()..conversationsResult = [_row(at: at)];
      await tester.pumpWidget(_inboxApp(chat));
      await _settle(tester);

      final expected = DateFormat('h:mm a', 'es_PE').format(at);
      expect(find.text(expected), findsOneWidget);
      expect(expected, startsWith('8:42'));
      expect(expected, contains('m.'));
      expect(find.textContaining('hace'), findsNothing);
    });

    testWidgets('3 yesterday shows Ayer', (tester) async {
      final chat = _Chat()..conversationsResult = [_row(at: _daysAgo(1, 9, 5))];
      await tester.pumpWidget(_inboxApp(chat));
      await _settle(tester);

      expect(find.text('Ayer'), findsOneWidget);
    });

    testWidgets('4 older shows dd/MM/yy', (tester) async {
      final at = _daysAgo(6, 18, 0);
      final chat = _Chat()..conversationsResult = [_row(at: at)];
      await tester.pumpWidget(_inboxApp(chat));
      await _settle(tester);

      expect(find.text(DateFormat('dd/MM/yy').format(at)), findsOneWidget);
    });

    testWidgets('5 unread conversation shows a badge and stronger name', (
      tester,
    ) async {
      final chat = _Chat()
        ..conversationsResult = [
          _row(id: 'c-unread', name: 'Ana Torres', unread: 3),
          _row(id: 'c-read', name: 'Luis Soto'),
        ];
      await tester.pumpWidget(_inboxApp(chat));
      await _settle(tester);

      expect(find.byKey(const Key('chat-unread-badge')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      final unreadName = tester.widget<Text>(find.text('Ana Torres'));
      final readName = tester.widget<Text>(find.text('Luis Soto'));
      expect(unreadName.style?.fontWeight, FontWeight.w700);
      expect(readName.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('6 marketplace row shows a discreet listing context', (
      tester,
    ) async {
      final chat = _Chat()
        ..conversationsResult = [
          _row(context: 'MARKETPLACE', listingTitle: 'Camiseta retro 1971'),
        ];
      await tester.pumpWidget(_inboxApp(chat));
      await _settle(tester);

      final label = find.text('Marketplace \u00b7 Camiseta retro 1971');
      expect(label, findsOneWidget);
      expect(tester.widget<Text>(label).style?.fontSize, lessThan(13));
    });

    testWidgets('7 social row never shows seller or marketplace copy', (
      tester,
    ) async {
      final chat = _Chat()
        ..conversationsResult = [_row(listingTitle: 'Camiseta retro 1971')];
      await tester.pumpWidget(_inboxApp(chat));
      await _settle(tester);

      expect(
        find.textContaining(
          RegExp('marketplace|vendedor|comprador', caseSensitive: false),
        ),
        findsNothing,
      );
    });

    testWidgets('8 request shows avatar, preview, state and can be accepted', (
      tester,
    ) async {
      final chat = _Chat()
        ..requestsResult = [
          ChatConversation(
            id: 'req-1',
            otherUserId: 'u8',
            otherDisplayName: 'Miguel Rojas',
            status: 'PENDING',
            lastMessagePreview: 'Hola, \u00bfvamos juntos al Monumental?',
            lastMessageAt: _today(10, 15),
          ),
        ];
      await tester.pumpWidget(_inboxApp(chat));
      await _settle(tester);
      expect(find.byKey(const Key('chat-requests-count')), findsOneWidget);
      await tester.tap(find.text('Solicitudes'));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is GarraAvatar && w.displayName == 'Miguel Rojas',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Hola, \u00bfvamos juntos al Monumental?'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chat-request-state-req-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-request-accept-req-1')));
      await _settle(tester);
      expect(chat.acceptedId, 'req-1');
      expect(find.byKey(const Key('chat-inbox-row-req-1')), findsOneWidget);
    });

    testWidgets('9 tapping an ACTIVE row opens /chat/:id and reloads on back', (
      tester,
    ) async {
      final chat = _Chat()..conversationsResult = [_row(id: 'c-77')];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ChatInboxPage(chatService: chat),
          ),
          GoRoute(
            path: '/chat/:conversationId',
            builder: (context, state) => Scaffold(
              body: Text('CHAT_${state.pathParameters['conversationId']}'),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      );
      await _settle(tester);
      expect(chat.conversationsCalls, 1);

      await tester.tap(find.byKey(const Key('chat-inbox-row-c-77')));
      await _transition(tester);
      expect(find.text('CHAT_c-77'), findsOneWidget);

      router.pop();
      await _transition(tester);
      expect(find.text('Mar\u00eda Quispe'), findsOneWidget);
      expect(chat.conversationsCalls, 2);
    });

    testWidgets('10 Home header has a Mensajes entry with unread badge', (
      tester,
    ) async {
      final chat = _Chat()..unread = 3;
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/chat',
            builder: (context, state) =>
                const Scaffold(body: Text('INBOX_ROUTE')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeProvider.overrideWith((ref) => Completer<HomeModel>().future),
            chatServiceProvider.overrideWithValue(chat),
          ],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await _settle(tester);

      final entry = find.byKey(const Key('messages-entry'));
      expect(entry, findsOneWidget);
      expect(find.byTooltip('Mensajes'), findsOneWidget);
      expect(
        find.descendant(of: entry, matching: find.text('3')),
        findsOneWidget,
      );
      expect(chat.unreadCalls, 1);

      await tester.tap(entry);
      await _transition(tester);
      expect(find.text('INBOX_ROUTE'), findsOneWidget);

      router.pop();
      await _transition(tester);
      expect(chat.unreadCalls, 2);
    });

    testWidgets('11 my profile has a Mensajes entry to the inbox', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PublicFanProfilePage(
              userId: 'fan-1',
              communityService: _Community(),
              chatService: _Chat(),
            ),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) =>
                const Scaffold(body: Text('INBOX_ROUTE')),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      );
      await _settle(tester);

      final entry = find.byKey(const Key('profile-messages-entry'));
      expect(entry, findsOneWidget);
      expect(find.text('Mensaje'), findsNothing);
      await tester.tap(entry);
      await _transition(tester);
      expect(find.text('INBOX_ROUTE'), findsOneWidget);
    });

    testWidgets('12 inbox uses Crema tokens', (tester) async {
      await _expectInboxTheme(
        tester,
        AppTheme.lightTheme,
        GarraSemanticColors.crema,
      );
    });

    testWidgets('13 inbox uses Noche tokens', (tester) async {
      await _expectInboxTheme(
        tester,
        AppTheme.darkTheme,
        GarraSemanticColors.noche,
      );
    });

    testWidgets('empty inbox shows the professional empty state', (
      tester,
    ) async {
      await tester.pumpWidget(_inboxApp(_Chat()));
      await _settle(tester);
      expect(find.text('A\u00fan no tienes conversaciones'), findsOneWidget);
    });
  });

  group('CHAT_V2_A conversation', () {
    testWidgets('14 message shows its local time', (tester) async {
      final at = _today(20, 37);
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false, at: at)];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      final expected = DateFormat('h:mm a', 'es_PE').format(at);
      expect(find.text(expected), findsOneWidget);
      expect(expected, startsWith('8:37'));
    });

    testWidgets('15 Hoy separator', (tester) async {
      final chat = _Chat()
        ..messagesResult = [_msg('m1', mine: false, at: _today(9, 0))];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      expect(find.text('Hoy'), findsOneWidget);
      expect(find.byKey(const Key('chat-day-separator')), findsOneWidget);
    });

    testWidgets('16 Ayer separator', (tester) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, at: _daysAgo(1, 21, 0)),
          _msg('m2', mine: true, at: _today(9, 0)),
        ];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      expect(find.text('Ayer'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
    });

    testWidgets('17 full date separator for older days', (tester) async {
      final at = _daysAgo(5, 19, 0);
      final chat = _Chat()..messagesResult = [_msg('m1', mine: false, at: at)];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      final expected = DateFormat("EEEE d 'de' MMMM", 'es_PE').format(at);
      expect(find.text(expected), findsOneWidget);
      expect(expected, contains(' de '));
    });

    testWidgets('18 own unread message shows Enviado', (tester) async {
      final at = _today(20, 42);
      final chat = _Chat()..messagesResult = [_msg('m1', mine: true, at: at)];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      final time = DateFormat('h:mm a', 'es_PE').format(at);
      expect(find.text('$time \u00b7 Enviado'), findsOneWidget);
      expect(find.textContaining('Le\u00eddo'), findsNothing);
    });

    testWidgets('19 own read message shows Le\u00eddo', (tester) async {
      final at = _today(20, 42);
      final chat = _Chat()
        ..messagesResult = [_msg('m1', mine: true, at: at, read: true)];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      final time = DateFormat('h:mm a', 'es_PE').format(at);
      expect(find.text('$time \u00b7 Le\u00eddo'), findsOneWidget);
    });

    testWidgets('20 incoming messages never show Le\u00eddo', (tester) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, at: _today(20, 42), read: true),
        ];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      expect(find.textContaining('Le\u00eddo'), findsNothing);
      expect(find.textContaining('Enviado'), findsNothing);
    });

    testWidgets('21 same sender within 5 min groups (one meta)', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: true, at: _today(20, 40)),
          _msg('m2', mine: true, at: _today(20, 44)),
        ];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      expect(find.byKey(const Key('chat-meta-m1')), findsNothing);
      expect(find.byKey(const Key('chat-meta-m2')), findsOneWidget);
      expect(find.textContaining('Enviado'), findsOneWidget);
    });

    testWidgets('22 different senders do not group', (tester) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: false, at: _today(20, 40)),
          _msg('m2', mine: true, at: _today(20, 41)),
        ];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      expect(find.byKey(const Key('chat-meta-m1')), findsOneWidget);
      expect(find.byKey(const Key('chat-meta-m2')), findsOneWidget);
    });

    testWidgets('23 different local days do not group (across midnight)', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg('m1', mine: true, at: _daysAgo(1, 23, 58)),
          _msg('m2', mine: true, at: _today(0, 1)),
        ];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      expect(find.byKey(const Key('chat-meta-m1')), findsOneWidget);
      expect(find.byKey(const Key('chat-meta-m2')), findsOneWidget);
      expect(find.byKey(const Key('chat-day-separator')), findsNWidgets(2));
    });

    testWidgets('24 header tap opens the profile', (tester) async {
      final chat = _Chat()
        ..messagesResult = [_msg('m1', mine: false, at: _today(9, 0))];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      expect(find.text('Diego Ramos'), findsOneWidget);
      expect(find.text('@diegor'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-header-profile')));
      await _transition(tester);
      expect(find.text('PROFILE_u2'), findsOneWidget);
    });

    testWidgets('25 own media opens the shared GarraMediaViewer', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [
          _msg(
            'm1',
            mine: true,
            at: _today(9, 0),
            content: '',
            media: [_image('a1'), _image('a2')],
          ),
        ];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      expect(find.byKey(const Key('chat-media-image-0')), findsOneWidget);
      expect(find.byKey(const Key('chat-media-image-1')), findsOneWidget);
      expect(find.byKey(const Key('chat-meta-m1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-media-image-1')));
      await _transition(tester);
      expect(find.byKey(const ValueKey('garra_media_viewer')), findsOneWidget);
    });

    testWidgets('26 composer attaches images through the shared pipeline', (
      tester,
    ) async {
      final chat = _Chat()
        ..messagesResult = [_msg('m1', mine: false, at: _today(9, 0))];
      final media = _Media();
      await tester.pumpWidget(_conversationApp(chat, media: media));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('chat-attach-photo')));
      await _settle(tester);
      expect(media.picks, 1);
      expect(media.purposes, everyElement(MediaUploadPurpose.chatImage));
      expect(find.byKey(const Key('chat-image-preview-0')), findsOneWidget);
      expect(find.byKey(const Key('chat-image-preview-1')), findsOneWidget);

      await tester.tap(find.byTooltip('Enviar'));
      await _settle(tester);
      expect(chat.sentMedia.single, ['asset-photo-0.jpg', 'asset-photo-1.jpg']);
      expect(find.byKey(const Key('chat-image-preview-0')), findsNothing);
      expect(find.byKey(const Key('chat-media-image-1')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('27 counter only appears near the 1000 limit', (tester) async {
      final chat = _Chat()
        ..messagesResult = [_msg('m1', mine: false, at: _today(9, 0))];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      final composer = find.byKey(const Key('chat-composer'));
      expect(tester.widget<TextField>(composer).maxLength, 1000);
      await tester.enterText(composer, 'a' * 200);
      await tester.pump();
      expect(find.byKey(const Key('chat-composer-counter')), findsNothing);
      expect(find.text('0/1000'), findsNothing);

      await tester.enterText(composer, 'a' * 900);
      await tester.pump();
      expect(find.text('900/1000'), findsOneWidget);
    });

    testWidgets('28 new message while near the bottom scrolls to it', (
      tester,
    ) async {
      final chat = _Chat()..messagesResult = _longThread();
      await tester.pumpWidget(_conversationApp(chat, poll: _poll));
      await _settle(tester);
      final before = _position(tester);
      expect(before.pixels, closeTo(before.maxScrollExtent, 1));
      final oldMax = before.maxScrollExtent;

      chat.messagesResult = [
        ...chat.messagesResult,
        _msg('new', mine: false, at: _today(23, 59)),
      ];
      await _pollOnce(tester);

      final after = _position(tester);
      expect(after.maxScrollExtent, greaterThan(oldMax));
      expect(after.pixels, closeTo(after.maxScrollExtent, 1));
      expect(find.byKey(const Key('chat-new-messages-pill')), findsNothing);
      expect(chat.markReads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('29 new message while reading above does not jump', (
      tester,
    ) async {
      final chat = _Chat()..messagesResult = _longThread();
      await tester.pumpWidget(_conversationApp(chat, poll: _poll));
      await _settle(tester);
      _position(tester).jumpTo(0);
      await tester.pump();

      chat.messagesResult = [
        ...chat.messagesResult,
        _msg('new', mine: false, at: _today(23, 59)),
      ];
      await _pollOnce(tester);

      expect(_position(tester).pixels, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('30 Nuevos mensajes pill appears and scrolls to the end', (
      tester,
    ) async {
      final chat = _Chat()..messagesResult = _longThread();
      await tester.pumpWidget(_conversationApp(chat, poll: _poll));
      await _settle(tester);
      _position(tester).jumpTo(0);
      await tester.pump();

      chat.messagesResult = [
        ...chat.messagesResult,
        _msg('new', mine: false, at: _today(23, 59)),
      ];
      await _pollOnce(tester);

      final pill = find.byKey(const Key('chat-new-messages-pill'));
      expect(pill, findsOneWidget);
      expect(find.text('Nuevos mensajes \u2193'), findsOneWidget);
      await tester.tap(pill);
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);

      final position = _position(tester);
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));
      expect(pill, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('31 read-only update repaints receipts without scrolling', (
      tester,
    ) async {
      final chat = _Chat()..messagesResult = _longThread();
      await tester.pumpWidget(_conversationApp(chat, poll: _poll));
      await _settle(tester);
      _position(tester).jumpTo(200);
      await tester.pump();
      expect(find.textContaining('Le\u00eddo'), findsNothing);

      chat.messagesResult = [
        for (final m in chat.messagesResult) m.mine ? _copy(m, read: true) : m,
      ];
      await _pollOnce(tester);

      expect(_position(tester).pixels, 200);
      expect(find.textContaining('Le\u00eddo'), findsWidgets);
      expect(find.byKey(const Key('chat-new-messages-pill')), findsNothing);
      expect(chat.markReads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('32 PENDING keeps the composer blocked', (tester) async {
      final chat = _Chat()
        ..conversationResult = _conversation(status: 'PENDING', outgoing: true)
        ..messagesResult = [_msg('m1', mine: true, at: _today(9, 0))];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      final composer = tester.widget<TextField>(
        find.byKey(const Key('chat-composer')),
      );
      expect(composer.enabled, isFalse);
      expect(find.byKey(const Key('chat-attach-photo')), findsNothing);
      await tester.tap(find.byTooltip('Enviar'), warnIfMissed: false);
      await tester.pump();
      expect(chat.sent, isEmpty);

      final incoming = _Chat()
        ..conversationResult = _conversation(status: 'PENDING')
        ..messagesResult = [_msg('m1', mine: false, at: _today(9, 0))];
      await tester.pumpWidget(_conversationApp(incoming));
      await _settle(tester);
      expect(find.byKey(const Key('chat-composer')), findsNothing);
      expect(find.byKey(const Key('chat-accept-request')), findsOneWidget);
    });

    testWidgets('33 conversation uses Crema tokens', (tester) async {
      await _expectConversationTheme(
        tester,
        AppTheme.lightTheme,
        GarraSemanticColors.crema,
      );
    });

    testWidgets('34 conversation uses Noche tokens', (tester) async {
      await _expectConversationTheme(
        tester,
        AppTheme.darkTheme,
        GarraSemanticColors.noche,
      );
    });

    testWidgets('floating panel hands an ACTIVE thread to /chat/:id', (
      tester,
    ) async {
      final chat = _Chat()
        ..conversationResult = _conversation(
          context: 'MARKETPLACE',
          listingTitle: 'Camiseta retro 1971',
        );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: ConsultarPorChatButton(
                sellerUserId: 'u2',
                listingTitle: 'Camiseta retro 1971',
                chatService: chat,
              ),
            ),
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
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      );
      await tester.tap(find.byKey(const Key('marketplace-chat-cta')));
      await _transition(tester);
      expect(find.byKey(const Key('floating-chat-open-full')), findsNothing);

      await tester.tap(find.byKey(const Key('marketplace-chat-send')));
      await _transition(tester);
      expect(chat.markReads, 0);
      await tester.tap(find.byKey(const Key('floating-chat-open-full')));
      await _transition(tester);

      expect(find.byType(ChatConversationPage), findsOneWidget);
      expect(find.byKey(const Key('floating-chat-panel')), findsNothing);
      expect(chat.markReads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('marketplace header shows discreet listing context', (
      tester,
    ) async {
      final chat = _Chat()
        ..conversationResult = _conversation(
          context: 'MARKETPLACE',
          listingTitle: 'Camiseta retro 1971',
        )
        ..messagesResult = [_msg('m1', mine: false, at: _today(9, 0))];
      await tester.pumpWidget(_conversationApp(chat));
      await _settle(tester);

      expect(
        find.text('Marketplace \u00b7 Camiseta retro 1971'),
        findsOneWidget,
      );
      expect(find.textContaining('vendedor'), findsNothing);
    });
  });
}

const _poll = Duration(seconds: 1);

DateTime _today(int hour, int minute) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

DateTime _daysAgo(int days, int hour, int minute) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days, hour, minute);
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

ChatConversation _row({
  String id = 'c1',
  String name = 'Mar\u00eda Quispe',
  String? preview = 'Hola',
  DateTime? at,
  int unread = 0,
  String context = 'SOCIAL',
  String? listingTitle,
}) {
  return ChatConversation(
    id: id,
    otherUserId: 'u-$id',
    otherDisplayName: name,
    status: 'ACTIVE',
    lastMessagePreview: preview,
    lastMessageAt: at ?? _today(12, 0),
    unreadCount: unread,
    context: context,
    listingTitle: listingTitle,
  );
}

ChatConversation _conversation({
  String status = 'ACTIVE',
  bool outgoing = false,
  String context = 'SOCIAL',
  String? listingTitle,
}) {
  return ChatConversation(
    id: 'c1',
    otherUserId: 'u2',
    otherDisplayName: 'Diego Ramos',
    otherUsername: 'diegor',
    status: status,
    outgoing: outgoing,
    context: context,
    listingTitle: listingTitle,
  );
}

ChatMessage _msg(
  String id, {
  required bool mine,
  DateTime? at,
  bool read = false,
  String? content,
  List<ChatMediaItem> media = const [],
}) {
  return ChatMessage(
    id: id,
    conversationId: 'c1',
    senderId: mine ? 'me' : 'u2',
    content: content ?? 'Mensaje $id para coordinar la previa del partido',
    mine: mine,
    createdAt: at,
    read: read,
    media: media,
  );
}

ChatMessage _copy(ChatMessage m, {required bool read}) {
  return ChatMessage(
    id: m.id,
    conversationId: m.conversationId,
    senderId: m.senderId,
    content: m.content,
    mine: m.mine,
    createdAt: m.createdAt,
    media: m.media,
    read: read,
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

/// 30 alternating messages 10 minutes apart (each its own group).
List<ChatMessage> _longThread() {
  final start = _today(0, 0);
  return [
    for (var i = 0; i < 30; i++)
      _msg(
        'm$i',
        mine: i.isOdd,
        at: start.add(Duration(minutes: 10 * i)),
      ),
  ];
}

Widget _inboxApp(_Chat chat, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.darkTheme,
    home: ChatInboxPage(chatService: chat),
  );
}

Widget _conversationApp(
  _Chat chat, {
  ThemeData? theme,
  Duration poll = const Duration(minutes: 5),
  MediaUploadService? media,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => ChatConversationPage(
          conversationId: 'c1',
          chatService: chat,
          mediaService: media,
          pollInterval: poll,
        ),
      ),
      GoRoute(
        path: '/comunidad/u/:id',
        builder: (context, state) =>
            Scaffold(body: Text('PROFILE_${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(
    theme: theme ?? AppTheme.darkTheme,
    routerConfig: router,
  );
}

Future<void> _expectInboxTheme(
  WidgetTester tester,
  ThemeData theme,
  GarraSemanticColors expected,
) async {
  final chat = _Chat()
    ..conversationsResult = [_row(unread: 2, preview: 'Vamos la U')];
  await tester.pumpWidget(_inboxApp(chat, theme: theme));
  await _settle(tester);

  final colors = tester.element(find.byType(ChatInboxPage)).garraColors;
  expect(colors.background, expected.background);
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
  expect(scaffold.backgroundColor, expected.background);
  final badge = tester.widget<Container>(
    find.byKey(const Key('chat-unread-badge')),
  );
  expect((badge.decoration! as BoxDecoration).color, expected.brandPrimary);
  final preview = tester.widget<Text>(find.text('Vamos la U'));
  expect(preview.style?.color, expected.textPrimary);
}

Future<void> _expectConversationTheme(
  WidgetTester tester,
  ThemeData theme,
  GarraSemanticColors expected,
) async {
  final chat = _Chat()
    ..messagesResult = [
      _msg('m1', mine: false, at: _today(9, 0)),
      _msg('m2', mine: true, at: _today(9, 30)),
    ];
  await tester.pumpWidget(_conversationApp(chat, theme: theme));
  await _settle(tester);

  BoxDecoration bubble(String key) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  expect(bubble('chat-bubble-mine').color, expected.brandPrimary);
  expect(bubble('chat-bubble-other').color, expected.surfaceRaised);
  expect(
    tester.widget<Align>(find.byKey(const Key('chat-bubble-mine'))).alignment,
    Alignment.centerRight,
  );
  expect(find.byKey(const Key('chat-backdrop')), findsOneWidget);
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
  expect(scaffold.backgroundColor, expected.background);
  final text = tester.widget<Text>(find.text(_msg('m2', mine: true).content));
  expect(text.style?.color, expected.onBrand);
}

class _Chat extends ChatService {
  _Chat() : super(dio: Dio());

  List<ChatConversation> conversationsResult = const [];
  List<ChatConversation> requestsResult = const [];
  ChatConversation? conversationResult;
  List<ChatMessage> messagesResult = const [];
  int unread = 0;
  int unreadCalls = 0;
  int markReads = 0;
  int conversationsCalls = 0;
  String? acceptedId;
  final List<String> sent = [];
  final List<List<String>> sentMedia = [];

  @override
  Future<ChatRelationship> relationship(
    String userId, {
    String context = 'SOCIAL',
  }) async => ChatRelationship.none();

  @override
  Future<List<ChatConversation>> conversations() async {
    conversationsCalls += 1;
    return conversationsResult;
  }

  @override
  Future<List<ChatConversation>> incoming() async => requestsResult;

  @override
  Future<ChatConversation> openMarketplace({
    required String recipientUserId,
    required String content,
    String? listingTitle,
    String? listingPrice,
  }) async {
    sent.add(content);
    return _conversation(context: 'MARKETPLACE', listingTitle: listingTitle);
  }

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
  Future<int> unreadCount() async {
    unreadCalls += 1;
    return unread;
  }

  @override
  Future<ChatConversation> accept(String conversationId) async {
    acceptedId = conversationId;
    final request = requestsResult.firstWhere((r) => r.id == conversationId);
    final active = ChatConversation(
      id: request.id,
      otherUserId: request.otherUserId,
      otherDisplayName: request.otherDisplayName,
      status: 'ACTIVE',
      lastMessagePreview: request.lastMessagePreview,
      lastMessageAt: request.lastMessageAt,
    );
    requestsResult = const [];
    conversationsResult = [...conversationsResult, active];
    return active;
  }

  @override
  Future<ChatMessage> send(
    String conversationId,
    String content, {
    List<String> mediaAssetIds = const [],
  }) async {
    sent.add(content);
    sentMedia.add(mediaAssetIds);
    final message = ChatMessage(
      id: 'sent-${sent.length}',
      conversationId: conversationId,
      senderId: 'me',
      content: content,
      mine: true,
      createdAt: DateTime.now(),
      media: [for (final id in mediaAssetIds) _image(id)],
    );
    messagesResult = [...messagesResult, message];
    return message;
  }
}

class _Media extends MediaUploadService {
  _Media() : super(dio: Dio(), binaryClient: Dio());

  int picks = 0;
  final List<MediaUploadPurpose> purposes = [];

  @override
  Future<List<XFile>> pickMultiImage({int max = 4}) async {
    picks += 1;
    return [for (var i = 0; i < math.min(2, max); i++) XFile('photo-$i.jpg')];
  }

  @override
  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
  }) async {
    purposes.add(purpose);
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

class _Community extends CommunityService {
  _Community() : super(dio: Dio());

  @override
  Future<Map<String, dynamic>> getPublicProfile(String userId) async => {
    'displayName': 'T\u00fa',
    'username': 'yo',
    'followerCount': 4,
    'followingCount': 2,
    'globalPostCount': 0,
    'isFollowedByMe': false,
    'isBlockedByMe': false,
    'isMe': true,
    'globalPosts': <dynamic>[],
  };

  @override
  Future<bool> registerProfileView(String userId) async => false;
}
