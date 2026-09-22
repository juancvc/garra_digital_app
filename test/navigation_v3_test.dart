import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/navigation/main_shell.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('main shell exposes five destinations including Crear', (tester) async {
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
                  builder: (_, __) => const Scaffold(body: Text('HOME')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/comunidad',
                  builder: (_, __) => const Scaffold(body: Text('COM')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/explorar',
                  builder: (_, __) => const Scaffold(body: Text('EXP')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/passport',
                  builder: (_, __) => const Scaffold(body: Text('PASS')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/comunidad/compose',
          builder: (_, __) => const Scaffold(body: Text('COMPOSE')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Comunidad'), findsOneWidget);
    expect(find.text('Crear'), findsOneWidget);
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);

    await tester.tap(find.text('Comunidad'));
    await tester.pumpAndSettle();
    expect(find.text('COM'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}
