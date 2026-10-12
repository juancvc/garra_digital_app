import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/navigation/main_shell_branch_scope.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/stickers/garra_sticker_assets.dart';
import 'package:garra_digital_app/core/widgets/garra_puma_crest.dart';
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

class _Chat extends FootballChatService {
  _Chat() : super(dio: Dio());

  @override
  Future<FootballChatPage> page(FootballChatContext context,
      {DateTime? before, String? beforeId, int size = 30}) async {
    if (before != null) return const FootballChatPage(items: [], hasMore: false);
    return FootballChatPage(items: [
      FootballChatMessage(
        id: 'm1',
        authorId: 'fan-other',
        authorName: 'Hincha Crema con nombre largo',
        authorUsername: 'h',
        body: 'Vamos la U, hoy se gana en el Monumental',
        createdAt: DateTime.utc(2026, 10, 10, 20),
      ),
      FootballChatMessage(
        id: 'm2',
        authorId: 'fan-me',
        authorName: 'Yo',
        authorUsername: 'me',
        body: 'Dale crema',
        createdAt: DateTime.utc(2026, 10, 10, 20, 1),
      ),
    ], hasMore: false);
  }

  @override
  Future<FootballChatStickerCatalog> stickerCatalog() async => const FootballChatStickerCatalog();

  @override
  Future<List<FootballChatSticker>> stickerFavorites() async => const [];
}

Future<void> _settle(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _pump(WidgetTester tester,
    {required Brightness brightness, double scale = 1.0, bool match = false}) async {
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
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: MainShellBranchScope(
          activeBranch: 1,
          child: match
              ? const FootballChatRoomView(surface: FootballChatSurface.futbolero, matchId: 1406077)
              : const CremaChatAmbientBackground(
                  child: FootballChatRoomView(surface: FootballChatSurface.community),
                ),
        ),
      ),
    ),
  ));
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Iterable<Image> _pumaImages(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .where((i) => i.image is AssetImage && (i.image as AssetImage).assetName == GarraIntroAssets.puma);

Color? _bubbleFill(WidgetTester tester, String id) {
  final boxes = tester.widgetList<Container>(find.descendant(
    of: find.byKey(ValueKey('chat_msg_bubble_$id')),
    matching: find.byType(Container),
  ));
  for (final c in boxes) {
    final d = c.decoration;
    if (d is BoxDecoration && d.border != null && d.color != null) return d.color;
  }
  return null;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUp(GarraStickerAssets.debugReset);
  tearDown(GarraStickerAssets.debugReset);

  testWidgets('light: one masked, luminance-keyed puma and no floating crest squares', (tester) async {
    await _pump(tester, brightness: Brightness.light);
    final crest = find.byKey(const ValueKey('crema_ambient_crest_light'));
    expect(crest, findsOneWidget);
    expect(tester.widget<Opacity>(crest).opacity, lessThanOrEqualTo(0.08));
    expect(find.descendant(of: crest, matching: find.byType(ShaderMask)), findsOneWidget);
    expect(find.descendant(of: crest, matching: find.byType(ColorFiltered)), findsOneWidget);
    final pumas = _pumaImages(tester).toList();
    expect(pumas, hasLength(1), reason: 'opaque crest PNG must not be used as particles in light');
    expect(find.descendant(of: crest, matching: find.byWidget(pumas.single)), findsOneWidget);
    expect(find.byKey(const ValueKey('crema_ambient_base_light')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('dark: background layers unchanged (big crest + 14 floating crests)', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    expect(find.byKey(const ValueKey('crema_ambient_crest_light')), findsNothing);
    expect(find.byKey(const ValueKey('crema_ambient_base_dark')), findsOneWidget);
    expect(_pumaImages(tester), hasLength(15));
    expect(find.byType(ShaderMask), findsNothing);
    await _dispose(tester);
  });

  testWidgets('light bubbles: warm cream (not pure white) with readable text, own bubble unchanged',
      (tester) async {
    await _pump(tester, brightness: Brightness.light);
    final other = _bubbleFill(tester, 'm1');
    expect(other, isNotNull);
    expect(other, isNot(const Color(0xFFFFFFFF)));
    expect(other, const Color(0xFFFCF6EA));
    expect(_bubbleFill(tester, 'm2'), const Color(0xFF7C0211));
    const cream = Color(0xFFF3E9D2);
    expect(_contrast(const Color(0xFF6A4C0E), cream), greaterThanOrEqualTo(4.5), reason: 'name');
    expect(_contrast(const Color(0xFF5E5047), cream), greaterThanOrEqualTo(4.5), reason: 'meta/menu');
    expect(_contrast(const Color(0xFF2A1A1C), other!), greaterThanOrEqualTo(7));
    final menu = tester.getRect(find.byKey(const ValueKey('chat_msg_menu_m1')));
    final bubble = tester.getRect(find.byKey(const ValueKey('chat_msg_bubble_m1')));
    // Light crema: the 32dp menu sits lower (top padding 14) so its icon lines up with the bubble body.
    final icon = tester.getRect(find.descendant(
        of: find.byKey(const ValueKey('chat_msg_menu_m1')), matching: find.byType(Icon)));
    expect(icon.top, greaterThanOrEqualTo(bubble.top + 14), reason: 'menu icon below the name row');
    expect(icon.bottom, lessThanOrEqualTo(bubble.bottom));
    expect(menu.left, greaterThan(bubble.right - 1));
    await _dispose(tester);
  });

  testWidgets('dark bubbles keep the previous palette', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    expect(_bubbleFill(tester, 'm1'), const Color(0xE6221A1C));
    expect(_bubbleFill(tester, 'm2'), const Color(0xFF6E2A35));
    await _dispose(tester);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('360dp x$scale light/dark: no overflow, composer height identical', (tester) async {
      await _pump(tester, brightness: Brightness.light, scale: scale);
      expect(tester.takeException(), isNull);
      final light = tester.getSize(find.byKey(const ValueKey('chat_input'))).height;
      await _dispose(tester);
      await _pump(tester, brightness: Brightness.dark, scale: scale);
      expect(tester.takeException(), isNull);
      final dark = tester.getSize(find.byKey(const ValueKey('chat_input'))).height;
      expect(light, dark);
      await _dispose(tester);
    });
  }

  testWidgets('MATCH room (no ambient background) renders in light without exceptions', (tester) async {
    await _pump(tester, brightness: Brightness.light, match: true);
    expect(find.byKey(const ValueKey('crema_ambient_crest_light')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
