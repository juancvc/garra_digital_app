import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garra_digital_app/core/navigation/main_shell.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_unread_badge.dart';

class _UnreadChat extends ChatService {
  _UnreadChat() : super(dio: Dio());
  int count = 0;

  @override
  Future<ChatUnreadSummary> unreadSummary() async => ChatUnreadSummary(unreadCount: count);
}

void main() {
  testWidgets('main shell exposes Centro Garra and Crear', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) =>
                      const Scaffold(body: Text('HOME')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/comunidad',
                  builder: (context, state) =>
                      const Scaffold(body: Text('COM')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/centro-garra',
                  builder: (context, state) =>
                      const Scaffold(body: Text('CENTRO')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/explorar',
                  builder: (context, state) =>
                      const Scaffold(body: Text('EXP')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/passport',
                  builder: (context, state) =>
                      const Scaffold(body: Text('PASS')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/comunidad/compose',
          builder: (context, state) => const Scaffold(body: Text('COMPOSE')),
        ),
      ],
    );

    final chat = _UnreadChat();
    final container = ProviderContainer(overrides: [chatServiceProvider.overrideWithValue(chat)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container,
        child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      ),
    );
    await tester.pump();

    final communityDestination = find.byWidgetPredicate((widget) =>
      widget is NavigationDestination && widget.label == 'Comunidad');
    expect(tester.getSize(find.text('Comunidad')).height, lessThan(25));
    expect(tester.widget<Badge>(find.descendant(
      of: communityDestination, matching: find.byType(Badge)).first).isLabelVisible, isFalse);
    chat.count = 120;
    container.invalidate(chatUnreadCountProvider);
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsWidgets);

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('COM'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('HOME'), findsOneWidget);

    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué quieres crear?'), findsOneWidget);
    expect(find.text('Publicación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
