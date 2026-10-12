import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/community/data/reaction_type.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/data/football_chat_sync.dart';
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

Future<void> _settle(WidgetTester tester, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  test('FootballChatMessage parses reactions when present', () {
    final m = FootballChatMessage.fromJson({
      'id': 'm1',
      'authorId': 'a',
      'authorName': 'H',
      'authorUsername': 'h',
      'body': 'hola',
      'createdAt': '2026-10-10T20:00:00Z',
      'reactions': [
        {'type': 'LIKE', 'count': 2, 'reactedByMe': true},
        {'type': 'FIRE', 'count': 1, 'reactedByMe': false},
      ],
    });
    expect(m.reactions, hasLength(2));
    expect(m.reactionSignature, contains('LIKE:2:1'));
  });

  test('FootballChatMessage tolerates missing reactions (older backend)', () {
    final m = FootballChatMessage.fromJson({
      'id': 'm1',
      'authorId': 'a',
      'authorName': 'H',
      'authorUsername': 'h',
      'body': 'hola',
    });
    expect(m.reactions, isEmpty);
  });

  test('polling merge replaces reactions without duplicating counts', () {
    const local = [
      FootballChatMessage(
        id: 'm1',
        authorId: 'a',
        authorName: 'H',
        authorUsername: 'h',
        body: 'hola',
        createdAt: null,
        reactions: [
          ChatMessageReactionSummary(type: 'LIKE', count: 1, reactedByMe: true),
        ],
      ),
    ];
    const server = [
      FootballChatMessage(
        id: 'm1',
        authorId: 'a',
        authorName: 'H',
        authorUsername: 'h',
        body: 'hola',
        createdAt: null,
        reactions: [
          ChatMessageReactionSummary(type: 'LIKE', count: 3, reactedByMe: true),
          ChatMessageReactionSummary(type: 'LOVE', count: 1, reactedByMe: false),
        ],
      ),
    ];
    final merged = footballChatSortedUnique([
      ...reconcileFootballChatRecentWindow(local: local, serverWindow: server),
      ...server,
    ]);
    expect(merged, hasLength(1));
    expect(merged.first.reactions.firstWhere((r) => r.type == 'LIKE').count, 3);
    expect(merged.first.reactions, hasLength(2));
  });

  testWidgets('chips render and reaction PUT is sent', (tester) async {
    final chat = _ReactionUiChat();
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
              child: const FootballChatRoomView(surface: FootballChatSurface.community),
            ),
          ),
        ),
      ),
    );
    await _settle(tester, 20);
    expect(find.byKey(const Key('football-chat-reaction-tap-msg-1-LIKE')), findsOneWidget);
    await tester.tap(find.byKey(const Key('football-chat-reaction-tap-msg-1-LIKE')));
    await _settle(tester, 8);
    expect(chat.lastReactType, ReactionType.like);
  });
}

class _ReactionUiChat extends FootballChatService {
  _ReactionUiChat() : super(dio: Dio());

  ReactionType? lastReactType;

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
          id: 'msg-1',
          authorId: 'fan-other',
          authorName: 'Hincha',
          authorUsername: 'h',
          body: 'vamos',
          createdAt: DateTime.utc(2026, 10, 10, 20),
          reactions: const [
            ChatMessageReactionSummary(type: 'LIKE', count: 2, reactedByMe: false),
          ],
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<FootballChatReactionsResult> reactToMessage(
    String messageId,
    ReactionType type,
  ) async {
    lastReactType = type;
    return FootballChatReactionsResult(
      messageId: messageId,
      reactions: [
        ChatMessageReactionSummary(
          type: type.apiValue,
          count: 3,
          reactedByMe: true,
        ),
      ],
      myReaction: type.apiValue,
    );
  }
}
