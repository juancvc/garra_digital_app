import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/auth/data/auth_service.dart';
import 'package:garra_digital_app/features/auth/presentation/entry_page.dart';
import 'package:garra_digital_app/features/auth/presentation/login_page.dart';
import 'package:garra_digital_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:garra_digital_app/features/auth/presentation/register_page.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({required this.googleResult}) : super(dio: Dio());

  final LoginResult googleResult;
  int googleCalls = 0;

  @override
  Future<LoginResult> loginWithGoogle() async {
    googleCalls++;
    return googleResult;
  }
}

class _SlowFakeAuthService extends AuthService {
  _SlowFakeAuthService() : super(dio: Dio());

  int googleCalls = 0;
  Completer<LoginResult>? _pending;

  void completeGoogle(LoginResult result) {
    _pending?.complete(result);
  }

  @override
  Future<LoginResult> loginWithGoogle() async {
    googleCalls++;
    _pending = Completer<LoginResult>();
    return _pending!.future;
  }
}

GoRouter _authTestRouter(Widget home) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(path: '/welcome', builder: (_, __) => const EntryPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const Scaffold(body: Text('RECOVERY')),
      ),
    ],
  );
}

Widget _testMedia(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: child,
  );
}

Widget _router(Widget child) {
  final router = _authTestRouter(child);
  return ProviderScope(
    child: _testMedia(
      MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
    ),
  );
}

Widget _routerWithAuth(Widget child, AuthService auth) {
  final router = _authTestRouter(child);
  return ProviderScope(
    overrides: [authServiceProvider.overrideWithValue(auth)],
    child: _testMedia(
      MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
    ),
  );
}

void main() {
  testWidgets('welcome correo opens register', (tester) async {
    await tester.pumpWidget(_router(const EntryPage()));
    await tester.tap(find.text('Crear cuenta con correo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Crear cuenta'), findsWidgets);
    expect(find.byKey(const ValueKey('register-email')), findsOneWidget);
  });

  testWidgets('welcome login link opens login', (tester) async {
    await tester.pumpWidget(_router(const EntryPage()));
    await tester.tap(find.byKey(const ValueKey('entry-login')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Iniciar sesi\u00f3n'), findsOneWidget);
  });

  testWidgets('login crear cuenta opens register', (tester) async {
    await tester.pumpWidget(_router(const LoginPage()));
    await tester.ensureVisible(find.byKey(const ValueKey('login-register-link')));
    await tester.tap(find.byKey(const ValueKey('login-register-link')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('register-email')), findsOneWidget);
  });

  testWidgets('login forgot password opens recovery', (tester) async {
    await tester.pumpWidget(_router(const LoginPage()));
    await tester.tap(find.byKey(const ValueKey('forgot-password-link')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('RECOVERY'), findsOneWidget);
  });

  testWidgets('google cancel on entry shows no snackbar', (tester) async {
    final auth = _FakeAuthService(googleResult: LoginResult.cancelled());
    await tester.pumpWidget(_routerWithAuth(const EntryPage(), auth));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    expect(auth.googleCalls, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(EntryPage), findsOneWidget);
  });

  testWidgets('google real error shows friendly snackbar', (tester) async {
    final auth = _FakeAuthService(
      googleResult: LoginResult.failure(
        'No pudimos iniciar sesi\u00f3n con Google. Intenta de nuevo.',
      ),
    );
    await tester.pumpWidget(_routerWithAuth(const EntryPage(), auth));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    expect(find.textContaining('Google'), findsWidgets);
    expect(find.textContaining('GoogleSignInException'), findsNothing);
  });

  testWidgets('google double tap only one call while loading', (tester) async {
    final auth = _SlowFakeAuthService();
    await tester.pumpWidget(_routerWithAuth(const EntryPage(), auth));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    expect(auth.googleCalls, 1);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNull);
    expect(auth.googleCalls, 1);
    auth.completeGoogle(LoginResult.cancelled());
    await tester.pump();
  });

  testWidgets('login layout 360px textScale 1.0 no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('login layout 360px textScale 1.3 no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LoginPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('login keyboard open and close without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('login-email')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
