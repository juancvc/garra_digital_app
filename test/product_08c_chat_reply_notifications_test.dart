import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_assets.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/presentation/football_chat_room_view.dart';
import 'package:garra_digital_app/features/notifications/data/notification_preferences_service.dart';
import 'package:garra_digital_app/features/notifications/data/push_router.dart';
import 'package:garra_digital_app/features/notifications/presentation/notification_preferences_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _Prefs extends NotificationPreferencesService {
  _Prefs({this.initial = true, this.failLoad = false, this.failSave = false}) : super(dio: Dio());
  bool initial;
  bool failLoad;
  bool failSave;
  final List<bool> patches = [];

  @override
  Future<ChatReplyPreference> load() async {
    if (failLoad) throw DioException(requestOptions: RequestOptions(path: '/x'));
    return ChatReplyPreference(socialChatRepliesEnabled: initial);
  }

  @override
  Future<ChatReplyPreference> setChatReplies(bool enabled) async {
    patches.add(enabled);
    if (failSave) throw DioException(requestOptions: RequestOptions(path: '/x'));
    initial = enabled;
    return ChatReplyPreference(socialChatRepliesEnabled: enabled);
  }
}

FootballChatMessage _msg(int i) => FootballChatMessage(
      id: 'm$i',
      authorId: i.isEven ? 'fan-me' : 'fan-other',
      authorName: 'Hincha',
      authorUsername: 'h',
      body: 'mensaje $i',
      createdAt: DateTime.utc(2026, 10, 10, 20, i),
    );

class _Chat extends FootballChatService {
  _Chat(this.items) : super(dio: Dio());
  final List<FootballChatMessage> items;

  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    if (before != null) return const FootballChatPage(items: [], hasMore: false);
    return FootballChatPage(items: items, hasMore: false);
  }

  @override
  Future<FootballChatStickerCatalog> stickerCatalog() async =>
      const FootballChatStickerCatalog(items: []);

  @override
  Future<List<FootballChatSticker>> stickerFavorites() async => const [];
}

Future<void> _settle(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _pumpRoom(WidgetTester tester, {String? focus, bool match = false}) async {
  tester.view.physicalSize = const Size(420, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      connectivityStatusProvider.overrideWith(_Net.new),
      currentFanProvider.overrideWith(_FanNotifier.new),
      footballChatServiceProvider.overrideWithValue(_Chat([for (var i = 0; i < 40; i++) _msg(i)])),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: MainShellBranchScope(
          activeBranch: 1,
          child: FootballChatRoomView(
            surface: match ? FootballChatSurface.futbolero : FootballChatSurface.community,
            matchId: match ? 1406077 : null,
            focusMessageId: focus,
          ),
        ),
      ),
    ),
  ));
  await _settle(tester);
}

Future<void> _pumpPrefs(WidgetTester tester, _Prefs prefs, {bool dark = false}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [notificationPreferencesServiceProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: const NotificationPreferencesPage(),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

bool _switchValue(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byKey(const ValueKey('pref_chat_replies'))).value;

void main() {
  group('PushRouter FOOTBALL_CHAT', () {
    const r = PushRouter();
    String go(String? refType, String? refId, {String? type}) =>
        r.resolveRoute(authenticated: true, type: type, referenceType: refType, referenceId: refId);

    test('GENERAL and bare FOOTBALL_CHAT open Comunidad Crema with messageId', () {
      expect(go('FOOTBALL_CHAT:GENERAL', 'abc-1'), '/comunidad?messageId=abc-1');
      expect(go('FOOTBALL_CHAT', 'abc-1'), '/comunidad?messageId=abc-1');
      expect(go('football_chat:general', ''), '/comunidad');
    });

    test('MATCH opens the match chat room', () {
      expect(go('FOOTBALL_CHAT:MATCH:1406077', 'r-9'),
          '/centro-garra/chat-futbolero?partido=1406077&messageId=r-9');
      expect(go('FOOTBALL_CHAT:MATCH:1406077', null), '/centro-garra/chat-futbolero?partido=1406077');
    });

    test('invalid match ids and unknown chat refs fall back safely', () {
      for (final bad in ['FOOTBALL_CHAT:MATCH:', 'FOOTBALL_CHAT:MATCH:abc', 'FOOTBALL_CHAT:MATCH:0',
        'FOOTBALL_CHAT:MATCH:-4', 'FOOTBALL_CHAT:MATCH:12x', 'FOOTBALL_CHAT:OTHER']) {
        expect(go(bad, 'm'), '/notifications', reason: bad);
      }
      expect(r.resolveRoute(authenticated: false, referenceType: 'FOOTBALL_CHAT:GENERAL', referenceId: 'm'),
          '/login');
    });

    test('older notification types are unchanged', () {
      expect(go('POST', 'p1'), '/muro-crema/posts/p1');
      expect(go('POST_COMMENT:p1', 'c1'), '/muro-crema/posts/p1?commentId=c1');
      expect(go('COMMUNITY_CHAT:barra', 'x'), '/clans/barra/chat?messageId=x');
      expect(go('REWARD', null), '/rewards/me');
      expect(go('SOMETHING_NEW', 'z'), '/notifications');
      expect(go(null, null), '/notifications');
    });
  });

  group('PushOpenDedupe', () {
    test('same notification navigates once, also after an app restart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = PushOpenDedupe();
      expect(await first.claim('n-1'), isTrue);
      expect(await first.claim('n-1'), isFalse);
      final afterRestart = PushOpenDedupe();
      expect(await afterRestart.claim('n-1'), isFalse);
      expect(await afterRestart.claim('n-2'), isTrue);
      expect(await afterRestart.claim(null), isTrue);
      expect(await afterRestart.claim(''), isTrue);
    });

    test('remembers a bounded number of ids', () async {
      SharedPreferences.setMockInitialValues({});
      final d = PushOpenDedupe();
      for (var i = 0; i < PushOpenDedupe.maxRemembered + 5; i++) {
        await d.claim('id-$i');
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PushOpenDedupe.prefsKey)!.length, PushOpenDedupe.maxRemembered);
    });
  });

  group('ChatReplyPreference', () {
    test('missing field (backend before 08B) defaults to ON', () {
      expect(ChatReplyPreference.fromJson(const {'pushEnabled': true}).socialChatRepliesEnabled, isTrue);
      expect(ChatReplyPreference.fromJson(const {'socialChatRepliesEnabled': false}).socialChatRepliesEnabled,
          isFalse);
    });
  });

  group('Preferencias: Respuestas en chats', () {
    testWidgets('shows server value (off) and saves ON via PATCH', (tester) async {
      final prefs = _Prefs(initial: false);
      await _pumpPrefs(tester, prefs);
      expect(find.text('Respuestas en chats'), findsOneWidget);
      expect(_switchValue(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('pref_chat_replies')));
      await tester.pump();
      await tester.pump();
      expect(prefs.patches, [true]);
      expect(_switchValue(tester), isTrue);
    });

    testWidgets('PATCH failure reverts the toggle and explains', (tester) async {
      final prefs = _Prefs(initial: true, failSave: true);
      await _pumpPrefs(tester, prefs);
      expect(_switchValue(tester), isTrue);
      await tester.tap(find.byKey(const ValueKey('pref_chat_replies')));
      await tester.pump();
      await tester.pump();
      expect(prefs.patches, [false]);
      expect(_switchValue(tester), isTrue);
      expect(find.byKey(const ValueKey('pref_chat_replies_error')), findsOneWidget);
    });

    testWidgets('load failure shows retry, then recovers', (tester) async {
      final prefs = _Prefs(failLoad: true);
      await _pumpPrefs(tester, prefs);
      expect(find.byKey(const ValueKey('pref_error')), findsOneWidget);
      prefs.failLoad = false;
      await tester.tap(find.byKey(const ValueKey('pref_retry')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('pref_chat_replies')), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('readable in ${dark ? 'dark' : 'light'} theme', (tester) async {
        await _pumpPrefs(tester, _Prefs(), dark: dark);
        final title = tester.widget<Text>(find.text('Respuestas en chats'));
        final scheme = Theme.of(tester.element(find.text('Respuestas en chats'))).colorScheme;
        expect(title.style?.color, scheme.onSurface);
        expect(scheme.brightness, dark ? Brightness.dark : Brightness.light);
      });
    }
  });

  group('Room focus (deep link messageId)', () {
    setUp(GarraStickerAssets.debugReset);
    tearDown(GarraStickerAssets.debugReset);

    for (final match in [false, true]) {
      testWidgets('loaded message is scrolled into view and highlighted (${match ? 'MATCH' : 'GENERAL'})',
          (tester) async {
        await _pumpRoom(tester, focus: 'm3', match: match);
        expect(find.byKey(const ValueKey('chat_focus_highlight_m3')), findsOneWidget);
        expect(find.text('mensaje 3'), findsOneWidget);
        final rect = tester.getRect(find.text('mensaje 3'));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(800));
        expect(find.byKey(const ValueKey('chat_focus_not_loaded')), findsNothing);
        await tester.pump(FootballChatRoomView.focusHighlightFor + const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const ValueKey('chat_focus_highlight_m3')), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }

    testWidgets('message outside the loaded window: stays at latest and says so', (tester) async {
      await _pumpRoom(tester, focus: 'not-in-window');
      expect(find.byKey(const ValueKey('chat_focus_not_loaded')), findsOneWidget);
      expect(find.text(FootballChatRoomView.focusNotLoadedCopy), findsOneWidget);
      expect(find.text('mensaje 39'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('no messageId: no highlight, no snackbar', (tester) async {
      await _pumpRoom(tester);
      expect(find.byKey(const ValueKey('chat_focus_not_loaded')), findsNothing);
      expect(find.textContaining('chat_focus_highlight'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
