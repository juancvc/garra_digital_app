import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/router/app_router.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/core/utils/garra_message_time.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_backdrop.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_media_grid.dart';
import 'package:garra_digital_app/features/clans/data/clan_models.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_detail_page.dart';
import 'package:garra_digital_app/features/clans/presentation/providers/clans_provider.dart';
import 'package:garra_digital_app/features/community/data/reaction_type.dart';
import 'package:garra_digital_app/features/community_chat/data/community_chat_models.dart';
import 'package:garra_digital_app/features/community_chat/data/community_chat_service.dart';
import 'package:garra_digital_app/features/community_chat/presentation/community_chat_page.dart';
import 'package:garra_digital_app/features/community_chat/presentation/community_chat_timeline.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'clans_foundation_test.dart' show FakeClanService, sampleClan;

const _poll = Duration(seconds: 5);
const _slug = 'garra-surco';
const _composer = Key('community-chat-composer');
const _send = Key('community-chat-send');
const _attach = Key('community-chat-attach-photo');
const _pill = Key('community-chat-new-messages-pill');

// --- Fixtures ----------------------------------------------------------------

DateTime _morning({int daysAgo = 0}) {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    8,
  ).subtract(Duration(days: daysAgo));
}

CommunityChatInfo _info({
  String status = 'ACTIVE',
  String clanStatus = 'ACTIVE',
  bool writable = true,
  int memberCount = 12,
  int watermark = 0,
  String clanName = 'Garra Surco',
}) {
  return CommunityChatInfo(
    chatId: 'chat-1',
    clanId: 'clan-1',
    clanSlug: _slug,
    clanName: clanName,
    status: status,
    clanStatus: clanStatus,
    memberCount: memberCount,
    watermark: watermark,
    lastReadSeq: watermark,
    writable: writable,
  );
}

ChatMessageReactionSummary _r(String type, int count, {bool mine = false}) =>
    ChatMessageReactionSummary(type: type, count: count, reactedByMe: mine);

ChatMediaItem _image(String id) => ChatMediaItem(
  assetId: id,
  url: 'https://example.invalid/$id.jpg',
  contentType: 'image/jpeg',
  kind: 'IMAGE',
);

CommunityChatMessage _m(
  int seq, {
  bool mine = false,
  String senderId = 'u2',
  String name = 'Diego Ramos',
  String status = communityMessageVisible,
  DateTime? at,
  String? content,
  List<ChatMediaItem> media = const [],
  List<ChatMessageReactionSummary> reactions = const [],
  int? version,
  String? id,
}) {
  final visible = status == communityMessageVisible;
  return CommunityChatMessage(
    id: id ?? 'm$seq',
    seq: seq,
    version: version ?? seq,
    status: status,
    sender: CommunityChatSender(
      id: mine ? 'me' : senderId,
      displayName: mine ? 'Yo Crema' : name,
      username: mine ? 'yocrema' : 'user$senderId',
    ),
    mine: mine,
    content: visible ? (content ?? 'Mensaje $seq de la previa') : null,
    createdAt: at ?? _morning().add(Duration(minutes: 10 * seq)),
    media: media,
    reactions: reactions,
    myReaction: myChatReaction(reactions),
  );
}

/// [n] messages from seq 1, alternating other/own, 10 minutes apart (every
/// bubble starts its own group).
List<CommunityChatMessage> _thread(int n) => [
  for (var seq = 1; seq <= n; seq++) _m(seq, mine: seq.isEven),
];

CommunityChatChanges _changes(
  List<CommunityChatMessage> items, {
  required int lastVersion,
  bool hasMore = false,
  bool resync = false,
}) {
  return CommunityChatChanges(
    items: items,
    lastVersion: lastVersion,
    hasMore: hasMore,
    resyncRequired: resync,
  );
}

// --- Fakes -------------------------------------------------------------------

class _Svc extends CommunityChatService {
  _Svc({List<CommunityChatMessage>? messages, CommunityChatInfo? info})
    : all = messages ?? _thread(45),
      infoResult = info ?? _info(),
      super(dio: Dio());

  List<CommunityChatMessage> all;
  CommunityChatInfo infoResult;
  int syncVersion = 500;
  final List<String> calls = [];
  final List<int> readSeqs = [];
  final List<int> sinceVersions = [];
  final List<int> beforeSeqs = [];
  final List<Object> changesQueue = [];
  final List<({String content, List<String> media})> sent = [];
  Object? infoError;
  Object? sendError;
  Object? reactError;
  Completer<void>? olderGate;
  Completer<void>? reactGate;
  int infoCalls = 0;
  int latestCalls = 0;
  var _version = 1000;

  @override
  Future<CommunityChatInfo> info(String slug) async {
    infoCalls += 1;
    calls.add('GET info $slug');
    if (infoError != null) throw infoError!;
    return infoResult;
  }

  @override
  Future<CommunityChatMessagePage> latest(String slug, {int size = 30}) async {
    latestCalls += 1;
    calls.add('GET latest size=$size');
    final items = all.length > size ? all.sublist(all.length - size) : all;
    return CommunityChatMessagePage(
      items: List.of(items),
      hasMoreBefore: all.length > items.length,
      oldestSeq: items.isEmpty ? null : items.first.seq,
      latestSeq: items.isEmpty ? null : items.last.seq,
      lastSeq: all.isEmpty ? 0 : all.last.seq,
      syncVersion: syncVersion,
    );
  }

  @override
  Future<CommunityChatMessagePage> older(
    String slug, {
    required int beforeSeq,
    int size = 30,
  }) async {
    beforeSeqs.add(beforeSeq);
    calls.add('GET older beforeSeq=$beforeSeq size=$size');
    if (olderGate != null) await olderGate!.future;
    final prior = all.where((m) => m.seq < beforeSeq).toList();
    final items = prior.length > size
        ? prior.sublist(prior.length - size)
        : prior;
    return CommunityChatMessagePage(
      items: items,
      hasMoreBefore: prior.length > items.length,
      oldestSeq: items.isEmpty ? null : items.first.seq,
      latestSeq: items.isEmpty ? null : items.last.seq,
      syncVersion: syncVersion,
    );
  }

  @override
  Future<CommunityChatChanges> changes(
    String slug, {
    required int sinceVersion,
  }) async {
    sinceVersions.add(sinceVersion);
    calls.add('GET changes since=$sinceVersion');
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
    sent.add((content: content, media: List.of(mediaAssetIds)));
    if (sendError != null) throw sendError!;
    final seq = (all.isEmpty ? 0 : all.last.seq) + 1;
    final message = _m(
      seq,
      mine: true,
      content: content,
      media: [for (final id in mediaAssetIds) _image(id)],
      at: DateTime.now(),
      version: ++_version,
    );
    all = [...all, message];
    return message;
  }

  @override
  Future<CommunityChatReactionsResult> react(
    String slug,
    String messageId,
    ReactionType type,
  ) {
    calls.add('PUT $messageId ${type.apiValue}');
    return _apply(messageId, type.apiValue);
  }

  @override
  Future<CommunityChatReactionsResult> removeReaction(
    String slug,
    String messageId,
  ) {
    calls.add('DELETE $messageId');
    return _apply(messageId, null);
  }

  Future<CommunityChatReactionsResult> _apply(String id, String? next) async {
    if (reactGate != null) await reactGate!.future;
    if (reactError != null) throw reactError!;
    final current = all.firstWhere((m) => m.id == id);
    final updated = withMyChatReaction(current.reactions, next);
    final version = ++_version;
    all = [
      for (final m in all)
        m.id == id
            ? m.copyWith(
                reactions: updated,
                myReaction: next,
                clearMyReaction: next == null,
                version: version,
              )
            : m,
    ];
    return CommunityChatReactionsResult(
      messageId: id,
      version: version,
      reactions: updated,
      myReaction: next,
    );
  }

  @override
  Future<CommunityChatInfo> markRead(String slug, int seq) async {
    calls.add('POST read $seq');
    readSeqs.add(seq);
    return infoResult;
  }

  int get writes => calls
      .where(
        (c) =>
            c.startsWith('POST send') ||
            c.startsWith('PUT ') ||
            c.startsWith('DELETE '),
      )
      .length;
}

class _Media extends MediaUploadService {
  _Media({this.perPick = 2, this.failUploads = false})
    : super(dio: Dio(), binaryClient: Dio());

  final int perPick;
  final bool failUploads;
  final List<int> maxes = [];
  final List<MediaUploadPurpose> purposes = [];
  var _n = 0;

  @override
  Future<List<XFile>> pickMultiImage({int max = 4}) async {
    maxes.add(max);
    final count = perPick < max ? perPick : max;
    return [for (var i = 0; i < count; i++) XFile('photo-${_n++}.jpg')];
  }

  @override
  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
    bool Function()? canStartRemote,
    CancelToken? cancelToken,
  }) async {
    purposes.add(purpose);
    final draft = MediaDraft(
      localId: file.path,
      state: MediaUploadState.uploading,
    );
    onUpdate?.call(draft);
    if (failUploads) {
      draft.state = MediaUploadState.failed;
    } else {
      draft
        ..assetId = 'asset-${file.path}'
        ..mediaUrl = 'https://example.invalid/${file.path}'
        ..state = MediaUploadState.ready
        ..progress = 1;
    }
    onUpdate?.call(draft);
    return draft;
  }
}
// --- Helpers -----------------------------------------------------------------

Future<void> _open(
  WidgetTester tester,
  _Svc svc, {
  ThemeData? theme,
  _Media? media,
  CommunityChatSeed? seed,
  bool reduceMotion = false,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => CommunityChatPage(
          slug: _slug,
          seed: seed,
          mediaService: media,
          pollInterval: _poll,
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityChatServiceProvider.overrideWithValue(svc)],
      child: MaterialApp.router(
        theme: theme ?? AppTheme.darkTheme,
        routerConfig: router,
        builder: reduceMotion
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
            : null,
      ),
    ),
  );
  await _settle(tester);
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

Finder _row(String id) => find.byKey(Key('community-chat-row-$id'));

Finder _gesture(String id) =>
    find.byKey(Key('community-chat-bubble-gesture-$id'));

Finder _option(String type) => find.byKey(Key('chat-reaction-option-$type'));

Finder _chip(String id, String type) =>
    find.byKey(Key('chat-reaction-chip-$id-$type'));

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

Future<void> _jump(
  WidgetTester tester,
  double Function(ScrollPosition) to,
) async {
  final position = _position(tester);
  position.jumpTo(to(position));
  await _settle(tester);
}

Future<void> _longPress(WidgetTester tester, String id) async {
  await tester.longPress(_gesture(id));
  await _transition(tester);
}

Future<void> _react(WidgetTester tester, String id, String type) async {
  await _longPress(tester, id);
  await tester.tap(_option(type));
  await _transition(tester);
}

Color? _bubbleColor(WidgetTester tester, String id) {
  final box = tester.widget<Container>(
    find.descendant(of: _gesture(id), matching: find.byType(Container)).first,
  );
  return (box.decoration as BoxDecoration?)?.color;
}

IconButton _sendButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(_send));

TextEditingController _controller(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(_composer)).controller!;

Widget _clanApp(FakeClanService clans, _Svc svc, GoRouter router) {
  return ProviderScope(
    overrides: [
      clanServiceProvider.overrideWithValue(clans),
      communityChatServiceProvider.overrideWithValue(svc),
    ],
    child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  );
}

GoRouter _clanRouter() {
  return GoRouter(
    initialLocation: '/clans/$_slug',
    routes: [
      GoRoute(
        path: '/clans/:slug',
        builder: (context, state) =>
            ClanDetailPage(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/clans/:slug/chat',
        builder: (context, state) => CommunityChatPage(
          slug: state.pathParameters['slug']!,
          seed: state.extra is CommunityChatSeed
              ? state.extra as CommunityChatSeed
              : null,
          pollInterval: _poll,
        ),
      ),
    ],
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_PE');
  });

  group('14B contract models', () {
    test('message, page, changes and info parse the backend names', () {
      final message = CommunityChatMessage.fromJson({
        'id': 'm1',
        'seq': 7,
        'version': 12,
        'status': 'VISIBLE',
        'sender': {
          'id': 'u2',
          'displayName': 'Diego Ramos',
          'username': 'diegor',
          'avatarUrl': 'https://example.invalid/a.jpg',
        },
        'mine': false,
        'content': 'Vamos Garra',
        'createdAt': '2026-09-27T20:00:00Z',
        'media': [
          {
            'assetId': 'a1',
            'url': 'https://example.invalid/1.jpg',
            'contentType': 'image/jpeg',
            'kind': 'IMAGE',
          },
        ],
        'reactions': [
          {'type': 'LOVE', 'count': 2, 'reactedByMe': true},
        ],
        'myReaction': 'LOVE',
      });
      expect(message.seq, 7);
      expect(message.version, 12);
      expect(message.sender.label, 'Diego Ramos');
      expect(message.sender.avatarUrl, isNotNull);
      expect(message.media.single.assetId, 'a1');
      expect(message.myReaction, 'LOVE');

      final page = CommunityChatMessagePage.fromJson({
        'items': [
          {'id': 'm1', 'seq': 1, 'version': 1, 'status': 'VISIBLE'},
        ],
        'hasMoreBefore': true,
        'oldestSeq': 1,
        'latestSeq': 1,
        'lastSeq': 9,
        'syncVersion': 44,
      });
      expect(page.hasMoreBefore, isTrue);
      expect(page.oldestSeq, 1);
      expect(page.syncVersion, 44);

      final changes = CommunityChatChanges.fromJson({
        'items': const [],
        'lastVersion': 51,
        'lastSeq': 9,
        'hasMore': true,
        'resyncRequired': false,
      });
      expect(changes.lastVersion, 51);
      expect(changes.hasMore, isTrue);

      final info = CommunityChatInfo.fromJson({
        'chatId': 'c1',
        'clanId': 'k1',
        'clanSlug': _slug,
        'clanName': 'Garra Surco',
        'status': 'ACTIVE',
        'clanStatus': 'ACTIVE',
        'myRole': 'MEMBER',
        'canModerate': false,
        'memberCount': 12,
        'lastSeq': 9,
        'lastVersion': 51,
        'unreadCount': 2,
        'watermark': 7,
        'lastReadSeq': 7,
        'writable': true,
      });
      expect(info.memberCount, 12);
      expect(info.watermark, 7);
      expect(info.writable, isTrue);

      final result = CommunityChatReactionsResult.fromJson({
        'messageId': 'm1',
        'version': 13,
        'reactions': const [],
        'myReaction': null,
      });
      expect(result.version, 13);
      expect(result.myReaction, isNull);
    });

    test('tombstones never expose content, media or reactions', () {
      for (final status in ['DELETED_BY_AUTHOR', 'HIDDEN_BY_MODERATOR']) {
        final message = CommunityChatMessage.fromJson({
          'id': 'm1',
          'seq': 1,
          'version': 3,
          'status': status,
          'content': 'secreto',
          'media': [
            {'assetId': 'a1', 'url': 'u', 'kind': 'IMAGE'},
          ],
          'reactions': [
            {'type': 'LIKE', 'count': 1, 'reactedByMe': true},
          ],
          'myReaction': 'LIKE',
        });
        expect(message.isTombstone, isTrue);
        expect(message.content, isNull);
        expect(message.media, isEmpty);
        expect(message.reactions, isEmpty);
        expect(message.myReaction, isNull);
      }
    });

    test('merge keys by id, orders by seq and never rolls back a version', () {
      final merged = mergeCommunityMessages(
        [_m(3), _m(1), _m(2, version: 9)],
        [_m(2, version: 5, content: 'viejo'), _m(4), _m(1)],
      );
      expect(merged.map((m) => m.seq), [1, 2, 3, 4]);
      expect(merged[1].version, 9);
      expect(merged.map((m) => m.id).toSet().length, merged.length);
      final updated = mergeCommunityMessages(merged, [
        _m(3, status: communityMessageDeletedByAuthor, version: 20),
      ]);
      expect(updated[2].isDeletedByAuthor, isTrue);
    });

    test('timeline groups same sender within the private chat window', () {
      final t = _morning();
      final entries = buildCommunityTimeline([
        _m(1, at: t),
        _m(2, at: t.add(const Duration(minutes: 2))),
        _m(3, at: t.add(const Duration(minutes: 20))),
        _m(4, senderId: 'u3', at: t.add(const Duration(minutes: 21))),
        _m(5, mine: true, at: t.add(const Duration(minutes: 22))),
      ]).whereType<CommunityMessageEntry>().toList();
      expect(entries.map((e) => e.firstInGroup), [
        true,
        false,
        true,
        true,
        true,
      ]);
      expect(entries.first.lastInGroup, isFalse);
    });
  });

  group('14B entry and routing', () {
    testWidgets('an ACTIVE member sees the Chat entry in the clan header', (
      tester,
    ) async {
      final clans = FakeClanService(
        detail: sampleClan(
          myMembership: const ClanMembershipSummary(
            role: 'MEMBER',
            status: 'ACTIVE',
          ),
        ),
      );
      await tester.pumpWidget(_clanApp(clans, _Svc(), _clanRouter()));
      await _pumpFrames(tester);

      expect(find.byKey(const Key('clan_chat_entry')), findsOneWidget);
      expect(find.text('Chat'), findsWidgets);
    });

    testWidgets('a non-member sees no Chat entry', (tester) async {
      final clans = FakeClanService(detail: sampleClan());
      await tester.pumpWidget(_clanApp(clans, _Svc(), _clanRouter()));
      await _pumpFrames(tester);

      expect(find.byKey(const Key('clan_chat_entry')), findsNothing);
    });

    testWidgets(
      'tapping the entry opens /clans/:slug/chat with name and member count',
      (tester) async {
        final clans = FakeClanService(
          detail: sampleClan(
            myMembership: const ClanMembershipSummary(
              role: 'MEMBER',
              status: 'ACTIVE',
            ),
          ),
        );
        final svc = _Svc(messages: _thread(3));
        final router = _clanRouter();
        await tester.pumpWidget(_clanApp(clans, svc, router));
        await _pumpFrames(tester);

        await tester.tap(find.byKey(const Key('clan_chat_entry')));
        await _pumpFrames(tester);

        expect(router.state.uri.path, '/clans/$_slug/chat');
        final page = tester.widget<CommunityChatPage>(
          find.byType(CommunityChatPage),
        );
        expect(page.slug, _slug);
        expect(page.seed?.name, 'Garra Surco');
        expect(svc.calls, contains('GET info $_slug'));
        final title = tester.widget<Text>(
          find.byKey(const Key('community-chat-title')),
        );
        expect(title.data, 'Garra Surco');
        // Member count comes from the chat info contract (12), not the clan.
        expect(find.text('12 miembros'), findsOneWidget);
        expect(find.text('Marketplace'), findsNothing);

        await tester.tap(find.byType(BackButton));
        await _pumpFrames(tester);
        expect(find.byType(CommunityChatPage), findsNothing);
        expect(find.byType(ClanDetailPage), findsOneWidget);
      },
    );

    test('the app router resolves the canonical community chat route', () {
      final router = createAppRouter(
        navigatorKey: GlobalKey<NavigatorState>(debugLabel: '14b'),
        initialLocation: '/explorar',
        redirect: (_, _) => null,
      );
      addTearDown(router.dispose);
      final match = router.configuration.findMatch(
        Uri.parse('/clans/$_slug/chat'),
      );
      expect(match.isError, isFalse);
      expect(match.last.route.name, 'clan-chat');
      expect(match.pathParameters['slug'], _slug);
      final detail = router.configuration.findMatch(Uri.parse('/clans/$_slug'));
      expect(detail.isError, isFalse);
      expect(detail.last.route.name, isNot('clan-chat'));
    });

    testWidgets('the route renders the page and the header seed logo', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(2), info: _info(memberCount: 1));
      await _open(
        tester,
        svc,
        seed: const CommunityChatSeed(
          name: 'Garra Surco',
          logoUrl: 'https://example.invalid/logo.png',
        ),
      );

      expect(find.byType(CommunityChatPage), findsOneWidget);
      expect(find.text('1 miembro'), findsOneWidget);
      expect(find.byKey(const Key('community-chat-header')), findsOneWidget);
      await _dispose(tester);
    });
  });
  group('14B initial load', () {
    testWidgets('loads latest 30 ascending and positions at the bottom', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);

      expect(svc.calls.take(2), ['GET info $_slug', 'GET latest size=30']);
      expect(_row('m45'), findsOneWidget);
      expect(_row('m44'), findsOneWidget);
      expect(
        tester.getTopLeft(_row('m44')).dy,
        lessThan(tester.getTopLeft(_row('m45')).dy),
      );
      expect(_row('m1'), findsNothing);
      final position = _position(tester);
      expect(position.maxScrollExtent - position.pixels, lessThan(1));
      expect(svc.beforeSeqs, isEmpty);
      await _dispose(tester);
    });

    testWidgets('sender identity only on the first bubble of other groups', (
      tester,
    ) async {
      final t = _morning();
      final svc = _Svc(
        messages: [
          _m(1, at: t),
          _m(2, at: t.add(const Duration(minutes: 1))),
          _m(3, mine: true, at: t.add(const Duration(minutes: 2))),
          _m(
            4,
            senderId: 'u3',
            name: 'Ana Torres',
            at: t.add(const Duration(minutes: 3)),
          ),
        ],
      );
      await _open(tester, svc);

      expect(
        find.byKey(const Key('community-chat-sender-name-m1')),
        findsOneWidget,
      );
      expect(find.text('Diego Ramos'), findsOneWidget);
      expect(
        find.byKey(const Key('community-chat-sender-avatar-m1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-chat-sender-name-m2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('community-chat-sender-name-m3')),
        findsNothing,
      );
      expect(find.text('Ana Torres'), findsOneWidget);
      expect(find.text('Yo Crema'), findsNothing);
      final width = tester.getSize(find.byType(CommunityChatPage)).width;
      expect(tester.getTopRight(_gesture('m3')).dx, greaterThan(width - 20));
      expect(tester.getTopLeft(_gesture('m1')).dx, lessThan(width / 2));
      await _dispose(tester);
    });

    testWidgets('day separators reuse the formatter and no receipts show', (
      tester,
    ) async {
      final yesterday = _morning(daysAgo: 1);
      final today = _morning();
      final svc = _Svc(
        messages: [
          _m(1, at: yesterday),
          _m(2, mine: true, at: today),
        ],
      );
      await _open(tester, svc);

      expect(find.text(formatGarraDaySeparator(yesterday)), findsOneWidget);
      expect(find.text(formatGarraDaySeparator(today)), findsOneWidget);
      expect(
        find.byKey(const Key('community-chat-day-separator')),
        findsNWidgets(2),
      );
      // Both messages are at 8:00 (yesterday and today): time only, no receipt.
      expect(find.text(formatGarraMessageTime(today)), findsNWidgets(2));
      expect(find.textContaining('Enviado'), findsNothing);
      expect(find.textContaining('Le\u00eddo'), findsNothing);
      await _dispose(tester);
    });

    for (final (name, theme, colors) in [
      ('Crema', () => AppTheme.lightTheme, GarraSemanticColors.crema),
      ('Noche', () => AppTheme.darkTheme, GarraSemanticColors.noche),
    ]) {
      testWidgets('$name bubbles use the semantic tokens and the backdrop', (
        tester,
      ) async {
        final svc = _Svc(messages: _thread(4));
        await _open(tester, svc, theme: theme());

        expect(_bubbleColor(tester, 'm4'), colors.brandPrimary);
        expect(_bubbleColor(tester, 'm3'), colors.surfaceRaised);
        expect(find.byType(ChatBackdrop), findsOneWidget);
        await _dispose(tester);
      });
    }

    testWidgets('403 on open shows friendly no-access copy with retry', (
      tester,
    ) async {
      final svc = _Svc()
        ..infoError = const CommunityChatException(403, 'raw forbidden');
      await _open(tester, svc);

      expect(find.text(communityChatAccessLostCopy), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('raw forbidden'), findsNothing);

      svc.infoError = null;
      await tester.tap(find.text('Reintentar'));
      await _settle(tester);
      expect(_row('m45'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('404 and 5xx on open never show backend text', (tester) async {
      final svc = _Svc()
        ..infoError = const CommunityChatException(404, 'Clan not found');
      await _open(tester, svc);
      expect(
        find.text('Esta comunidad o su chat no est\u00e1 disponible.'),
        findsOneWidget,
      );
      expect(find.textContaining('Clan not found'), findsNothing);
      await _dispose(tester);

      final down = _Svc()
        ..infoError = const CommunityChatException(500, 'NullPointer');
      await _open(tester, down);
      expect(find.text('No pudimos abrir el chat'), findsOneWidget);
      expect(find.textContaining('NullPointer'), findsNothing);
      await _dispose(tester);
    });
  });

  group('14B pagination', () {
    testWidgets('near the top loads beforeSeq=oldest and keeps the view', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);
      await _jump(tester, (p) => p.minScrollExtent + 250);
      await _settle(tester);
      expect(svc.beforeSeqs, isEmpty);
      final before = tester.getTopLeft(_row('m20'));

      await _jump(tester, (p) => p.pixels - 100);
      final anchor = tester.getTopLeft(_row('m20'));
      await _settle(tester);

      expect(svc.beforeSeqs, [16]);
      expect(svc.calls, contains('GET older beforeSeq=16 size=30'));
      // Prepending never moves what is on screen.
      expect(tester.getTopLeft(_row('m20')), anchor);
      expect(anchor.dy, closeTo(before.dy + 100, 1));
      await _jump(tester, (p) => p.minScrollExtent);
      expect(_row('m1'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('a double trigger issues a single request', (tester) async {
      final svc = _Svc()..olderGate = Completer<void>();
      await _open(tester, svc);

      await _jump(tester, (p) => p.minScrollExtent);
      await _jump(tester, (p) => p.minScrollExtent + 10);
      await _jump(tester, (p) => p.minScrollExtent);
      expect(svc.beforeSeqs, [16]);
      expect(
        find.byKey(const Key('community-chat-older-loading')),
        findsOneWidget,
      );

      svc.olderGate!.complete();
      await _settle(tester);
      expect(svc.beforeSeqs, [16]);
      await _dispose(tester);
    });

    testWidgets('hasMoreBefore=false stops paging', (tester) async {
      final svc = _Svc();
      await _open(tester, svc);
      await _jump(tester, (p) => p.minScrollExtent);
      expect(svc.beforeSeqs, [16]);

      await _jump(tester, (p) => p.minScrollExtent);
      await _jump(tester, (p) => p.minScrollExtent + 5);
      await _jump(tester, (p) => p.minScrollExtent);
      expect(svc.beforeSeqs, [16]);

      final small = _Svc(messages: _thread(20));
      await _dispose(tester);
      await _open(tester, small);
      await _jump(tester, (p) => p.minScrollExtent);
      expect(small.beforeSeqs, isEmpty);
      await _dispose(tester);
    });

    testWidgets('older pages and new messages coexist without duplicates', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);
      await _jump(tester, (p) => p.minScrollExtent);
      expect(svc.beforeSeqs, [16]);

      svc.changesQueue.add(
        _changes([
          _m(20, version: 600, reactions: [_r('FIRE', 1)]),
          _m(46, version: 601),
          _m(46, version: 601),
        ], lastVersion: 601),
      );
      await _pollOnce(tester);

      expect(find.byKey(_pill), findsOneWidget);
      await tester.tap(find.byKey(_pill));
      await _transition(tester);
      expect(_row('m46'), findsOneWidget);
      expect(_row('m45'), findsOneWidget);
      expect(
        tester.getTopLeft(_row('m45')).dy,
        lessThan(tester.getTopLeft(_row('m46')).dy),
      );
      await _dispose(tester);
    });
  });
  group('14B send', () {
    testWidgets('text send trims, appears immediately and clears', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(5));
      await _open(tester, svc);
      expect(_sendButton(tester).onPressed, isNull);
      await tester.enterText(find.byKey(_composer), '   ');
      await tester.pump();
      expect(_sendButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(_composer), '  Vamos Garra  ');
      await tester.pump();
      await tester.tap(find.byKey(_send));
      await _transition(tester);

      expect(svc.sent.single.content, 'Vamos Garra');
      expect(svc.sent.single.media, isEmpty);
      expect(_row('m6'), findsOneWidget);
      expect(find.text('Vamos Garra'), findsOneWidget);
      expect(_controller(tester).text, isEmpty);
      await _dispose(tester);
    });

    testWidgets('1000 characters send; more than 1000 is blocked', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(2));
      await _open(tester, svc);

      await tester.enterText(find.byKey(_composer), 'a' * 1001);
      await tester.pump();
      expect(_controller(tester).text.length, 1000);
      expect(
        find.byKey(const Key('community-chat-composer-counter')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_send));
      await _transition(tester);
      expect(svc.sent.single.content.length, 1000);

      _controller(tester).text = 'b' * 1001;
      await tester.pump();
      await tester.tap(find.byKey(_send));
      await _transition(tester);
      expect(svc.sent, hasLength(1));
      expect(find.textContaining('supera los 1000'), findsOneWidget);
      expect(_controller(tester).text.length, 1001);
      await _dispose(tester);
    });

    testWidgets('image-only send uses CHAT_IMAGE uploads and the media grid', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(2));
      final media = _Media();
      await _open(tester, svc, media: media);

      await tester.tap(find.byKey(_attach));
      await _settle(tester);
      expect(
        find.byKey(const Key('community-chat-image-preview-1')),
        findsOneWidget,
      );
      expect(media.purposes, everyElement(MediaUploadPurpose.chatImage));
      expect(_sendButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(_send));
      await _transition(tester);
      expect(svc.sent.single.content, '');
      expect(svc.sent.single.media, ['asset-photo-0.jpg', 'asset-photo-1.jpg']);
      expect(find.byType(ChatMediaGrid), findsOneWidget);
      expect(
        find.byKey(const Key('community-chat-image-preview-0')),
        findsNothing,
      );
      await _dispose(tester);
    });

    testWidgets('text + images; a preview can be removed before sending', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(2));
      await _open(tester, svc, media: _Media());

      await tester.tap(find.byKey(_attach));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('community-chat-image-remove-0')));
      await tester.pump();
      expect(
        find.byKey(const Key('community-chat-image-preview-1')),
        findsNothing,
      );
      await tester.enterText(find.byKey(_composer), 'Foto del banderazo');
      await tester.pump();
      await tester.tap(find.byKey(_send));
      await _transition(tester);

      expect(svc.sent.single.content, 'Foto del banderazo');
      expect(svc.sent.single.media, ['asset-photo-1.jpg']);
      await _dispose(tester);
    });

    testWidgets('max 4 images: the 5th cannot be attached', (tester) async {
      final svc = _Svc(messages: _thread(2));
      final media = _Media(perPick: 6);
      await _open(tester, svc, media: media);

      await tester.tap(find.byKey(_attach));
      await _settle(tester);
      expect(media.maxes, [4]);
      expect(
        find.byKey(const Key('community-chat-image-preview-3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-chat-image-preview-4')),
        findsNothing,
      );
      final attach = tester.widget<IconButton>(find.byKey(_attach));
      expect(attach.onPressed, isNull);
      await tester.tap(find.byKey(_send));
      await _transition(tester);
      expect(svc.sent.single.media, hasLength(4));
      await _dispose(tester);
    });

    testWidgets('a failed upload is never sent silently; text is kept', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(2));
      await _open(tester, svc, media: _Media(perPick: 1, failUploads: true));

      await tester.tap(find.byKey(_attach));
      await _settle(tester);
      await tester.enterText(find.byKey(_composer), 'Con foto');
      await tester.pump();
      await tester.tap(find.byKey(_send));
      await _transition(tester);

      expect(svc.sent, isEmpty);
      expect(find.textContaining('no se pudo subir'), findsOneWidget);
      expect(_controller(tester).text, 'Con foto');
      await _dispose(tester);
    });

    testWidgets('send failure keeps the draft and shows feedback', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(2))
        ..sendError = const CommunityChatException(500);
      await _open(tester, svc);

      await tester.enterText(find.byKey(_composer), 'No se va');
      await tester.pump();
      await tester.tap(find.byKey(_send));
      await _transition(tester);

      expect(find.text('No pudimos enviar el mensaje'), findsOneWidget);
      expect(_controller(tester).text, 'No se va');
      expect(_row('m3'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('the sent message is not duplicated when /changes returns it', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(2));
      await _open(tester, svc);
      await tester.enterText(find.byKey(_composer), 'Una sola vez');
      await tester.pump();
      await tester.tap(find.byKey(_send));
      await _transition(tester);

      svc.changesQueue.add(_changes([svc.all.last], lastVersion: 700));
      await _pollOnce(tester);

      expect(_row('m3'), findsOneWidget);
      expect(find.text('Una sola vez'), findsOneWidget);
      expect(find.byKey(_pill), findsNothing);
      await _dispose(tester);
    });
  });

  group('14B reactions', () {
    testWidgets('long press on own and other messages offers six reactions', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(2));
      await _open(tester, svc);

      for (final id in ['m1', 'm2']) {
        await _longPress(tester, id);
        expect(_picker(), findsOneWidget);
        for (final type in ['LIKE', 'LOVE', 'HAHA', 'FIRE', 'GARRA', 'SAD']) {
          expect(_option(type), findsOneWidget, reason: type);
        }
        expect(_option('ANGER'), findsNothing);
        expect(_option('CARE'), findsNothing);
        await tester.tapAt(const Offset(5, 300));
        await _transition(tester);
      }
      expect(svc.writes, 0);
      await _dispose(tester);
    });

    testWidgets('optimistic chip, then reconciled with the response', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(2))..reactGate = Completer<void>();
      await _open(tester, svc);

      await _react(tester, 'm1', 'LOVE');
      expect(_chip('m1', 'LOVE'), findsOneWidget);
      expect(svc.calls, contains('PUT m1 LOVE'));

      svc.reactGate!.complete();
      await _settle(tester);
      expect(_chip('m1', 'LOVE'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('failure rolls back with a snackbar', (tester) async {
      final svc = _Svc(messages: _thread(2))
        ..reactError = const CommunityChatException(500);
      await _open(tester, svc);

      await _react(tester, 'm2', 'HAHA');
      await _settle(tester);
      expect(_chip('m2', 'HAHA'), findsNothing);
      expect(
        find.text('No pudimos actualizar la reacci\u00f3n'),
        findsOneWidget,
      );
      await _dispose(tester);
    });

    testWidgets('another reaction replaces mine; the same one removes it', (
      tester,
    ) async {
      final svc = _Svc(
        messages: [
          _m(1, reactions: [_r('LIKE', 1, mine: true)]),
        ],
      );
      await _open(tester, svc);

      await _react(tester, 'm1', 'FIRE');
      await _settle(tester);
      expect(svc.calls, contains('PUT m1 FIRE'));
      expect(_chip('m1', 'FIRE'), findsOneWidget);
      expect(_chip('m1', 'LIKE'), findsNothing);

      await _react(tester, 'm1', 'FIRE');
      await _settle(tester);
      expect(svc.calls, contains('DELETE m1'));
      expect(_chip('m1', 'FIRE'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('GARRA triggers the 320ms pulse', (tester) async {
      final svc = _Svc(messages: _thread(2));
      await _open(tester, svc);

      await _longPress(tester, 'm1');
      await tester.tap(_option('GARRA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('chat-garra-pulse')), findsOneWidget);
      await _transition(tester);
      expect(find.byKey(const Key('chat-garra-pulse')), findsNothing);
      expect(svc.calls, contains('PUT m1 GARRA'));
      await _dispose(tester);
    });

    testWidgets('reduce motion skips the GARRA pulse but still reacts', (
      tester,
    ) async {
      final svc = _Svc(messages: _thread(2));
      await _open(tester, svc, reduceMotion: true);

      await _longPress(tester, 'm1');
      await tester.tap(_option('GARRA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const Key('chat-garra-pulse')), findsNothing);
      await _settle(tester);
      expect(svc.calls, contains('PUT m1 GARRA'));
      expect(_chip('m1', 'GARRA'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('visible bubbles expose a semantic reaction action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final svc = _Svc(messages: _thread(2));
      await _open(tester, svc);

      final actions = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.customSemanticsActions?.isNotEmpty ?? false),
      );
      expect(actions, findsNWidgets(2));
      handle.dispose();
      await _dispose(tester);
    });

    testWidgets('a reaction-only change never scrolls, pills or marks read', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);
      await _jump(tester, (p) => p.pixels - 160);
      final pixels = _position(tester).pixels;
      final reads = List.of(svc.readSeqs);
      final target = svc.all.firstWhere((m) => m.seq == 43);

      svc.changesQueue.add(
        _changes([
          target.copyWith(version: 900, reactions: [_r('LOVE', 3)]),
        ], lastVersion: 900),
      );
      await _pollOnce(tester);

      expect(_position(tester).pixels, pixels);
      expect(find.byKey(_pill), findsNothing);
      expect(svc.readSeqs, reads);
      expect(_chip('m43', 'LOVE'), findsOneWidget);
      await _dispose(tester);
    });
  });
  group('14B polling', () {
    testWidgets('new message at the bottom stays at the bottom', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);

      svc.changesQueue.add(_changes([_m(46, version: 501)], lastVersion: 501));
      await _pollOnce(tester);

      expect(svc.sinceVersions.first, 500);
      expect(_row('m46'), findsOneWidget);
      final position = _position(tester);
      expect(position.maxScrollExtent - position.pixels, lessThan(1));
      expect(find.byKey(_pill), findsNothing);

      await _pollOnce(tester);
      expect(svc.sinceVersions.last, 501);
      await _dispose(tester);
    });

    testWidgets('new message while scrolled up: no yank, pill, tap to bottom', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);
      await _jump(tester, (p) => p.pixels - 400);
      final pixels = _position(tester).pixels;

      svc.changesQueue.add(_changes([_m(46, version: 501)], lastVersion: 501));
      await _pollOnce(tester);

      expect(_position(tester).pixels, pixels);
      expect(find.byKey(_pill), findsOneWidget);
      expect(svc.readSeqs, isNot(contains(46)));

      await tester.tap(find.byKey(_pill));
      await _transition(tester);
      final position = _position(tester);
      expect(position.maxScrollExtent - position.pixels, lessThan(1));
      expect(find.byKey(_pill), findsNothing);
      expect(svc.readSeqs.last, 46);
      await _dispose(tester);
    });

    testWidgets('hasMore pages apply in order within one cycle', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);

      svc.changesQueue
        ..add(
          _changes(
            [_m(47, version: 510), _m(46, version: 509)],
            lastVersion: 510,
            hasMore: true,
          ),
        )
        ..add(_changes([_m(48, version: 511)], lastVersion: 511));
      await _pollOnce(tester);

      expect(svc.sinceVersions.take(2), [500, 510]);
      final y46 = tester.getTopLeft(_row('m46')).dy;
      final y47 = tester.getTopLeft(_row('m47')).dy;
      final y48 = tester.getTopLeft(_row('m48')).dy;
      expect(y46, lessThan(y47));
      expect(y47, lessThan(y48));

      await _pollOnce(tester);
      expect(svc.sinceVersions.last, 511);
      await _dispose(tester);
    });

    testWidgets('an existing id is replaced in place', (tester) async {
      final svc = _Svc();
      await _open(tester, svc);
      final pixels = _position(tester).pixels;

      svc.changesQueue.add(
        _changes([
          svc.all.last.copyWith(version: 800, reactions: [_r('FIRE', 2)]),
        ], lastVersion: 800),
      );
      await _pollOnce(tester);

      expect(_row('m45'), findsOneWidget);
      expect(_chip('m45', 'FIRE'), findsOneWidget);
      expect(_position(tester).pixels, closeTo(pixels, 20));
      expect(find.byKey(_pill), findsNothing);
      await _dispose(tester);
    });

    testWidgets('resyncRequired reloads without duplicates, keeps composer', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);
      await tester.enterText(find.byKey(_composer), 'borrador');
      await tester.pump();

      svc.all = [...svc.all, _m(46), _m(47)];
      svc.syncVersion = 900;
      svc.changesQueue.add(_changes(const [], lastVersion: 0, resync: true));
      await _pollOnce(tester);

      expect(svc.infoCalls, 2);
      expect(svc.latestCalls, 2);
      expect(_row('m47'), findsOneWidget);
      expect(_row('m46'), findsOneWidget);
      expect(_controller(tester).text, 'borrador');

      await _pollOnce(tester);
      expect(svc.sinceVersions.last, 900);
      expect(svc.latestCalls, 2);
      await _dispose(tester);
    });

    testWidgets('5xx keeps the timeline silently and retries', (tester) async {
      final svc = _Svc();
      await _open(tester, svc);

      svc.changesQueue.add(const CommunityChatException(503));
      await _pollOnce(tester);
      expect(_row('m45'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(_composer), findsOneWidget);

      svc.changesQueue.add(_changes([_m(46, version: 501)], lastVersion: 501));
      await _pollOnce(tester);
      expect(svc.sinceVersions, [500, 500]);
      expect(_row('m46'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('403 stops polling, disables the composer, shows feedback', (
      tester,
    ) async {
      final svc = _Svc();
      await _open(tester, svc);

      svc.changesQueue.add(const CommunityChatException(403));
      await _pollOnce(tester);

      expect(
        find.byKey(const Key('community-chat-access-lost')),
        findsOneWidget,
      );
      expect(find.text(communityChatAccessLostCopy), findsOneWidget);
      expect(find.byKey(_composer), findsNothing);
      expect(_row('m45'), findsOneWidget);
      final polls = svc.sinceVersions.length;
      await tester.pump(const Duration(seconds: 20));
      await _settle(tester);
      expect(svc.sinceVersions.length, polls);

      await _longPress(tester, 'm45');
      expect(_picker(), findsNothing);
      expect(svc.writes, 0);
      await _dispose(tester);
    });

    testWidgets('dispose cancels polling', (tester) async {
      final svc = _Svc();
      await _open(tester, svc);
      await _pollOnce(tester);
      final polls = svc.sinceVersions.length;
      expect(polls, 1);

      await _dispose(tester);
      await tester.pump(const Duration(seconds: 20));
      expect(svc.sinceVersions.length, polls);
    });
  });

  group('14B tombstones', () {
    testWidgets('author and moderation tombstones hide everything', (
      tester,
    ) async {
      final svc = _Svc(
        messages: [
          _m(1, status: communityMessageDeletedByAuthor, mine: true),
          _m(
            2,
            status: communityMessageHiddenByModerator,
            media: [_image('x')],
            reactions: [_r('LIKE', 2)],
          ),
          _m(3),
        ],
      );
      await _open(tester, svc);

      expect(find.text('Mensaje eliminado'), findsOneWidget);
      expect(find.text('Mensaje retirado por moderaci\u00f3n'), findsOneWidget);
      expect(find.bySemanticsLabel('Mensaje eliminado'), findsOneWidget);
      expect(find.byType(ChatMediaGrid), findsNothing);
      expect(find.byKey(const Key('chat-reactions-m2')), findsNothing);
      expect(_gesture('m1'), findsNothing);
      expect(_gesture('m2'), findsNothing);
      expect(find.text('Mensaje 1 de la previa'), findsNothing);

      await tester.longPress(
        find.byKey(const Key('community-chat-tombstone-m2')),
      );
      await _transition(tester);
      expect(_picker(), findsNothing);
      expect(svc.writes, 0);
      await _dispose(tester);
    });

    testWidgets('tombstones from /changes update in place, no scroll/pill', (
      tester,
    ) async {
      final svc = _Svc(
        messages: [
          ..._thread(44),
          _m(45, media: [_image('p')], reactions: [_r('LOVE', 1)]),
        ],
      );
      await _open(tester, svc);
      final pixels = _position(tester).pixels;
      final reads = List.of(svc.readSeqs);

      svc.changesQueue.add(
        _changes([
          _m(45, status: communityMessageHiddenByModerator, version: 950),
          _m(
            44,
            status: communityMessageDeletedByAuthor,
            version: 951,
            mine: true,
          ),
        ], lastVersion: 951),
      );
      await _pollOnce(tester);

      expect(
        find.byKey(const Key('community-chat-tombstone-m45')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-chat-tombstone-m44')),
        findsOneWidget,
      );
      expect(find.byType(ChatMediaGrid), findsNothing);
      expect(find.byKey(const Key('chat-reactions-m45')), findsNothing);
      expect(find.byKey(_pill), findsNothing);
      expect(_position(tester).pixels, lessThanOrEqualTo(pixels));
      expect(svc.readSeqs, reads);
      await _dispose(tester);
    });
  });

  group('14B read-only', () {
    for (final (label, info) in [
      ('clan PENDING', _info(clanStatus: 'PENDING', writable: false)),
      ('clan SUSPENDED', _info(clanStatus: 'SUSPENDED', writable: false)),
      ('clan REJECTED', _info(clanStatus: 'REJECTED', writable: false)),
      ('clan ARCHIVED', _info(clanStatus: 'ARCHIVED', writable: false)),
      ('chat READ_ONLY', _info(status: 'READ_ONLY', writable: false)),
      ('chat CLOSED', _info(status: 'CLOSED', writable: false)),
    ]) {
      testWidgets('$label: history visible, composer unavailable', (
        tester,
      ) async {
        final svc = _Svc(messages: _thread(3), info: info);
        await _open(tester, svc);

        expect(_row('m3'), findsOneWidget);
        expect(find.text(communityChatReadOnlyCopy), findsOneWidget);
        expect(find.byKey(_composer), findsNothing);
        expect(find.byKey(_send), findsNothing);
        expect(find.byKey(_attach), findsNothing);

        await _longPress(tester, 'm3');
        expect(_picker(), findsNothing);
        expect(svc.writes, 0);
        await _dispose(tester);
      });
    }
  });

  group('14B mark read', () {
    testWidgets('initial load marks the latest seq once', (tester) async {
      final svc = _Svc(info: _info(watermark: 40));
      await _open(tester, svc);
      expect(svc.readSeqs, [45]);
      await _dispose(tester);

      final read = _Svc(info: _info(watermark: 45));
      await _open(tester, read);
      expect(read.readSeqs, isEmpty);
      await _dispose(tester);
    });

    testWidgets('a new visible message at the bottom advances the read', (
      tester,
    ) async {
      final svc = _Svc(info: _info(watermark: 40));
      await _open(tester, svc);

      svc.changesQueue.add(_changes([_m(46, version: 501)], lastVersion: 501));
      await _pollOnce(tester);
      expect(svc.readSeqs, [45, 46]);

      await _pollOnce(tester);
      expect(svc.readSeqs, [45, 46]);
      await _dispose(tester);
    });

    testWidgets('reaction-only and tombstone-only updates never mark read', (
      tester,
    ) async {
      final svc = _Svc(info: _info(watermark: 45));
      await _open(tester, svc);

      svc.changesQueue
        ..add(
          _changes([
            svc.all.last.copyWith(version: 700, reactions: [_r('SAD', 1)]),
          ], lastVersion: 700),
        )
        ..add(
          _changes([
            _m(
              44,
              status: communityMessageDeletedByAuthor,
              version: 701,
              mine: true,
            ),
          ], lastVersion: 701),
        );
      await _pollOnce(tester);
      await _pollOnce(tester);

      expect(svc.readSeqs, isEmpty);
      await _dispose(tester);
    });

    testWidgets('never sends a seq below the watermark', (tester) async {
      final svc = _Svc(info: _info(watermark: 50));
      await _open(tester, svc);
      expect(svc.readSeqs, isEmpty);

      svc.changesQueue.add(_changes([_m(46, version: 501)], lastVersion: 501));
      await _pollOnce(tester);
      expect(svc.readSeqs, isEmpty);
      await _dispose(tester);
    });
  });
}
