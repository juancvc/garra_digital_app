import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_inbox_page.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_unread_badge.dart';
import 'package:garra_digital_app/features/clans/data/clan_models.dart';
import 'package:garra_digital_app/features/clans/presentation/providers/clans_provider.dart';
import 'package:garra_digital_app/features/community/data/reaction_type.dart';
import 'package:garra_digital_app/features/community_chat/data/community_chat_models.dart';
import 'package:garra_digital_app/features/community_chat/data/community_chat_service.dart';
import 'package:garra_digital_app/features/community_chat/presentation/community_chat_page.dart';
import 'package:go_router/go_router.dart';

import 'clans_foundation_test.dart' show FakeClanService, sampleClan;

const _poll = Duration(seconds: 5);
const _slug = 'garra-surco';
const _composer = Key('community-chat-composer');
const _pill = Key('community-chat-new-messages-pill');
const _deleteAction = Key('community-chat-action-delete');
const _hideAction = Key('community-chat-action-hide');
const _accept = ValueKey('clan_confirm_accept');
const _cancel = ValueKey('clan_confirm_cancel');

// --- Fixtures ----------------------------------------------------------------

DateTime _morning() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 8);
}

CommunityChatInfo _info({
  bool writable = true,
  bool canModerate = false,
  String myRole = 'MEMBER',
  String status = 'ACTIVE',
  int watermark = 0,
}) {
  return CommunityChatInfo(
    chatId: 'chat-1',
    clanId: 'clan-1',
    clanSlug: _slug,
    clanName: 'Garra Surco',
    status: status,
    clanStatus: 'ACTIVE',
    memberCount: 12,
    watermark: watermark,
    lastReadSeq: watermark,
    writable: writable,
    myRole: myRole,
    canModerate: canModerate,
  );
}

CommunityChatMessage _m(
  int seq, {
  bool mine = false,
  String status = communityMessageVisible,
  int? version,
  List<ChatMessageReactionSummary> reactions = const [],
}) {
  final visible = status == communityMessageVisible;
  return CommunityChatMessage(
    id: 'm$seq',
    seq: seq,
    version: version ?? seq,
    status: status,
    sender: CommunityChatSender(
      id: mine ? 'me' : 'u2',
      displayName: mine ? 'Yo Crema' : 'Diego Ramos',
      username: mine ? 'yocrema' : 'diegor',
    ),
    mine: mine,
    content: visible ? 'Mensaje $seq de la previa' : null,
    createdAt: _morning().add(Duration(minutes: 10 * seq)),
    reactions: visible ? reactions : const [],
    myReaction: visible ? myChatReaction(reactions) : null,
  );
}

/// [n] messages from seq 1, alternating other (odd) / own (even).
List<CommunityChatMessage> _thread(int n) => [
  for (var seq = 1; seq <= n; seq++) _m(seq, mine: seq.isEven),
];

CommunityChatChanges _changes(
  List<CommunityChatMessage> items, {
  required int lastVersion,
}) {
  return CommunityChatChanges(
    items: items,
    lastVersion: lastVersion,
    hasMore: false,
    resyncRequired: false,
  );
}

// --- Fakes -------------------------------------------------------------------

class _Svc extends CommunityChatService {
  _Svc({List<CommunityChatMessage>? messages, CommunityChatInfo? info})
    : all = messages ?? _thread(6),
      infoResult = info ?? _info(),
      super(dio: Dio());

  List<CommunityChatMessage> all;
  CommunityChatInfo infoResult;
  final List<String> calls = [];
  final List<int> readSeqs = [];
  final List<int> beforeSeqs = [];
  final List<Object> changesQueue = [];
  final List<String> slugs = [];
  Object? infoError;
  Object? deleteError;
  Object? hideError;
  bool forceMoreBefore = false;
  int? latestLimit;
  int changesCalls = 0;
  var _version = 1000;

  @override
  Future<CommunityChatInfo> info(String slug) async {
    slugs.add(slug);
    calls.add('GET info');
    if (infoError != null) throw infoError!;
    return infoResult;
  }

  @override
  Future<CommunityChatMessagePage> latest(String slug, {int size = 30}) async {
    slugs.add(slug);
    calls.add('GET latest');
    final take = latestLimit ?? size;
    final items = all.length > take ? all.sublist(all.length - take) : all;
    return CommunityChatMessagePage(
      items: List.of(items),
      hasMoreBefore: forceMoreBefore || all.length > items.length,
      oldestSeq: items.isEmpty ? null : items.first.seq,
      latestSeq: items.isEmpty ? null : items.last.seq,
      lastSeq: all.isEmpty ? 0 : all.last.seq,
      syncVersion: 500,
    );
  }

  @override
  Future<CommunityChatMessagePage> older(
    String slug, {
    required int beforeSeq,
    int size = 30,
  }) async {
    beforeSeqs.add(beforeSeq);
    calls.add('GET older $beforeSeq');
    final prior = all.where((m) => m.seq < beforeSeq).toList();
    final items = prior.length > size
        ? prior.sublist(prior.length - size)
        : prior;
    return CommunityChatMessagePage(
      items: items,
      hasMoreBefore: prior.length > items.length,
      oldestSeq: items.isEmpty ? null : items.first.seq,
      latestSeq: items.isEmpty ? null : items.last.seq,
      syncVersion: 500,
    );
  }

  @override
  Future<CommunityChatChanges> changes(
    String slug, {
    required int sinceVersion,
  }) async {
    changesCalls += 1;
    calls.add('GET changes');
    if (changesQueue.isEmpty) {
      return _changes(const [], lastVersion: sinceVersion);
    }
    final next = changesQueue.removeAt(0);
    if (next is CommunityChatChanges) return next;
    throw next;
  }

  @override
  Future<CommunityChatMessage> send(
    String slug,
    String content, {
    List<String> mediaAssetIds = const [],
  }) async {
    calls.add('POST send');
    final seq = all.last.seq + 1;
    final message = _m(seq, mine: true, version: ++_version);
    all = [...all, message];
    return message;
  }

  @override
  Future<CommunityChatReactionsResult> react(
    String slug,
    String messageId,
    ReactionType type,
  ) async {
    calls.add('PUT reaction $messageId');
    throw const CommunityChatException(500);
  }

  @override
  Future<CommunityChatMessage> deleteMessage(
    String slug,
    String messageId,
  ) async {
    calls.add('DELETE /clans/$slug/chat/messages/$messageId');
    if (deleteError != null) throw deleteError!;
    return _tombstone(messageId, communityMessageDeletedByAuthor);
  }

  @override
  Future<CommunityChatMessage> hideMessage(
    String slug,
    String messageId,
  ) async {
    calls.add('POST /clans/$slug/chat/messages/$messageId/hide');
    if (hideError != null) throw hideError!;
    return _tombstone(messageId, communityMessageHiddenByModerator);
  }

  CommunityChatMessage _tombstone(String id, String status) {
    final current = all.firstWhere((m) => m.id == id);
    final tombstone = _m(
      current.seq,
      mine: current.mine,
      status: status,
      version: ++_version,
    );
    all = [
      for (final m in all)
        if (m.id == id) tombstone else m,
    ];
    return tombstone;
  }

  @override
  Future<CommunityChatInfo> markRead(String slug, int seq) async {
    calls.add('POST read $seq');
    readSeqs.add(seq);
    return infoResult;
  }

  Iterable<String> get messageWrites =>
      calls.where((c) => c.startsWith('DELETE ') || c.contains('/hide'));
}

class _Chat extends ChatService {
  _Chat({this.summary = ChatUnreadSummary.zero}) : super(dio: Dio());

  ChatUnreadSummary summary;
  List<ChatConversation> conversationsResult = const [];
  List<ChatConversation> requestsResult = const [];
  int summaryCalls = 0;
  int conversationsCalls = 0;

  @override
  Future<ChatUnreadSummary> unreadSummary() async {
    summaryCalls += 1;
    return summary;
  }

  @override
  Future<List<ChatConversation>> conversations() async {
    conversationsCalls += 1;
    return conversationsResult;
  }

  @override
  Future<List<ChatConversation>> incoming() async => requestsResult;
}

class _Clans extends FakeClanService {
  _Clans({super.myClans});

  int myClansCalls = 0;

  @override
  Future<List<MyClanMembership>> getMyClans() async {
    myClansCalls += 1;
    return myClans;
  }
}

MyClanMembership _membership(
  String slug,
  String name, {
  String status = 'ACTIVE',
  int memberCount = 12,
  String? logoUrl,
}) {
  return MyClanMembership(
    clan: sampleClan(
      id: 'clan-$slug',
      slug: slug,
      name: name,
      memberCount: memberCount,
      logoUrl: logoUrl,
    ),
    role: 'MEMBER',
    status: status,
  );
}

ChatConversation _conversation() {
  return const ChatConversation(
    id: 'c1',
    otherUserId: 'u2',
    otherDisplayName: 'Diego Ramos',
    otherUsername: 'diegor',
    status: 'ACTIVE',
    outgoing: false,
    context: 'SOCIAL',
  );
}

// --- Helpers -----------------------------------------------------------------

Future<ProviderContainer> _open(
  WidgetTester tester,
  _Svc svc, {
  _Chat? chat,
  _Clans? clans,
}) async {
  final container = ProviderContainer(
    overrides: [
      communityChatServiceProvider.overrideWithValue(svc),
      chatServiceProvider.overrideWithValue(chat ?? _Chat()),
      clanServiceProvider.overrideWithValue(clans ?? _Clans()),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const CommunityChatPage(slug: _slug, pollInterval: _poll),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    ),
  );
  await _settle(tester);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
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

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _gesture(String id) =>
    find.byKey(Key('community-chat-bubble-gesture-$id'));

Finder _tombstone(String id) => find.byKey(Key('community-chat-tombstone-$id'));

Finder _picker() => find.byKey(const Key('chat-reaction-picker'));

ScrollPosition _position(WidgetTester tester) {
  return tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('community-chat-transcript')),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;
}

Future<void> _longPress(WidgetTester tester, String id) async {
  await tester.longPress(_gesture(id));
  await _transition(tester);
}

Future<void> _closePicker(WidgetTester tester) async {
  await tester.tapAt(const Offset(5, 300));
  await _transition(tester);
}

/// Long press -> contextual action -> confirmation dialog.
Future<void> _action(WidgetTester tester, String id, Key action) async {
  await _longPress(tester, id);
  expect(_picker(), findsOneWidget);
  await tester.tap(find.byKey(action));
  await _transition(tester);
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(_accept));
  await _transition(tester);
  await _settle(tester);
}

// --- Tests -------------------------------------------------------------------

void main() {
  group('14C self delete', () {
    testWidgets('own visible message offers Eliminar next to the reactions', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);

      await _longPress(tester, 'm6');
      expect(_picker(), findsOneWidget);
      expect(find.byKey(const Key('chat-message-actions')), findsOneWidget);
      expect(find.byKey(_deleteAction), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      expect(find.byKey(_hideAction), findsNothing);
      for (final type in ['LIKE', 'LOVE', 'HAHA', 'FIRE', 'GARRA', 'SAD']) {
        expect(
          find.byKey(Key('chat-reaction-option-$type')),
          findsOneWidget,
          reason: type,
        );
      }
      await _closePicker(tester);
      expect(svc.messageWrites, isEmpty);
      await _dispose(tester);
    });

    testWidgets('others\' messages offer no Eliminar (member)', (tester) async {
      final svc = _Svc();
      await _open(tester, svc);

      await _longPress(tester, 'm5');
      expect(_picker(), findsOneWidget);
      expect(find.byKey(_deleteAction), findsNothing);
      expect(find.byKey(_hideAction), findsNothing);
      expect(find.byKey(const Key('chat-message-actions')), findsNothing);
      await _closePicker(tester);
      await _dispose(tester);
    });

    testWidgets('confirmation copy; cancel sends no request', (tester) async {
      final svc = _Svc();
      await _open(tester, svc);

      await _action(tester, 'm6', _deleteAction);
      expect(_picker(), findsNothing);
      expect(find.text('\u00bfEliminar este mensaje?'), findsOneWidget);
      expect(
        find.text('El mensaje dejar\u00e1 de mostrarse en el chat.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_accept),
          matching: find.text('Eliminar'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_cancel));
      await _transition(tester);

      expect(svc.messageWrites, isEmpty);
      expect(_gesture('m6'), findsOneWidget);
      expect(find.text('Mensaje 6 de la previa'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('confirm calls DELETE and shows the server tombstone', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);
      final reads = List.of(svc.readSeqs);

      await _action(tester, 'm6', _deleteAction);
      await _confirm(tester);

      expect(svc.messageWrites, ['DELETE /clans/$_slug/chat/messages/m6']);
      expect(_tombstone('m6'), findsOneWidget);
      expect(find.text('Mensaje eliminado'), findsOneWidget);
      expect(find.text('Mensaje 6 de la previa'), findsNothing);
      expect(find.byKey(_pill), findsNothing);
      expect(svc.readSeqs, reads);

      // The same tombstone later from /changes: no duplicate.
      svc.changesQueue.add(
        _changes([svc.all.last], lastVersion: svc.all.last.version),
      );
      await _pollOnce(tester);
      expect(_tombstone('m6'), findsOneWidget);
      expect(find.text('Mensaje eliminado'), findsOneWidget);

      // A tombstone has no picker and no actions.
      await tester.longPress(_tombstone('m6'), warnIfMissed: false);
      await _transition(tester);
      expect(_picker(), findsNothing);
      expect(find.byKey(_deleteAction), findsNothing);
      await _dispose(tester);
    });

    testWidgets('5xx or network keeps the original with a snackbar', (
      tester,
    ) async {
      for (final error in [
        const CommunityChatException(500),
        const CommunityChatException(null),
      ]) {
        final svc = _Svc()..deleteError = error;
        await _open(tester, svc);

        await _action(tester, 'm6', _deleteAction);
        await _confirm(tester);

        expect(svc.messageWrites, hasLength(1));
        expect(_tombstone('m6'), findsNothing);
        expect(find.text('Mensaje 6 de la previa'), findsOneWidget);
        expect(find.text('No pudimos eliminar el mensaje.'), findsOneWidget);
        expect(find.byKey(_composer), findsOneWidget);
        await _dispose(tester);
      }
    });

    testWidgets('409 reconciles with /changes without crashing', (
      tester,
    ) async {
      final svc = _Svc()..deleteError = const CommunityChatException(409);
      await _open(tester, svc);
      final before = svc.changesCalls;
      svc.changesQueue.add(
        _changes([
          _m(
            6,
            mine: true,
            status: communityMessageHiddenByModerator,
            version: 900,
          ),
        ], lastVersion: 900),
      );

      await _action(tester, 'm6', _deleteAction);
      await _confirm(tester);

      expect(svc.changesCalls, greaterThan(before));
      expect(
        find.text('Este mensaje ya no est\u00e1 disponible.'),
        findsOneWidget,
      );
      expect(_tombstone('m6'), findsOneWidget);
      expect(find.text('Mensaje retirado por moderaci\u00f3n'), findsOneWidget);
      expect(find.byKey(_composer), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('403 gives feedback; access stays when the chat is ours', (
      tester,
    ) async {
      final svc = _Svc()..deleteError = const CommunityChatException(403);
      await _open(tester, svc);

      await _action(tester, 'm6', _deleteAction);
      await _confirm(tester);

      expect(find.text('No pudimos eliminar el mensaje.'), findsOneWidget);
      expect(find.text('Mensaje 6 de la previa'), findsOneWidget);
      expect(find.byKey(const Key('community-chat-access-lost')), findsNothing);
      expect(find.byKey(_composer), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('read-only chat: no picker, no Eliminar, history visible', (
      tester,
    ) async {
      final svc = _Svc(info: _info(writable: false, canModerate: true));
      await _open(tester, svc);

      expect(find.text('Mensaje 6 de la previa'), findsOneWidget);
      for (final id in ['m6', 'm5']) {
        await tester.longPress(_gesture(id));
        await _transition(tester);
        expect(_picker(), findsNothing);
        expect(find.byKey(_deleteAction), findsNothing);
        expect(find.byKey(_hideAction), findsNothing);
      }
      expect(svc.messageWrites, isEmpty);
      await _dispose(tester);
    });

    testWidgets('tombstones offer no action', (tester) async {
      final svc = _Svc(
        info: _info(canModerate: true, myRole: 'OWNER'),
        messages: [
          ..._thread(4),
          _m(5, status: communityMessageHiddenByModerator),
          _m(6, mine: true, status: communityMessageDeletedByAuthor),
        ],
      );
      await _open(tester, svc);

      for (final id in ['m5', 'm6']) {
        await tester.longPress(_tombstone(id), warnIfMissed: false);
        await _transition(tester);
        expect(_picker(), findsNothing);
        expect(find.byKey(_deleteAction), findsNothing);
        expect(find.byKey(_hideAction), findsNothing);
      }
      await _dispose(tester);
    });
  });

  group('14C moderation', () {
    CommunityChatInfo moderator() =>
        _info(canModerate: true, myRole: 'MODERATOR');

    testWidgets('a moderator sees Retirar mensaje on others, not on own', (
      tester,
    ) async {
      final svc = _Svc(info: moderator());
      await _open(tester, svc);

      await _longPress(tester, 'm5');
      expect(find.byKey(_hideAction), findsOneWidget);
      expect(find.text('Retirar mensaje'), findsOneWidget);
      expect(find.byKey(_deleteAction), findsNothing);
      await _closePicker(tester);

      await _longPress(tester, 'm6');
      expect(find.byKey(_hideAction), findsNothing);
      expect(find.byKey(_deleteAction), findsOneWidget);
      await _closePicker(tester);
      expect(svc.messageWrites, isEmpty);
      await _dispose(tester);
    });

    testWidgets('a MEMBER never sees Retirar mensaje', (tester) async {
      final svc = _Svc(info: _info(myRole: 'MEMBER'));
      await _open(tester, svc);

      await _longPress(tester, 'm5');
      expect(_picker(), findsOneWidget);
      expect(find.byKey(_hideAction), findsNothing);
      expect(find.text('Retirar mensaje'), findsNothing);
      await _closePicker(tester);
      await _dispose(tester);
    });

    testWidgets('confirmation copy; cancel sends no request', (tester) async {
      final svc = _Svc(info: moderator());
      await _open(tester, svc);

      await _action(tester, 'm5', _hideAction);
      expect(find.text('\u00bfRetirar este mensaje del chat?'), findsOneWidget);
      expect(
        find.text('El contenido dejar\u00e1 de mostrarse para los miembros.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_accept),
          matching: find.text('Retirar'),
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget); // composer only
      await tester.tap(find.byKey(_cancel));
      await _transition(tester);

      expect(svc.messageWrites, isEmpty);
      expect(find.text('Mensaje 5 de la previa'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('confirm POSTs hide and shows the moderation tombstone', (
      tester,
    ) async {
      final svc = _Svc(info: moderator());
      await _open(tester, svc);
      final reads = List.of(svc.readSeqs);

      await _action(tester, 'm5', _hideAction);
      await _confirm(tester);

      expect(svc.messageWrites, ['POST /clans/$_slug/chat/messages/m5/hide']);
      expect(_tombstone('m5'), findsOneWidget);
      expect(find.text('Mensaje retirado por moderaci\u00f3n'), findsOneWidget);
      expect(find.text('Mensaje 5 de la previa'), findsNothing);
      expect(find.textContaining('MODERATOR'), findsNothing);
      expect(find.byKey(_pill), findsNothing);
      expect(svc.readSeqs, reads);
      await _dispose(tester);
    });

    testWidgets('403 shows the permission snackbar; the chat stays usable', (
      tester,
    ) async {
      final svc = _Svc(info: moderator())
        ..hideError = const CommunityChatException(403);
      await _open(tester, svc);

      await _action(tester, 'm5', _hideAction);
      await _confirm(tester);

      expect(
        find.text('No tienes permisos para retirar este mensaje.'),
        findsOneWidget,
      );
      expect(find.text('Mensaje 5 de la previa'), findsOneWidget);
      expect(find.byKey(const Key('community-chat-access-lost')), findsNothing);
      expect(find.byKey(_composer), findsOneWidget);

      final polls = svc.changesCalls;
      await _pollOnce(tester);
      expect(svc.changesCalls, greaterThan(polls));
      expect(find.byKey(_composer), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('409 reconciles with /changes without crashing', (
      tester,
    ) async {
      final svc = _Svc(info: moderator())
        ..hideError = const CommunityChatException(409);
      await _open(tester, svc);
      svc.changesQueue.add(
        _changes([
          _m(5, status: communityMessageDeletedByAuthor, version: 910),
        ], lastVersion: 910),
      );

      await _action(tester, 'm5', _hideAction);
      await _confirm(tester);

      expect(
        find.text('Este mensaje ya no est\u00e1 disponible.'),
        findsOneWidget,
      );
      expect(_tombstone('m5'), findsOneWidget);
      expect(find.text('Mensaje eliminado'), findsOneWidget);
      expect(find.byKey(_composer), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('read-only chat: a moderator gets no Retirar', (tester) async {
      final svc = _Svc(
        info: _info(writable: false, canModerate: true, status: 'READ_ONLY'),
      );
      await _open(tester, svc);

      await tester.longPress(_gesture('m5'));
      await _transition(tester);
      expect(_picker(), findsNothing);
      expect(find.byKey(_hideAction), findsNothing);
      expect(find.text('Mensaje 5 de la previa'), findsOneWidget);
      await _dispose(tester);
    });
  });

  group('14C tombstones via polling', () {
    testWidgets('scrolled up: in place, no pill, no scroll, no mark-read', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(40));
      await _open(tester, svc);
      final position = _position(tester);
      position.jumpTo(position.maxScrollExtent - 600);
      await _settle(tester);
      final pixels = _position(tester).pixels;
      final reads = List.of(svc.readSeqs);

      svc.changesQueue.add(
        _changes([
          _m(39, status: communityMessageHiddenByModerator, version: 960),
          _m(
            40,
            mine: true,
            status: communityMessageDeletedByAuthor,
            version: 961,
          ),
        ], lastVersion: 961),
      );
      await _pollOnce(tester);

      expect(find.byKey(_pill), findsNothing);
      expect(_position(tester).pixels, closeTo(pixels, 0.5));
      expect(svc.readSeqs, reads);
      _position(tester).jumpTo(_position(tester).maxScrollExtent);
      await _settle(tester);
      expect(_tombstone('m39'), findsOneWidget);
      expect(_tombstone('m40'), findsOneWidget);
      await _dispose(tester);
    });
  });

  group('14C global unread', () {
    test('parses total, direct and community', () {
      final summary = ChatUnreadSummary.fromJson({
        'unreadCount': 7,
        'directUnreadCount': 4,
        'communityUnreadCount': 3,
      });
      expect(summary.unreadCount, 7);
      expect(summary.directUnreadCount, 4);
      expect(summary.communityUnreadCount, 3);

      final legacy = ChatUnreadSummary.fromJson({'unreadCount': 2});
      expect(legacy.unreadCount, 2);
      expect(legacy.directUnreadCount, 2);
      expect(legacy.communityUnreadCount, 0);
      expect(ChatUnreadSummary.zero.unreadCount, 0);
    });

    test('one fetch feeds the total and the split', () async {
      final chat = _Chat(
        summary: const ChatUnreadSummary(
          unreadCount: 5,
          directUnreadCount: 3,
          communityUnreadCount: 2,
        ),
      );
      final container = ProviderContainer(
        overrides: [chatServiceProvider.overrideWithValue(chat)],
      );
      addTearDown(container.dispose);
      container.listen(chatUnreadTotalProvider, (_, _) {});
      final summary = await container.read(chatUnreadCountProvider.future);

      expect(summary.directUnreadCount, 3);
      expect(summary.communityUnreadCount, 2);
      expect(container.read(chatUnreadTotalProvider), 5);
      expect(chat.summaryCalls, 1);
    });

    Future<void> pumpBadge(WidgetTester tester, _Chat chat) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [chatServiceProvider.overrideWithValue(chat)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              appBar: AppBar(actions: const [GarraMessagesAction()]),
            ),
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('Home Mensajes badge shows the backend total, no re-sum', (
      tester,
    ) async {
      final chat = _Chat(
        summary: const ChatUnreadSummary(
          unreadCount: 5,
          directUnreadCount: 3,
          communityUnreadCount: 2,
        ),
      );
      await pumpBadge(tester, chat);

      final badge = tester.widget<Badge>(
        find.byKey(const Key('messages-entry-badge')),
      );
      expect(badge.isLabelVisible, isTrue);
      expect(
        find.descendant(
          of: find.byKey(const Key('messages-entry')),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      expect(find.text('10'), findsNothing);
      expect(find.text('9+'), findsNothing);
      expect(chat.summaryCalls, 1);
    });

    testWidgets('0 hides the badge; >9 keeps the 9+ presentation', (
      tester,
    ) async {
      await pumpBadge(tester, _Chat());
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('messages-entry-badge')))
            .isLabelVisible,
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpBadge(
        tester,
        _Chat(
          summary: const ChatUnreadSummary(
            unreadCount: 12,
            directUnreadCount: 0,
            communityUnreadCount: 12,
          ),
        ),
      );
      expect(find.text('9+'), findsOneWidget);
    });

    testWidgets('community mark-read refetches the global unread', (
      tester,
    ) async {
      final chat = _Chat(
        summary: const ChatUnreadSummary(
          unreadCount: 4,
          directUnreadCount: 1,
          communityUnreadCount: 3,
        ),
      );
      final svc = _Svc();
      final container = ProviderContainer(
        overrides: [
          communityChatServiceProvider.overrideWithValue(svc),
          chatServiceProvider.overrideWithValue(chat),
          clanServiceProvider.overrideWithValue(_Clans()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(chatUnreadCountProvider, (_, _) {});
      await container.read(chatUnreadCountProvider.future);
      expect(chat.summaryCalls, 1);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const CommunityChatPage(slug: _slug, pollInterval: _poll),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await _settle(tester);

      expect(svc.readSeqs, [6]);
      expect(chat.summaryCalls, 2);
      await _dispose(tester);
    });

    testWidgets('access lost refetches clan list and global unread', (
      tester,
    ) async {
      final chat = _Chat();
      final clans = _Clans(myClans: [_membership(_slug, 'Garra Surco')]);
      final svc = _Svc();
      final container = await _open(tester, svc, chat: chat, clans: clans);
      container.listen(myClansProvider, (_, _) {});
      container.listen(chatUnreadCountProvider, (_, _) {});
      await container.read(myClansProvider.future);
      await container.read(chatUnreadCountProvider.future);
      final clanCalls = clans.myClansCalls;
      final unreadCalls = chat.summaryCalls;

      svc.changesQueue.add(const CommunityChatException(403));
      await _pollOnce(tester);

      expect(
        find.byKey(const Key('community-chat-access-lost')),
        findsOneWidget,
      );
      expect(clans.myClansCalls, greaterThan(clanCalls));
      expect(chat.summaryCalls, greaterThan(unreadCalls));
      await _dispose(tester);
    });
  });

  group('14C inbox', () {
    GoRouter inboxRouter(_Chat chat) => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ChatInboxPage(chatService: chat),
        ),
        GoRoute(
          path: '/clans/:slug/chat',
          builder: (context, state) {
            final seed = state.extra as CommunityChatSeed?;
            return Scaffold(
              body: Text(
                'CHAT_ROUTE ${state.pathParameters['slug']} '
                '${seed?.name} ${seed?.logoUrl}',
              ),
            );
          },
        ),
        GoRoute(
          path: '/chat/:conversationId',
          builder: (context, state) => const Scaffold(body: Text('DM_ROUTE')),
        ),
      ],
    );

    Future<void> pumpInbox(
      WidgetTester tester, {
      required _Chat chat,
      required _Clans clans,
      required _Svc svc,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatServiceProvider.overrideWithValue(chat),
            clanServiceProvider.overrideWithValue(clans),
            communityChatServiceProvider.overrideWithValue(svc),
          ],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: inboxRouter(chat),
          ),
        ),
      );
      await _settle(tester);
    }

    _Chat inboxChat() => _Chat(
      summary: const ChatUnreadSummary(
        unreadCount: 7,
        directUnreadCount: 2,
        communityUnreadCount: 5,
      ),
    )..conversationsResult = [_conversation()];

    testWidgets('Privados keeps the private inbox; badges use the split', (
      tester,
    ) async {
      final chat = inboxChat();
      final clans = _Clans(myClans: [_membership(_slug, 'Garra Surco')]);
      final svc = _Svc();
      await pumpInbox(tester, chat: chat, clans: clans, svc: svc);

      expect(find.byKey(const Key('chat-section-private')), findsOneWidget);
      expect(find.byKey(const Key('chat-section-communities')), findsOneWidget);
      expect(find.text('Privados'), findsOneWidget);
      expect(find.text('Comunidades'), findsOneWidget);
      expect(find.text('Conversaciones'), findsOneWidget);
      expect(find.text('Solicitudes'), findsOneWidget);
      expect(find.byKey(const Key('chat-inbox-row-c1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('chat-section-private-count')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('chat-section-communities-count')),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      expect(find.text('7'), findsNothing);
      expect(chat.summaryCalls, 1);
      expect(clans.myClansCalls, 0);
      expect(svc.calls, isEmpty);

      await tester.tap(find.byKey(const Key('chat-inbox-row-c1')));
      await _transition(tester);
      expect(find.text('DM_ROUTE'), findsOneWidget);
    });

    testWidgets('Comunidades lists ACTIVE memberships without chat calls', (
      tester,
    ) async {
      final chat = inboxChat();
      final clans = _Clans(
        myClans: [
          _membership(
            _slug,
            'Garra Surco',
            memberCount: 12,
            logoUrl: 'https://example.invalid/logo.png',
          ),
          _membership('crema-norte', 'Crema Norte', memberCount: 1),
          _membership('pendiente', 'Pendiente FC', status: 'PENDING'),
        ],
      );
      final svc = _Svc();
      await pumpInbox(tester, chat: chat, clans: clans, svc: svc);

      await tester.tap(find.byKey(const Key('chat-section-communities')));
      await _settle(tester);

      expect(
        find.byKey(const Key('community-inbox-row-$_slug')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-inbox-row-crema-norte')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-inbox-row-pendiente')),
        findsNothing,
      );
      expect(find.text('12 miembros'), findsOneWidget);
      expect(find.text('1 miembro'), findsOneWidget);
      expect(find.byKey(const Key('chat-inbox-row-c1')), findsNothing);
      expect(clans.myClansCalls, 1);
      expect(svc.calls, isEmpty);
      expect(
        find.descendant(
          of: find.byKey(const Key('chat-section-communities-count')),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('community-inbox-row-$_slug')));
      await _transition(tester);
      expect(
        find.text(
          'CHAT_ROUTE $_slug Garra Surco https://example.invalid/logo.png',
        ),
        findsOneWidget,
      );
      expect(svc.calls, isEmpty);
    });

    testWidgets('empty state when the viewer has no community', (tester) async {
      final chat = inboxChat();
      final clans = _Clans(
        myClans: [_membership('pendiente', 'Pendiente FC', status: 'LEFT')],
      );
      final svc = _Svc();
      await pumpInbox(tester, chat: chat, clans: clans, svc: svc);

      await tester.tap(find.byKey(const Key('chat-section-communities')));
      await _settle(tester);

      expect(find.byKey(const Key('community-inbox-empty')), findsOneWidget);
      expect(
        find.text('A\u00fan no perteneces a ninguna comunidad.'),
        findsOneWidget,
      );
      expect(svc.calls, isEmpty);
    });

    testWidgets('pull to refresh refetches the list and the global unread', (
      tester,
    ) async {
      final chat = inboxChat();
      final clans = _Clans(myClans: [_membership(_slug, 'Garra Surco')]);
      final svc = _Svc();
      await pumpInbox(tester, chat: chat, clans: clans, svc: svc);
      await tester.tap(find.byKey(const Key('chat-section-communities')));
      await _settle(tester);
      final clanCalls = clans.myClansCalls;
      final unreadCalls = chat.summaryCalls;

      clans.myClans = [
        _membership(_slug, 'Garra Surco'),
        _membership('crema-norte', 'Crema Norte'),
      ];
      chat.summary = const ChatUnreadSummary(
        unreadCount: 9,
        directUnreadCount: 2,
        communityUnreadCount: 7,
      );
      await tester.fling(
        find.byKey(const Key('community-inbox-row-$_slug')),
        const Offset(0, 400),
        1200,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);

      expect(clans.myClansCalls, greaterThan(clanCalls));
      expect(chat.summaryCalls, greaterThan(unreadCalls));
      expect(
        find.byKey(const Key('community-inbox-row-crema-norte')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('chat-section-communities-count')),
          matching: find.text('7'),
        ),
        findsOneWidget,
      );
      expect(svc.calls, isEmpty);
    });

    testWidgets('without a ProviderScope the private inbox renders alone', (
      tester,
    ) async {
      final chat = inboxChat();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChatInboxPage(chatService: chat),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const Key('chat-section-private')), findsNothing);
      expect(find.byKey(const Key('chat-inbox-row-c1')), findsOneWidget);
    });
  });

  group('14C short first page', () {
    testWidgets('a latest page that does not fill the view loads older', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(20))..latestLimit = 3;
      await _open(tester, svc);
      await tester.pump(const Duration(milliseconds: 50));
      await _settle(tester);

      expect(svc.beforeSeqs, isNotEmpty);
      expect(svc.beforeSeqs.first, 18);
      expect(find.text('Mensaje 20 de la previa'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('a full page does not trigger the fill', (tester) async {
      final svc = _Svc(messages: _thread(45));
      await _open(tester, svc);
      await tester.pump(const Duration(milliseconds: 50));
      await _settle(tester);

      expect(svc.beforeSeqs, isEmpty);
      await _dispose(tester);
    });
  });
}
