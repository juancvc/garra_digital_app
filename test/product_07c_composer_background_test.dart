import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_assets.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_preloader.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/presentation/crema_chat_ambient_background.dart';
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

class _Chat extends FootballChatService {
  _Chat() : super(dio: Dio());

  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    if (before != null) {
      return const FootballChatPage(items: [], hasMore: false);
    }
    return FootballChatPage(items: [
      FootballChatMessage(
        id: 'm1',
        authorId: 'fan-other',
        authorName: 'Hincha',
        authorUsername: 'h',
        body: 'arenga',
        createdAt: DateTime.utc(2026, 10, 10, 20),
      ),
    ], hasMore: false);
  }

  @override
  Future<FootballChatStickerCatalog> stickerCatalog() async => const FootballChatStickerCatalog();
}

Future<void> _pumpRoom(WidgetTester tester,
    {bool match = false, double textScale = 1.0, Brightness brightness = Brightness.dark}) async {
  final stub = Dio()
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) => h.resolve(Response(requestOptions: o, statusCode: 200, data: {
        'data': {'assetBaseUrl': ''},
      })),
    ));
  await tester.runAsync(() => GarraStickerAssets.ensureRemoteConfig(dio: stub));
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      connectivityStatusProvider.overrideWith(_Net.new),
      currentFanProvider.overrideWith(_FanNotifier.new),
      footballChatServiceProvider.overrideWithValue(_Chat()),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: MainShellBranchScope(
          activeBranch: 1,
          child: match
              ? const FootballChatRoomView(surface: FootballChatSurface.futbolero, matchId: 1406077)
              : const FootballChatRoomView(surface: FootballChatSurface.community),
        ),
      ),
    ),
  ));
  await _settle(tester, 20);
}

double _inputHeight(WidgetTester tester) => tester.getSize(find.byKey(const ValueKey('chat_input'))).height;

void main() {
  setUp(() {
    GarraStickerAssets.debugReset();
    GarraStickerPreloader.debugReset();
  });

  group('ambient background', () {
    for (final b in Brightness.values) {
      testWidgets('${b.name} base', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: b, useMaterial3: true),
          home: const CremaChatAmbientBackground(active: false, child: SizedBox()),
        ));
        final light = b == Brightness.light;
        expect(find.byKey(const ValueKey('crema_ambient_base_light')), light ? findsOneWidget : findsNothing);
        expect(find.byKey(const ValueKey('crema_ambient_base_dark')), light ? findsNothing : findsOneWidget);
        if (!light) {
          final box = tester.widget<ColoredBox>(find.byKey(const ValueKey('crema_ambient_base_dark')));
          expect(box.color, const Color(0xFF120C0E), reason: 'dark keeps the exact previous color');
        }
      });
    }
  });

  for (final match in [false, true]) {
    final label = match ? 'MATCH' : 'GENERAL';
    for (final scale in [1.0, 1.3]) {
      testWidgets('$label x$scale: compact single-line composer, aligned 40dp buttons, no overflow at 360dp',
          (tester) async {
        await _pumpRoom(tester, match: match, textScale: scale);
        expect(tester.takeException(), isNull);
        final h = _inputHeight(tester);
        // Previous composer: 10dp vertical padding + 3-line-capable field (~48+); now dense <= 44 at x1.0.
        expect(h, lessThanOrEqualTo(scale == 1.0 ? 44 : 52));
        final hint = tester.widget<Text>(find.text('Escribe tu arenga...'));
        expect(hint.maxLines, 1);
        for (final k in ['football_chat_emoji_btn', 'football_chat_sticker_btn', 'chat_send']) {
          final s = tester.getSize(find.byKey(ValueKey(k)));
          expect(s.height, inInclusiveRange(40, 48), reason: k);
        }
        // Bottom-aligned controls.
        final sendBottom = tester.getBottomLeft(find.byKey(const ValueKey('chat_send'))).dy;
        final emojiBottom = tester.getBottomLeft(find.byKey(const ValueKey('football_chat_emoji_btn'))).dy;
        expect((sendBottom - emojiBottom).abs(), lessThan(1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }

    testWidgets('$label: multiline grows but caps at 5 lines; reply preview keeps compact composer',
        (tester) async {
      await _pumpRoom(tester, match: match);
      final single = _inputHeight(tester);
      await tester.enterText(find.byKey(const ValueKey('chat_input')), 'a\nb');
      await tester.pump();
      final two = _inputHeight(tester);
      expect(two, greaterThan(single));
      await tester.enterText(find.byKey(const ValueKey('chat_input')), List.filled(12, 'linea').join('\n'));
      await tester.pump();
      final many = _inputHeight(tester);
      final line = two - single;
      expect(many, lessThanOrEqualTo(single + 4 * line + 1), reason: 'capped at 5 lines');
      await tester.enterText(find.byKey(const ValueKey('chat_input')), '');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat_msg_menu_m1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat_action_reply')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat_reply_composer')), findsOneWidget);
      expect(_inputHeight(tester), closeTo(single, 0.5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('light theme room renders over light page without exceptions', (tester) async {
    await _pumpRoom(tester, brightness: Brightness.light);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
