import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/community/presentation/community_social_page.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/presentation/chat_futbolero_page.dart';
import 'package:garra_digital_app/features/football/presentation/football_chat_room_view.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';

class _Net extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

class _OfflineNet extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.offline;
}

DioException _http(int status) {
  final options = RequestOptions(path: '/football/chat/messages');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status),
  );
}

class _Chat extends FootballChatService {
  _Chat() : super(dio: Dio());
  final List<String> pageCalls = [];
  final List<String> sends = [];

  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    pageCalls.add(context.key);
    return FootballChatPage(
      items: context.isMatch
          ? [
              FootballChatMessage(
                id: 'm1',
                authorId: 'a',
                authorName: 'Hincha',
                authorUsername: 'h',
                body: 'Gol',
                createdAt: DateTime.utc(2026, 10, 6, 20, 10),
                contextType: 'MATCH',
                contextId: '${context.matchId}',
              )
            ]
          : [
              FootballChatMessage(
                id: 'g1',
                authorId: 'b',
                authorName: 'Crema',
                authorUsername: 'c',
                body: 'Arriba U',
                createdAt: DateTime.utc(2026, 10, 6, 20, 5),
              ),
            ],
      hasMore: false,
    );
  }

  @override
  Future<FootballChatMessage> send(String body,
      {FootballChatContext context = const FootballChatContext.general(),
      String? clientMessageId}) async {
    sends.add(context.key);
    return FootballChatMessage(
      id: 'sent-${sends.length}',
      authorId: 'me',
      authorName: 'Yo',
      authorUsername: 'yo',
      body: body,
      createdAt: DateTime.utc(2026, 10, 6, 21, 0),
      contextType: context.isMatch ? 'MATCH' : 'GENERAL',
      contextId: context.matchId?.toString(),
    );
  }
}

class _FailOnceChat extends FootballChatService {
  _FailOnceChat() : super(dio: Dio());
  var fail = true;

  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    if (fail) {
      fail = false;
      throw _http(500);
    }
    return const FootballChatPage(items: [], hasMore: false);
  }
}

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Widget _withBranch(int branch, Widget child) {
  return MainShellBranchScope(activeBranch: branch, child: child);
}

void main() {
  group('PRODUCT-03B-1 Comunidad Crema', () {
    testWidgets('CommunitySocialPage loads GENERAL chat', (tester) async {
      final chat = _Chat();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            footballChatServiceProvider.overrideWithValue(chat),
            connectivityStatusProvider.overrideWith(_Net.new),
          ],
          child: MaterialApp(
            home: _withBranch(1, const CommunitySocialPage()),
          ),
        ),
      );
      await _settle(tester);
      expect(chat.pageCalls, ['GENERAL']);
      expect(find.text('Comunidad Crema'), findsOneWidget);
      expect(find.text('Arriba U'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_input')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('send from Comunidad uses GENERAL context', (tester) async {
      final chat = _Chat();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            footballChatServiceProvider.overrideWithValue(chat),
            connectivityStatusProvider.overrideWith(_Net.new),
          ],
          child: MaterialApp(
            home: _withBranch(1, const CommunitySocialPage()),
          ),
        ),
      );
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('chat_input')), 'Hola crema');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await _settle(tester);
      expect(chat.sends, ['GENERAL']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('MATCH room stays separate from GENERAL', (tester) async {
      final chat = _Chat();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            footballChatServiceProvider.overrideWithValue(chat),
            connectivityStatusProvider.overrideWith(_Net.new),
          ],
          child: MaterialApp(
            home: _withBranch(
              2,
              const ChatFutboleroPage(matchId: 42),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(chat.pageCalls, ['MATCH:42']);
      expect(find.text('Gol'), findsOneWidget);
      expect(find.text('Arriba U'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Home feed widget still uses social modes', (tester) async {
      expect(const SocialFeedTab(mode: 'FOR_YOU').mode, 'FOR_YOU');
      expect(const SocialFeedTab(mode: 'FOLLOWING').mode, 'FOLLOWING');
    });

    testWidgets('GENERAL chat pauses polling when shell branch is not Comunidad',
        (tester) async {
      final chat = _Chat();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            footballChatServiceProvider.overrideWithValue(chat),
            connectivityStatusProvider.overrideWith(_Net.new),
          ],
          child: MaterialApp(
            home: _withBranch(1, const CommunitySocialPage()),
          ),
        ),
      );
      await _settle(tester);
      expect(chat.pageCalls, ['GENERAL']);
      chat.pageCalls.clear();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            footballChatServiceProvider.overrideWithValue(chat),
            connectivityStatusProvider.overrideWith(_Net.new),
          ],
          child: MaterialApp(
            home: _withBranch(0, const CommunitySocialPage()),
          ),
        ),
      );
      await _settle(tester);
      chat.pageCalls.clear();
      await tester.pump(FootballChatRoomView.pollEvery);
      await tester.pump(FootballChatRoomView.pollEvery);
      expect(chat.pageCalls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('offline initial load shows error and disabled composer', (tester) async {
      final chat = _Chat();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            footballChatServiceProvider.overrideWithValue(chat),
            connectivityStatusProvider.overrideWith(_OfflineNet.new),
          ],
          child: MaterialApp(
            home: _withBranch(1, const CommunitySocialPage()),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('chat_error')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_composer_disabled')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('backend failure shows retry affordance', (tester) async {
      final chat = _FailOnceChat();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            footballChatServiceProvider.overrideWithValue(chat),
            connectivityStatusProvider.overrideWith(_Net.new),
          ],
          child: MaterialApp(
            home: _withBranch(1, const CommunitySocialPage()),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('chat_error')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_retry')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
