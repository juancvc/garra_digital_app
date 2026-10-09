import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/data/football_chat_sync.dart';
import 'package:garra_digital_app/features/community/presentation/community_social_page.dart';
import 'package:garra_digital_app/features/community/data/community_report.dart';
import 'package:garra_digital_app/features/football/presentation/football_chat_room_view.dart';

FootballChatMessage _msg(String id, DateTime at, String body,
        {String authorId = 'author-1'}) =>
    FootballChatMessage(
      id: id,
      authorId: authorId,
      authorName: 'Hincha',
      authorUsername: 'h',
      body: body,
      createdAt: at,
    );

void main() {
  group('footballChatSync', () {
    final tie = DateTime.utc(2026, 10, 6, 20, 30);

    test('reconcile removes moderated message in recent window only', () {
      final local = [
        _msg('old', DateTime.utc(2026, 10, 6, 20, 10), 'history'),
        _msg('a', tie, 'visible'),
        _msg('gone', tie.add(const Duration(seconds: 1)), 'moderated'),
      ];
      final window = [
        _msg('a', tie, 'visible'),
        _msg('b', tie.add(const Duration(seconds: 2)), 'new'),
      ];
      final reconciled =
          reconcileFootballChatRecentWindow(local: local, serverWindow: window);
      final out = footballChatSortedUnique([...reconciled, ...window]);
      expect(out.map((m) => m.id).toList(), ['old', 'a', 'b']);
      expect(out.any((m) => m.id == 'gone'), isFalse);
    });

    test('same createdAt uses id tie-break for window boundary', () {
      expect(
        footballChatIsSameOrNewer(_msg('b', tie, 'x'), tie, 'a'),
        isTrue,
      );
      expect(
        footballChatIsSameOrNewer(_msg('a', tie, 'x'), tie, 'b'),
        isFalse,
      );
    });

    test('empty server window leaves local list unchanged', () {
      final local = [_msg('a', tie, 'keep')];
      expect(
        reconcileFootballChatRecentWindow(local: local, serverWindow: const []),
        local,
      );
    });

    test('deep history is never dropped when absent from poll window', () {
      final anchor = tie;
      final local = [
        _msg('deep', anchor.subtract(const Duration(hours: 2)), 'archived'),
        _msg('recent', anchor, 'still here'),
        _msg('moderated', anchor.add(const Duration(seconds: 1)), 'gone'),
      ];
      final window = [
        _msg('recent', anchor, 'still here'),
        _msg('new', anchor.add(const Duration(seconds: 2)), 'fresh'),
      ];
      final reconciled =
          reconcileFootballChatRecentWindow(local: local, serverWindow: window);
      expect(reconciled.map((m) => m.id), containsAll(['deep', 'recent']));
      expect(reconciled.any((m) => m.id == 'moderated'), isFalse);
      expect(reconciled.any((m) => m.id == 'new'), isFalse);
    });
  });

  group('FootballChatService query params', () {
    test('page sends before and beforeId together', () async {
      RequestOptions? captured;
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(Response(
            requestOptions: options,
            data: const {
              'data': {'items': [], 'hasMore': false},
            },
          ));
        },
      ));
      final service = FootballChatService(dio: dio);
      final at = DateTime.utc(2026, 10, 6, 20, 40);
      await service.page(
        const FootballChatContext.general(),
        before: at,
        beforeId: 'uuid-oldest',
      );
      expect(captured?.path, '/football/chat/messages');
      expect(captured?.queryParameters['before'], isNotNull);
      expect(captured?.queryParameters['beforeId'], 'uuid-oldest');
    });

    test('send includes clientMessageId', () async {
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
                'body': 'hola',
                'createdAt': '2026-10-06T20:00:00Z',
              },
            },
          ));
        },
      ));
      final service = FootballChatService(dio: dio);
      await service.send('hola', clientMessageId: 'client-uuid-1');
      expect(captured?.data['clientMessageId'], 'client-uuid-1');
    });

    test('page rejects beforeId without before', () {
      final service = FootballChatService(dio: Dio());
      expect(
        () => service.page(
          const FootballChatContext.general(),
          beforeId: 'only-id',
        ),
        throwsArgumentError,
      );
    });
  });

  group('FootballChatRoomView integration', () {
    testWidgets('history request includes beforeId for tied timestamps',
        (tester) async {
      final chat = _StablePagingChat();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            footballChatServiceProvider.overrideWithValue(chat),
            connectivityStatusProvider.overrideWith(_Net.new),
            currentFanProvider.overrideWith(_FanNotifier.new),
          ],
          child: MaterialApp(
            home: MainShellBranchScope(
              activeBranch: 1,
              child: const CommunitySocialPage(),
            ),
          ),
        ),
      );
      await _settle(tester, 16);
      await tester.drag(find.byKey(const ValueKey('chat_list')), const Offset(0, 500));
      await _settle(tester, 16);
      expect(
        chat.calls.any((c) => c.contains('beforeId:mid')),
        isTrue,
      );
    });

    testWidgets('polling drops message removed from server window',
        (tester) async {
      final chat = _ModerationPollChat();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            footballChatServiceProvider.overrideWithValue(chat),
            connectivityStatusProvider.overrideWith(_Net.new),
            currentFanProvider.overrideWith(_FanNotifier.new),
          ],
          child: MaterialApp(
            home: MainShellBranchScope(
              activeBranch: 1,
              child: const CommunitySocialPage(),
            ),
          ),
        ),
      );
      await _settle(tester, 24);
      expect(find.byKey(const ValueKey('chat_list')), findsOneWidget);
      expect(find.text('visible'), findsOneWidget);
      expect(find.text('gone'), findsOneWidget);
      await tester.pump(FootballChatRoomView.pollEvery);
      await _settle(tester, 12);
      expect(find.text('visible'), findsOneWidget);
      expect(find.text('gone'), findsNothing);
    });

    testWidgets('menu opens report for another users message',
        (tester) async {
      final chat = _AuthorshipChat();
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await _openMessageMenu(tester, 'other-msg');
      expect(find.byKey(const ValueKey('chat_action_report')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_action_delete')), findsNothing);
    });

    testWidgets('menu opens delete for own message', (tester) async {
      final chat = _AuthorshipChat();
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await _openMessageMenu(tester, 'own-msg');
      expect(find.byKey(const ValueKey('chat_action_delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_action_report')), findsNothing);
    });

    testWidgets('long press still opens message actions', (tester) async {
      final chat = _AuthorshipChat();
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      final target = find.text('their line');
      await tester.ensureVisible(target);
      await _settle(tester, 4);
      await tester.longPress(target);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat_action_report')), findsOneWidget);
    });

    testWidgets('report success shows thanks snackbar', (tester) async {
      final chat = _ModerationActionsChat();
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await _openMessageMenu(tester, 'other-msg');
      await tester.tap(find.byKey(const ValueKey('chat_action_report')));
      await tester.pumpAndSettle();
      await _pickReportReason(tester, 'Spam');
      await _submitFootballReport(tester);
      expect(chat.reportCalls, hasLength(1));
      expect(chat.reportCalls.single.messageId, 'other-msg');
      expect(find.text(garraReportThanksMessage), findsOneWidget);
    });

    testWidgets('report duplicate HTTP 400 shows sheet error', (tester) async {
      final chat = _ModerationActionsChat()
        ..reportResult =
            ReportSubmitResult.failure('Ya denunciaste este mensaje.');
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await _openMessageMenu(tester, 'other-msg');
      await tester.tap(find.byKey(const ValueKey('chat_action_report')));
      await tester.pumpAndSettle();
      await _pickReportReason(tester, 'Spam');
      await _submitFootballReport(tester);
      expect(find.text('Ya denunciaste este mensaje.'), findsOneWidget);
      expect(find.text(garraReportThanksMessage), findsNothing);
    });

    testWidgets('report rate limit HTTP 429 shows sheet error', (tester) async {
      final chat = _ModerationActionsChat()
        ..reportResult = ReportSubmitResult.failure(
          'Demasiadas denuncias. Espera un momento.',
        );
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await _openMessageMenu(tester, 'other-msg');
      await tester.tap(find.byKey(const ValueKey('chat_action_report')));
      await tester.pumpAndSettle();
      await _pickReportReason(tester, 'Otro');
      await _submitFootballReport(tester);
      expect(
        find.text('Demasiadas denuncias. Espera un momento.'),
        findsOneWidget,
      );
    });

    testWidgets('delete confirmed removes message from list', (tester) async {
      final chat = _ModerationActionsChat();
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      expect(find.text('my post'), findsOneWidget);
      await _openMessageMenu(tester, 'own-msg');
      await tester.tap(find.byKey(const ValueKey('chat_action_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await _settle(tester, 12);
      expect(chat.deleteCalls, ['own-msg']);
      expect(find.text('my post'), findsNothing);
    });

    testWidgets('delete cancelled keeps message', (tester) async {
      final chat = _ModerationActionsChat();
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await _openMessageMenu(tester, 'own-msg');
      await tester.tap(find.byKey(const ValueKey('chat_action_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await _settle(tester, 8);
      expect(chat.deleteCalls, isEmpty);
      expect(find.text('my post'), findsOneWidget);
    });

    testWidgets('delete HTTP 403 shows snackbar', (tester) async {
      final chat = _ModerationActionsChat()
        ..deleteResult = ReportSubmitResult.failure('No puedes eliminar esto.');
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await _openMessageMenu(tester, 'own-msg');
      await tester.tap(find.byKey(const ValueKey('chat_action_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await _settle(tester, 12);
      expect(find.text('No puedes eliminar esto.'), findsOneWidget);
      expect(find.text('my post'), findsOneWidget);
    });

    testWidgets('delete HTTP 404 shows snackbar', (tester) async {
      final chat = _ModerationActionsChat()
        ..deleteResult =
            ReportSubmitResult.failure('El mensaje ya no está disponible.');
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await _openMessageMenu(tester, 'own-msg');
      await tester.tap(find.byKey(const ValueKey('chat_action_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await _settle(tester, 12);
      expect(find.text('El mensaje ya no está disponible.'), findsOneWidget);
    });

    testWidgets('send HTTP 409 retry reuses clientMessageId', (tester) async {
      final chat = _IdempotentSendChat();
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('chat_input')), 'Once');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await _settle(tester, 24);
      expect(find.text('No se envió · Reintentar'), findsOneWidget);
      expect(chat.clientIds, hasLength(1));
      await tester.tap(find.text('No se envió · Reintentar'));
      await _settle(tester, 24);
      expect(chat.clientIds, hasLength(2));
      expect(chat.clientIds[0], isNotEmpty);
      expect(chat.clientIds[0], chat.clientIds[1]);
      expect(find.text('Once'), findsWidgets);
    });

    testWidgets('duplicate pending body blocks accidental double send',
        (tester) async {
      final chat = _SlowSendChat();
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('chat_input')), 'Dup');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.enterText(find.byKey(const ValueKey('chat_input')), 'Dup');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await _settle(tester, 8);
      expect(chat.sendBodies, ['Dup']);
      chat.release();
      await _settle(tester, 16);
    });

    testWidgets('new content can be sent after prior identical message delivered',
        (tester) async {
      final chat = _ModerationActionsChat();
      await _pumpCommunityChat(tester, chat);
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('chat_input')), 'Repeat');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await _settle(tester, 16);
      expect(chat.sendBodies, ['Repeat']);
      await tester.enterText(find.byKey(const ValueKey('chat_input')), 'Repeat');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await _settle(tester, 16);
      expect(chat.sendBodies, ['Repeat', 'Repeat']);
    });
  });
}

DioException _dioErr(int status, {String? message}) {
  final options = RequestOptions(path: '/football/chat/messages');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: message == null ? null : {'message': message},
    ),
  );
}

Future<void> _pickReportReason(WidgetTester tester, String label) async {
  final reason = find.text(label);
  await tester.ensureVisible(reason);
  await tester.pumpAndSettle();
  await tester.tap(reason);
  await tester.pumpAndSettle();
}

Future<void> _submitFootballReport(WidgetTester tester) async {
  final submit = find.text('Enviar denuncia');
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await _settle(tester, 12);
}

Future<void> _pumpCommunityChat(
  WidgetTester tester,
  FootballChatService chat,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        footballChatServiceProvider.overrideWithValue(chat),
        connectivityStatusProvider.overrideWith(_Net.new),
        currentFanProvider.overrideWith(_FanNotifier.new),
      ],
      child: MaterialApp(
        home: MainShellBranchScope(
          activeBranch: 1,
          child: const CommunitySocialPage(),
        ),
      ),
    ),
  );
}

Future<void> _openMessageMenu(WidgetTester tester, String messageId) async {
  await tester.tap(find.byKey(ValueKey('chat_msg_menu_$messageId')));
  await tester.pumpAndSettle();
}

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

Future<void> _settle(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

class _StablePagingChat extends FootballChatService {
  _StablePagingChat() : super(dio: Dio());

  final List<String> calls = [];
  static final _tie = DateTime.utc(2026, 10, 6, 20, 30);

  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    calls.add(
        'page:${before?.toIso8601String() ?? 'latest'}:beforeId:${beforeId ?? ''}');
    if (before == null) {
      return FootballChatPage(
        items: [
          _msg('mid', _tie, 'middle'),
          _msg('new', _tie.add(const Duration(minutes: 1)), 'newest'),
        ],
        hasMore: true,
      );
    }
    if (beforeId == 'mid') {
      return FootballChatPage(
        items: [_msg('old', _tie.subtract(const Duration(minutes: 1)), 'old')],
        hasMore: false,
      );
    }
    return const FootballChatPage(items: [], hasMore: false);
  }
}

class _AuthorshipChat extends FootballChatService {
  _AuthorshipChat() : super(dio: Dio());

  static final _at = DateTime.utc(2026, 10, 6, 20, 15);

  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    if (before != null) {
      return const FootballChatPage(items: [], hasMore: false);
    }
    return FootballChatPage(
      items: [
        _msg('other-msg', _at, 'their line', authorId: 'fan-other'),
        _msg('own-msg', _at.add(const Duration(minutes: 1)), 'my post',
            authorId: 'fan-me'),
      ],
      hasMore: false,
    );
  }
}

class _ReportCall {
  _ReportCall(this.messageId, this.category);
  final String messageId;
  final String category;
}

class _ModerationActionsChat extends _AuthorshipChat {
  final List<_ReportCall> reportCalls = [];
  final List<String> deleteCalls = [];
  final List<String> sendBodies = [];
  ReportSubmitResult reportResult = ReportSubmitResult.success();
  ReportSubmitResult deleteResult = ReportSubmitResult.success();

  @override
  Future<ReportSubmitResult> reportMessage({
    required String messageId,
    required String category,
    String? reason,
  }) async {
    reportCalls.add(_ReportCall(messageId, category));
    return reportResult;
  }

  @override
  Future<ReportSubmitResult> deleteMessage(String messageId) async {
    deleteCalls.add(messageId);
    return deleteResult;
  }

  @override
  Future<FootballChatMessage> send(String body,
      {FootballChatContext context = const FootballChatContext.general(),
      String? clientMessageId}) async {
    sendBodies.add(body);
    return _msg(
      'sent-${sendBodies.length}',
      DateTime.utc(2026, 10, 6, 21, 0),
      body,
      authorId: 'fan-me',
    );
  }
}

class _IdempotentSendChat extends _AuthorshipChat {
  final List<String> clientIds = [];
  var attempts = 0;

  @override
  Future<FootballChatMessage> send(String body,
      {FootballChatContext context = const FootballChatContext.general(),
      String? clientMessageId}) async {
    clientIds.add(clientMessageId ?? '');
    attempts++;
    if (attempts == 1) {
      throw _dioErr(409, message: 'Conflicto de idempotencia');
    }
    return _msg('srv-1', DateTime.utc(2026, 10, 6, 21, 0), body,
        authorId: 'fan-me');
  }
}

class _SlowSendChat extends _AuthorshipChat {
  _SlowSendChat() {
    _gate = Completer<void>();
  }
  late final Completer<void> _gate;
  final List<String> sendBodies = [];

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<FootballChatMessage> send(String body,
      {FootballChatContext context = const FootballChatContext.general(),
      String? clientMessageId}) async {
    sendBodies.add(body);
    await _gate.future;
    return _msg('slow-${sendBodies.length}', DateTime.utc(2026, 10, 6, 21, 0),
        body, authorId: 'fan-me');
  }
}

class _ModerationPollChat extends FootballChatService {
  _ModerationPollChat() : super(dio: Dio());
  int polls = 0;

  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    if (before != null) {
      return const FootballChatPage(items: [], hasMore: false);
    }
    polls++;
    if (polls == 1) {
      return FootballChatPage(
        items: [
          _msg('1', DateTime.utc(2026, 10, 6, 20, 1), 'visible'),
          _msg('2', DateTime.utc(2026, 10, 6, 20, 2), 'gone'),
        ],
        hasMore: false,
      );
    }
    return FootballChatPage(
      items: [_msg('1', DateTime.utc(2026, 10, 6, 20, 1), 'visible')],
      hasMore: false,
    );
  }
}
