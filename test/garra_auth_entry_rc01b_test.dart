import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/auth/presentation/entry_page.dart';
import 'package:garra_digital_app/features/auth/presentation/login_page.dart';
import 'package:garra_digital_app/features/auth/presentation/register_page.dart';

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: '/welcome', builder: (_, state) => const EntryPage()),
    GoRoute(path: '/login', builder: (_, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (_, state) => RegisterPage(fromLogin: state.extra == true),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (_, state) => const Scaffold(body: Text('RECOVERY')),
    ),
  ],
);

Future<void> _mount(
  WidgetTester tester,
  String initial, {
  bool light = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
        routerConfig: _router(initial),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('welcome to login and register preserve Back stack', (
    tester,
  ) async {
    await _mount(tester, '/welcome');
    await tester.tap(find.byKey(const ValueKey('entry-login')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('login-register-link')),
    );
    await tester.tap(find.byKey(const ValueKey('login-register-link')));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(EntryPage), findsOneWidget);
  });

  testWidgets('direct login and register Back fall to welcome', (tester) async {
    for (final route in ['/login', '/register']) {
      await _mount(tester, route);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EntryPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('register login link returns to existing login without a cycle', (
    tester,
  ) async {
    await _mount(tester, '/login');
    await tester.ensureVisible(
      find.byKey(const ValueKey('login-register-link')),
    );
    await tester.tap(find.byKey(const ValueKey('login-register-link')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Ya tienes una cuenta'));
    await tester.tap(find.textContaining('Ya tienes una cuenta'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(EntryPage), findsOneWidget);
  });

  testWidgets('login recovery uses real navigation history', (tester) async {
    await _mount(tester, '/login');
    await tester.tap(find.byKey(const ValueKey('forgot-password-link')));
    await tester.pumpAndSettle();
    expect(find.text('RECOVERY'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('light and dark hero text stays light on stadium', (
    tester,
  ) async {
    for (final light in [true, false]) {
      await _mount(tester, '/login', light: light);
      final title = tester.widget<Text>(find.text('Inicia sesión'));
      expect(title.style!.color, const Color(0xFFF7F0E2));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('all Auth entries fit narrow light and dark layouts', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final light in [true, false]) {
      for (final route in ['/welcome', '/login', '/register']) {
        await _mount(tester, route, light: light);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('reduced motion removes ambient overlay', (tester) async {
    await _mount(tester, '/welcome');
    expect(find.byKey(const ValueKey('auth-ambient-aura')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
