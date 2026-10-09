import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/presentation/community_social_page.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/presentation/chat_futbolero_page.dart';
import 'package:garra_digital_app/features/football/presentation/football_chat_room_view.dart';

class _Net extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

FootballChatMessage _msg(String id, int minute, String body) => FootballChatMessage(
      id: id,
      authorId: 'a-$id',
      authorName: 'Hincha',
      authorUsername: 'h$id',
      body: body,
      createdAt: DateTime.utc(2026, 10, 6, 20, minute),
    );

class _PagingChat extends FootballChatService {
  _PagingChat() : super(dio: Dio());

  final List<String> calls = [];
  int failHistoryOnce = 0;
  Completer<void>? historyGate;
  Completer<void>? refreshGate;

  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    calls.add(
        '${context.key}:${before?.toIso8601String() ?? 'latest'}:${beforeId ?? ''}');
    if (before == null && refreshGate != null) {
      await refreshGate!.future;
    }
    if (before != null && historyGate != null) {
      await historyGate!.future;
    }
    if (before == null) {
      return FootballChatPage(
        items: [_msg('4', 40, 'm4'), _msg('5', 50, 'm5')],
        hasMore: true,
      );
    }
    if (failHistoryOnce > 0) {
      failHistoryOnce--;
      throw DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 500,
        ),
      );
    }
    final t = before.toUtc();
    if (t == DateTime.utc(2026, 10, 6, 20, 40)) {
      return FootballChatPage(
        items: [_msg('2', 20, 'm2'), _msg('3', 30, 'm3')],
        hasMore: true,
      );
    }
    if (t == DateTime.utc(2026, 10, 6, 20, 20)) {
      return FootballChatPage(items: [_msg('1', 10, 'm1')], hasMore: false);
    }
    return const FootballChatPage(items: [], hasMore: false);
  }
}

class _PollChat extends FootballChatService {
  _PollChat() : super(dio: Dio());
  int pollCount = 0;

  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    if (before != null) {
      return const FootballChatPage(items: [], hasMore: false);
    }
    pollCount++;
    if (pollCount == 1) {
      return FootballChatPage(
        items: [for (var i = 1; i <= 24; i++) _msg('a$i', i, 'msg$i')],
        hasMore: false,
      );
    }
    return FootballChatPage(
      items: [
        for (var i = 1; i <= 24; i++) _msg('a$i', i, 'msg$i'),
        _msg('b', 25, 'nuevo'),
      ],
      hasMore: false,
    );
  }
}

Future<void> _settle(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

AuthUser _fan(String id) => AuthUser(
      userId: id,
      email: '$id@test.local',
      username: id,
      fullName: id,
      status: 'ACTIVE',
    );

class _FanNotifier extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

void main() {
  group('PRODUCT-03B-2 historial y nuevos mensajes', () {
    testWidgets('primera página y segunda con before', (tester) async {
      final chat = _PagingChat();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          footballChatServiceProvider.overrideWithValue(chat),
          connectivityStatusProvider.overrideWith(_Net.new),
        ],
        child: MaterialApp(
          home: MainShellBranchScope(
            activeBranch: 1,
            child: const CommunitySocialPage(),
          ),
        ),
      ));
      await _settle(tester);
      expect(find.text('m4'), findsOneWidget);
      expect(find.text('m5'), findsOneWidget);
      expect(chat.calls.first, 'GENERAL:latest:');

      await tester.drag(find.byKey(const ValueKey('chat_list')), const Offset(0, 400));
      await _settle(tester, 12);
      expect(chat.calls.any((c) => c.startsWith('GENERAL:2026')), isTrue);
      expect(find.text('m2'), findsOneWidget);

      await tester.drag(find.byKey(const ValueKey('chat_list')), const Offset(0, 400));
      await _settle(tester, 12);
      expect(find.text('m1'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_history_end')), findsOneWidget);
    });

    testWidgets('hasMore false muestra fin de historial', (tester) async {
      final chat = _PagingChat();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          footballChatServiceProvider.overrideWithValue(chat),
          connectivityStatusProvider.overrideWith(_Net.new),
        ],
        child: MaterialApp(
          home: MainShellBranchScope(
            activeBranch: 1,
            child: const CommunitySocialPage(),
          ),
        ),
      ));
      await _settle(tester);
      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byKey(const ValueKey('chat_list')), const Offset(0, 500));
        await _settle(tester, 12);
      }
      expect(find.byKey(const ValueKey('chat_history_end')), findsOneWidget);
    });

    testWidgets('fallo de historial y reintento', (tester) async {
      final chat = _PagingChat()..failHistoryOnce = 99;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          footballChatServiceProvider.overrideWithValue(chat),
          connectivityStatusProvider.overrideWith(_Net.new),
        ],
        child: MaterialApp(
          home: MainShellBranchScope(
            activeBranch: 1,
            child: const CommunitySocialPage(),
          ),
        ),
      ));
      await _settle(tester);
      for (var i = 0; i < 2; i++) {
        await tester.drag(find.byKey(const ValueKey('chat_list')), const Offset(0, 500));
        await _settle(tester, 10);
      }
      await _settle(tester, 12);
      expect(find.text('No pudimos cargar mensajes anteriores'), findsOneWidget);
      chat.failHistoryOnce = 0;
      await tester.tap(find.text('No pudimos cargar mensajes anteriores'));
      await _settle(tester, 12);
      expect(find.text('m2'), findsOneWidget);
    });

    testWidgets('polling al final no muestra aviso', (tester) async {
      final chat = _PollChat();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          footballChatServiceProvider.overrideWithValue(chat),
          connectivityStatusProvider.overrideWith(_Net.new),
        ],
        child: MaterialApp(
          home: MainShellBranchScope(
            activeBranch: 1,
            child: const CommunitySocialPage(),
          ),
        ),
      ));
      await _settle(tester);
      await tester.pump(FootballChatRoomView.pollEvery);
      await _settle(tester);
      expect(find.text('nuevo'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_new_messages_banner')), findsNothing);
    });

    testWidgets('polling leyendo arriba muestra Nuevos mensajes', (tester) async {
      final chat = _PollChat();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          footballChatServiceProvider.overrideWithValue(chat),
          connectivityStatusProvider.overrideWith(_Net.new),
        ],
        child: MaterialApp(
          home: MainShellBranchScope(
            activeBranch: 1,
            child: const CommunitySocialPage(),
          ),
        ),
      ));
      await _settle(tester);
      await tester.fling(find.byKey(const ValueKey('chat_list')), const Offset(0, 800), 2000);
      await _settle(tester, 16);
      await tester.pump(FootballChatRoomView.pollEvery);
      await _settle(tester, 12);
      expect(find.byKey(const ValueKey('chat_new_messages_banner')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat_new_messages_banner')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('chat_new_messages_banner')), findsNothing);
    });

    testWidgets('MATCH aislado de GENERAL', (tester) async {
      final chat = _PagingChat();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            footballChatServiceProvider.overrideWithValue(chat),
            connectivityStatusProvider.overrideWith(_Net.new),
          ],
          child: MaterialApp(
            home: MainShellBranchScope(
              activeBranch: 2,
              child: const ChatFutboleroPage(matchId: 99),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(chat.calls.first, 'MATCH:99:latest:');
      expect(find.text('m4'), findsOneWidget);
    });

    testWidgets('respuesta tardía no pisa generación nueva', (tester) async {
      final chat = _PagingChat()..refreshGate = Completer<void>();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          footballChatServiceProvider.overrideWithValue(chat),
          connectivityStatusProvider.overrideWith(_Net.new),
        ],
        child: MaterialApp(
          home: MainShellBranchScope(
            activeBranch: 1,
            child: const CommunitySocialPage(),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      chat.refreshGate!.complete();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('cambio de usuario limpia mensajes visibles', (tester) async {
      final chat = _PagingChat();
      final container = ProviderContainer(overrides: [
        footballChatServiceProvider.overrideWithValue(chat),
        connectivityStatusProvider.overrideWith(_Net.new),
        currentFanProvider.overrideWith(_FanNotifier.new),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MainShellBranchScope(
              activeBranch: 1,
              child: const CommunitySocialPage(),
            ),
          ),
        ),
      );
      container.read(currentFanProvider.notifier).state = AsyncData(_fan('user-a'));
      await _settle(tester);
      expect(find.text('m5'), findsOneWidget);

      final loadsBefore = chat.calls.where((c) => c.contains(':latest:')).length;
      container.read(currentFanProvider.notifier).state = AsyncData(_fan('user-b'));
      await tester.pump();
      await _settle(tester, 12);
      expect(
        chat.calls.where((c) => c.contains(':latest:')).length,
        greaterThan(loadsBefore),
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}
