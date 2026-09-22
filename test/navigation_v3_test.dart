import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/navigation/main_shell.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('main shell exposes five destinations including Crear', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
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
          builder: (context, state) =>
              const Scaffold(body: Text('COMPOSE')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    );
    await tester.pump();

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Comunidad'), findsOneWidget);
    expect(find.text('Crear'), findsOneWidget);
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);

    await tester.tap(find.text('Comunidad'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('COM'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('HOME'), findsOneWidget);
  });
}
