import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
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

Future<void> _settle(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

class _ReplyUiChat extends FootballChatService {
  _ReplyUiChat() : super(dio: Dio());

  Map<String, dynamic>? lastSend;

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
    return FootballChatPage(
      items: [
        FootballChatMessage(
          id: 'target-1',
          authorId: 'fan-other',
          authorName: 'Hincha',
          authorUsername: 'h',
          body: 'arenga original',
          createdAt: DateTime.utc(2026, 10, 10, 20),
        ),
        FootballChatMessage(
          id: 'reply-1',
          authorId: 'fan-other',
          authorName: 'Hincha',
          authorUsername: 'h',
          body: 'citando',
          createdAt: DateTime.utc(2026, 10, 10, 20, 1),
          replyTo: const FootballChatReplyPreview(
            id: 'target-1',
            authorId: 'fan-other',
            authorName: 'Hincha',
            preview: 'arenga original',
          ),
        ),
      ],
      hasMore: false,
    );
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
      'context': context.key,
    };
    return FootballChatMessage(
      id: 'sent-1',
      authorId: 'fan-me',
      authorName: 'Yo',
      authorUsername: 'me',
      body: body,
      createdAt: DateTime.utc(2026, 10, 10, 21),
      replyTo: replyToMessageId == null
          ? null
          : const FootballChatReplyPreview(
              id: 'target-1',
              authorId: 'fan-other',
              authorName: 'Hincha',
              preview: 'arenga original',
            ),
    );
  }
}

void main() {
  test('FootballChatMessage parses replyTo from API envelope', () {
    final parsed = FootballChatMessage.fromJson({
      'id': 'm1',
      'authorId': 'a',
      'authorName': 'Hincha',
      'authorUsername': 'h',
      'body': 'respuesta',
      'createdAt': '2026-10-10T20:00:00Z',
      'replyTo': {
        'id': 'm0',
        'authorId': 'b',
        'authorName': 'Otro',
        'preview': 'arenga',
        'unavailable': false,
      },
    });
    expect(parsed.replyTo?.preview, 'arenga');
    expect(parsed.replyTo?.unavailable, isFalse);
  });

  test('send includes replyToMessageId in POST body', () async {
    RequestOptions? captured;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        captured = options;
        handler.resolve(Response(
          requestOptions: options,
          data: {
            'data': {
              'id': 'srv-1',
              'authorId': 'me',
              'authorName': 'Yo',
              'authorUsername': 'yo',
              'body': 'resp',
              'createdAt': '2026-10-06T20:00:00Z',
            },
          },
        ));
      },
    ));
    final service = FootballChatService(dio: dio);
    await service.send(
      'resp',
      clientMessageId: 'client-uuid-1',
      replyToMessageId: 'target-uuid',
    );
    expect(captured?.data['replyToMessageId'], 'target-uuid');
    expect(captured?.data['clientMessageId'], 'client-uuid-1');
  });

  testWidgets('reply menu, composer preview, send and quote render', (tester) async {
    final chat = _ReplyUiChat();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          footballChatServiceProvider.overrideWithValue(chat),
          connectivityStatusProvider.overrideWith(_Net.new),
          currentFanProvider.overrideWith(_FanNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MainShellBranchScope(
              activeBranch: 1,
              child: const FootballChatRoomView(
                surface: FootballChatSurface.community,
              ),
            ),
          ),
        ),
      ),
    );
    await _settle(tester, 14);
    expect(find.byKey(const ValueKey('chat_quote_target-1')), findsOneWidget);
    expect(find.text('arenga original'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('chat_msg_menu_target-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat_action_reply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat_reply_composer')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat_reply_composer')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chat_msg_menu_target-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat_action_reply')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat_input')), 'mi respuesta');
    await tester.tap(find.byKey(const ValueKey('chat_send')));
    await _settle(tester, 8);
    expect(chat.lastSend?['replyToMessageId'], 'target-1');
    expect(chat.lastSend?['body'], 'mi respuesta');
    expect(chat.lastSend?['clientMessageId'], isNotEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
