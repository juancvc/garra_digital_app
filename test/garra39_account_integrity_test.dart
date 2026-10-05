import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/network/offline_action_guard.dart';
import 'package:garra_digital_app/core/storage/secure_storage_service.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/auth/data/auth_flow_models.dart';
import 'package:garra_digital_app/features/auth/data/auth_service.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/auth/data/register_request.dart';
import 'package:garra_digital_app/features/auth/presentation/forgot_password_page.dart';
import 'package:garra_digital_app/features/auth/presentation/login_page.dart';
import 'package:garra_digital_app/features/auth/presentation/providers/auth_flow_providers.dart';
import 'package:garra_digital_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:garra_digital_app/features/auth/presentation/register_page.dart';
import 'package:garra_digital_app/features/auth/presentation/reset_password_page.dart';
import 'package:garra_digital_app/features/auth/presentation/verify_email_page.dart';
import 'package:go_router/go_router.dart';

/// GARRA39: account integrity flows + the register lifecycle crash.

class _Source implements ConnectivitySource {
  _Source(this.result);
  final ConnectivityResult result;
  final _controller = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );
  @override
  Future<List<ConnectivityResult>> check() async => [result];
  @override
  Stream<List<ConnectivityResult>> get changes => _controller.stream;
  Future<void> dispose() => _controller.close();
}

/// Scripted service: every call is recorded and answered by a queue/closure.
class _FakeAuth extends AuthService {
  _FakeAuth() : super(dio: Dio());

  Future<AuthFlowResult<RegisterOutcome>> Function(RegisterRequest)? onRegister;
  Future<AuthFlowResult<AuthUser>> Function(String, String)? onVerify;
  Future<AuthFlowResult<ResendAck>> Function(String)? onResend;
  Future<AuthFlowResult<ResendAck>> Function(String)? onForgot;
  Future<AuthFlowResult<void>> Function(String, String, String)? onReset;
  Future<LoginResult> Function(String, String)? onLogin;

  final registers = <RegisterRequest>[];
  final verifies = <List<String>>[];
  var resends = 0;
  var forgots = 0;
  final resets = <List<String>>[];
  var logins = 0;

  @override
  Future<AuthFlowResult<RegisterOutcome>> register(
    RegisterRequest request,
  ) async {
    registers.add(request);
    return onRegister!(request);
  }

  @override
  Future<AuthFlowResult<AuthUser>> verifyEmail({
    required String email,
    required String code,
  }) async {
    verifies.add([email, code]);
    return onVerify!(email, code);
  }

  @override
  Future<AuthFlowResult<ResendAck>> resendVerification(String email) async {
    resends++;
    return onResend!(email);
  }

  @override
  Future<AuthFlowResult<ResendAck>> forgotPassword(String email) async {
    forgots++;
    return onForgot!(email);
  }

  @override
  Future<AuthFlowResult<void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    resets.add([email, code, newPassword]);
    return onReset!(email, code, newPassword);
  }

  @override
  Future<void> discardLocalSession() async {}

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    logins++;
    return onLogin!(email, password);
  }
}

const _user = AuthUser(
  userId: 'u1',
  email: 'juan@example.com',
  username: 'juan',
  fullName: 'Juan',
  status: 'ACTIVE',
);

AuthFlowResult<RegisterOutcome> _verificationRequired({int resend = 60}) =>
    AuthFlowResult.success(
      data: RegisterOutcome(
        verificationRequired: true,
        email: 'juan@example.com',
        resendAvailableInSeconds: resend,
        codeExpiresInSeconds: 600,
      ),
    );

class _Harness {
  _Harness(this.auth, {String initial = '/register'}) {
    router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(
          path: '/verify-email',
          builder: (_, state) =>
              VerifyEmailPage(args: state.extra! as VerifyEmailArgs),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, state) => ForgotPasswordPage(
            initialEmail: state.extra is String ? state.extra! as String : '',
          ),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (_, state) =>
              ResetPasswordPage(args: state.extra! as ResetPasswordArgs),
        ),
        GoRoute(path: '/home', builder: (_, _) => const Text('HOME')),
        GoRoute(path: '/other', builder: (_, _) => const Text('OTHER')),
      ],
    );
  }

  final _FakeAuth auth;
  late final GoRouter router;
  final source = _Source(ConnectivityResult.wifi);

  Widget app({ThemeData? theme}) => ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      connectivitySourceProvider.overrideWithValue(source),
      postVerifyDestinationProvider.overrideWithValue((_) async => '/home'),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        ref.watch(connectivityStatusProvider);
        return MaterialApp.router(
          routerConfig: router,
          theme: theme ?? AppTheme.darkTheme,
        );
      },
    ),
  );
}

Future<void> _bigScreen(WidgetTester tester, {double width = 800}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _fillRegisterForm(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  // GARRA39.1: e-mail + password + confirmation only (the Garra profile comes later).
  await tester.enterText(fields.at(0), ' Juan@Example.com ');
  await tester.enterText(fields.at(1), 'Password-123');
  await tester.enterText(fields.at(2), 'Password-123');
  await tester.pump();
}

Future<void> _tapRegister(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Crear cuenta'));
  await tester.tap(find.text('Crear cuenta'));
}

Finder _primary(String label) => find.widgetWithText(FilledButton, label);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('REGISTER -> CHECK YOUR EMAIL', () {
    testWidgets('success goes to the code screen with the masked email', (
      tester,
    ) async {
      await _bigScreen(tester);
      final auth = _FakeAuth()
        ..onRegister = (_) async => _verificationRequired();
      final h = _Harness(auth);
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await _fillRegisterForm(tester);
      await _tapRegister(tester);
      await tester.pumpAndSettle();

      expect(auth.registers.single.email, 'juan@example.com');
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(find.textContaining('j***@example.com'), findsOneWidget);
      expect(find.byKey(const ValueKey('otp-field')), findsOneWidget);
      // No raw e-mail, no password on screen.
      expect(find.textContaining('juan@example.com'), findsNothing);
      expect(find.textContaining('Password-123'), findsNothing);
    });

    testWidgets(
      'network error keeps the form and shows a recoverable message',
      (tester) async {
        await _bigScreen(tester);
        final auth = _FakeAuth()
          ..onRegister = (_) async => AuthFlowResult.failure(
            AuthFailureKind.network,
            authNetworkMessage,
          );
        final h = _Harness(auth);
        addTearDown(h.source.dispose);
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();

        await _fillRegisterForm(tester);
        await _tapRegister(tester);
        await tester.pumpAndSettle();

        expect(find.text(authNetworkMessage), findsOneWidget);
        expect(find.text('Crear cuenta'), findsWidgets);
        expect(find.text('Revisa tu correo'), findsNothing);
        // The form still holds the data (nothing lost) and can retry.
        expect(find.text(' Juan@Example.com '), findsOneWidget);
      },
    );

    testWidgets('duplicate account and server errors show the server copy', (
      tester,
    ) async {
      await _bigScreen(tester);
      final auth = _FakeAuth()
        ..onRegister = (_) async => AuthFlowResult.failure(
          AuthFailureKind.conflict,
          'Este correo ya est\u00e1 registrado',
        );
      final h = _Harness(auth);
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await _fillRegisterForm(tester);
      await _tapRegister(tester);
      await tester.pumpAndSettle();
      expect(find.text('Este correo ya est\u00e1 registrado'), findsOneWidget);

      auth.onRegister = (_) async =>
          AuthFlowResult.failure(AuthFailureKind.server, authServerMessage);
      await tester.pump(const Duration(seconds: 5));
      await _tapRegister(tester);
      await tester.pumpAndSettle();
      expect(find.text(authServerMessage), findsOneWidget);
    });

    testWidgets(
      'email registration unavailable (no SMTP) explains it and stays on the form',
      (tester) async {
        await _bigScreen(tester);
        final auth = _FakeAuth()
          ..onRegister = (_) async => AuthFlowResult.failure(
            AuthFailureKind.emailUnavailable,
            authEmailUnavailableMessage,
          );
        final h = _Harness(auth);
        addTearDown(h.source.dispose);
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();

        await _fillRegisterForm(tester);
        await _tapRegister(tester);
        await tester.pumpAndSettle();

        expect(find.text(authEmailUnavailableMessage), findsOneWidget);
        expect(find.text('Revisa tu correo'), findsNothing);
        expect(find.text(' Juan@Example.com '), findsOneWidget);
      },
    );

    testWidgets('429 shows the useful message', (tester) async {
      await _bigScreen(tester);
      final auth = _FakeAuth()
        ..onRegister = (_) async => AuthFlowResult.failure(
          AuthFailureKind.rateLimited,
          authRateLimitedMessage,
          retryAfterSeconds: 120,
        );
      final h = _Harness(auth);
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await _fillRegisterForm(tester);
      await _tapRegister(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Has hecho varios intentos. Intenta nuevamente en unos minutos.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('offline: no request is made and the form is kept', (
      tester,
    ) async {
      await _bigScreen(tester);
      final auth = _FakeAuth()
        ..onRegister = (_) async => _verificationRequired();
      final h = _Harness(auth);
      addTearDown(h.source.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            connectivitySourceProvider.overrideWithValue(
              _Source(ConnectivityResult.none),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(connectivityStatusProvider);
              return MaterialApp.router(
                routerConfig: h.router,
                theme: AppTheme.darkTheme,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillRegisterForm(tester);
      await _tapRegister(tester);
      await tester.pumpAndSettle();

      expect(auth.registers, isEmpty);
      expect(find.text(offlineActionMessage), findsOneWidget);
    });

    testWidgets(
      'REGRESSION: page removed while register is in flight does not crash '
      '(no snackbar, no navigation from the dead State)',
      (tester) async {
        await _bigScreen(tester);
        final pending = Completer<AuthFlowResult<RegisterOutcome>>();
        final auth = _FakeAuth()..onRegister = (_) => pending.future;
        final h = _Harness(auth);
        addTearDown(h.source.dispose);
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();

        await _fillRegisterForm(tester);
        await _tapRegister(tester);
        await tester.pump();
        expect(auth.registers, hasLength(1));

        // The user leaves (or a route change replaces the page) mid-request.
        h.router.go('/other');
        await tester.pumpAndSettle();
        expect(find.text('OTHER'), findsOneWidget);

        pending.complete(_verificationRequired());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('OTHER'), findsOneWidget);
        expect(find.text('Revisa tu correo'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'REGRESSION: failure arriving after the page is gone shows nothing',
      (tester) async {
        await _bigScreen(tester);
        final pending = Completer<AuthFlowResult<RegisterOutcome>>();
        final auth = _FakeAuth()..onRegister = (_) => pending.future;
        final h = _Harness(auth);
        addTearDown(h.source.dispose);
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();

        await _fillRegisterForm(tester);
        await _tapRegister(tester);
        await tester.pump();

        // Whole subtree torn down while the request is pending.
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete(
          AuthFlowResult.failure(AuthFailureKind.server, authServerMessage),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a second tap while loading does not send a second request', (
      tester,
    ) async {
      await _bigScreen(tester);
      final pending = Completer<AuthFlowResult<RegisterOutcome>>();
      final auth = _FakeAuth()..onRegister = (_) => pending.future;
      final h = _Harness(auth);
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await _fillRegisterForm(tester);
      await _tapRegister(tester);
      await tester.pump();
      // While loading the button is disabled (and _register itself guards).
      final button = tester.widget<FilledButton>(
        find.byType(FilledButton).last,
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();

      expect(auth.registers, hasLength(1));
      pending.complete(_verificationRequired());
      await tester.pumpAndSettle();
    });
  });

  group('VERIFY EMAIL', () {
    Future<_Harness> openVerify(
      WidgetTester tester,
      _FakeAuth auth, {
      int resend = 60,
      ThemeData? theme,
      double width = 800,
      bool fromLogin = false,
    }) async {
      await _bigScreen(tester, width: width);
      final h = _Harness(auth, initial: '/other');
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app(theme: theme));
      await tester.pumpAndSettle();
      h.router.go(
        '/verify-email',
        extra: VerifyEmailArgs(
          email: 'juan@example.com',
          resendAvailableInSeconds: resend,
          fromLogin: fromLogin,
        ),
      );
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('correct code verifies and moves to home', (tester) async {
      final auth = _FakeAuth()
        ..onVerify = (_, _) async => AuthFlowResult.success(data: _user);
      await openVerify(tester, auth);

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '123456');
      await tester.tap(_primary('Verificar'));
      await tester.pumpAndSettle();

      expect(auth.verifies.single, ['juan@example.com', '123456']);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('the code field takes digits only and at most six', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await openVerify(tester, auth);

      await tester.enterText(
        find.byKey(const ValueKey('otp-field')),
        '12ab34567890',
      );
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('otp-field')),
      );
      expect(field.controller!.text, '123456');
      expect(field.keyboardType, TextInputType.number);
    });

    testWidgets('wrong code and expired code show the typed error and stay', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..onVerify = (_, _) async => AuthFlowResult.failure(
          AuthFailureKind.invalidCode,
          authInvalidCodeMessage,
        );
      await openVerify(tester, auth);

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '000000');
      await tester.tap(_primary('Verificar'));
      await tester.pumpAndSettle();
      expect(find.text(authInvalidCodeMessage), findsOneWidget);
      expect(find.text('HOME'), findsNothing);

      // Expired is the same typed outcome (the server does not distinguish).
      await tester.enterText(find.byKey(const ValueKey('otp-field')), '111111');
      await tester.pump();
      expect(find.text(authInvalidCodeMessage), findsNothing);
      await tester.tap(_primary('Verificar'));
      await tester.pumpAndSettle();
      expect(find.text(authInvalidCodeMessage), findsOneWidget);
      expect(auth.verifies, hasLength(2));
    });

    testWidgets('incomplete code is not sent', (tester) async {
      final auth = _FakeAuth();
      await openVerify(tester, auth);

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '123');
      await tester.tap(_primary('Verificar'));
      await tester.pump();

      expect(auth.verifies, isEmpty);
      expect(find.byKey(const ValueKey('auth-inline-error')), findsOneWidget);
    });

    testWidgets('resend is disabled during the cooldown, then works', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..onResend = (_) async => AuthFlowResult.success(
          data: const ResendAck(
            resendAvailableInSeconds: 60,
            codeExpiresInSeconds: 600,
          ),
        );
      await openVerify(tester, auth, resend: 30);

      OutlinedButton resendButton() => tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Reenviar c\u00f3digo'),
      );
      expect(resendButton().onPressed, isNull);
      expect(find.textContaining('0:30'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      expect(find.textContaining('0:20'), findsOneWidget);
      expect(resendButton().onPressed, isNull);

      await tester.pump(const Duration(seconds: 20));
      expect(
        find.text('Puedes solicitar un nuevo c\u00f3digo.'),
        findsOneWidget,
      );
      expect(resendButton().onPressed, isNotNull);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Reenviar c\u00f3digo'),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(auth.resends, 1);
      // A new cooldown starts from the server value.
      expect(resendButton().onPressed, isNull);
      expect(find.textContaining('1:00'), findsOneWidget);
    });

    testWidgets('resend hitting 429 uses Retry-After as the new cooldown', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..onResend = (_) async => AuthFlowResult.failure(
          AuthFailureKind.rateLimited,
          authRateLimitedMessage,
          retryAfterSeconds: 45,
        );
      await openVerify(tester, auth, resend: 0);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Reenviar c\u00f3digo'),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text(authRateLimitedMessage), findsOneWidget);
      expect(find.textContaining('0:45'), findsOneWidget);
    });

    testWidgets('verify 429 shows the useful message', (tester) async {
      final auth = _FakeAuth()
        ..onVerify = (_, _) async => AuthFlowResult.failure(
          AuthFailureKind.rateLimited,
          authRateLimitedMessage,
        );
      await openVerify(tester, auth);

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '123456');
      await tester.tap(_primary('Verificar'));
      await tester.pumpAndSettle();

      expect(find.text(authRateLimitedMessage), findsOneWidget);
    });

    testWidgets('the e-mail is kept when the network fails and retry works', (
      tester,
    ) async {
      var calls = 0;
      final auth = _FakeAuth()
        ..onVerify = (_, _) async {
          calls++;
          return calls == 1
              ? AuthFlowResult.failure(
                  AuthFailureKind.network,
                  authNetworkMessage,
                )
              : AuthFlowResult.success(data: _user);
        };
      await openVerify(tester, auth);

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '123456');
      await tester.tap(_primary('Verificar'));
      await tester.pumpAndSettle();
      expect(find.text(authNetworkMessage), findsOneWidget);
      expect(find.textContaining('j***@example.com'), findsOneWidget);

      await tester.tap(_primary('Verificar'));
      await tester.pumpAndSettle();
      expect(auth.verifies.map((v) => v[0]).toSet(), {'juan@example.com'});
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('changing e-mail goes back to the register form', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await openVerify(tester, auth);

      await tester.tap(find.byKey(const ValueKey('change-email')));
      await tester.pumpAndSettle();

      expect(find.text('Crear cuenta'), findsWidgets);
    });

    testWidgets('page removed while verifying does not crash', (tester) async {
      final pending = Completer<AuthFlowResult<AuthUser>>();
      final auth = _FakeAuth()..onVerify = (_, _) => pending.future;
      final h = await openVerify(tester, auth);

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '123456');
      await tester.tap(_primary('Verificar'));
      await tester.pump();
      h.router.go('/other');
      await tester.pumpAndSettle();
      pending.complete(AuthFlowResult.success(data: _user));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('OTHER'), findsOneWidget);
    });
  });

  group('LOGIN', () {
    testWidgets(
      'EMAIL_VERIFICATION_REQUIRED redirects to the challenge and clears the password',
      (tester) async {
        await _bigScreen(tester);
        final auth = _FakeAuth()
          ..onLogin = (_, _) async => LoginResult.verificationRequired();
        final h = _Harness(auth, initial: '/login');
        addTearDown(h.source.dispose);
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'juan@example.com');
        await tester.enterText(fields.at(1), 'Password-123');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Iniciar sesi\u00f3n'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Revisa tu correo'), findsOneWidget);
        expect(find.textContaining('j***@example.com'), findsOneWidget);
        expect(find.text('Volver a iniciar sesi\u00f3n'), findsOneWidget);
      },
    );

    testWidgets(
      'login page removed while the request is pending does not crash',
      (tester) async {
        await _bigScreen(tester);
        final pending = Completer<LoginResult>();
        final auth = _FakeAuth()..onLogin = (_, _) => pending.future;
        final h = _Harness(auth, initial: '/login');
        addTearDown(h.source.dispose);
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'juan@example.com');
        await tester.enterText(fields.at(1), 'Password-123');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Iniciar sesi\u00f3n'),
        );
        await tester.pump();
        h.router.go('/other');
        await tester.pumpAndSettle();
        pending.complete(LoginResult.failure('Invalid email or password'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('wrong password still shows the failure snackbar', (
      tester,
    ) async {
      await _bigScreen(tester);
      final auth = _FakeAuth()
        ..onLogin = (_, _) async =>
            LoginResult.failure('Credenciales incorrectas');
      final h = _Harness(auth, initial: '/login');
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'juan@example.com');
      await tester.enterText(fields.at(1), 'x');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Iniciar sesi\u00f3n'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Credenciales incorrectas'), findsOneWidget);
    });

    testWidgets('forgot-password link opens the recovery screen', (
      tester,
    ) async {
      await _bigScreen(tester);
      final auth = _FakeAuth();
      final h = _Harness(auth, initial: '/login');
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('forgot-password-link')),
      );
      await tester.tap(find.byKey(const ValueKey('forgot-password-link')));
      await tester.pumpAndSettle();

      expect(find.text('\u00bfOlvidaste tu contrase\u00f1a?'), findsWidgets);
      expect(find.byKey(const ValueKey('forgot-email')), findsOneWidget);
    });
  });

  group('FORGOT / RESET PASSWORD', () {
    testWidgets('forgot -> reset -> login with neutral copy', (tester) async {
      await _bigScreen(tester);
      final auth = _FakeAuth()
        ..onForgot = (_) async => AuthFlowResult.success(
          data: const ResendAck(
            resendAvailableInSeconds: 60,
            codeExpiresInSeconds: 600,
          ),
        );
      auth.onReset = (_, _, _) async => AuthFlowResult.success();
      final h = _Harness(auth, initial: '/other');
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      h.router.go('/forgot-password');
      await tester.pumpAndSettle();

      // The request screen never claims the account exists.
      expect(
        find.textContaining('Si existe una cuenta asociada'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('forgot-email')),
        'Juan@Example.com',
      );
      await tester.tap(_primary('Enviar c\u00f3digo'));
      await tester.pumpAndSettle();

      expect(auth.forgots, 1);
      expect(find.text('Nueva contrase\u00f1a'), findsWidgets);

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '654321');
      await tester.enterText(
        find.byKey(const ValueKey('reset-password')),
        'Brand-New-Pass-9',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm')),
        'Brand-New-Pass-9',
      );
      await tester.ensureVisible(_primary('Cambiar contrase\u00f1a'));
      await tester.tap(_primary('Cambiar contrase\u00f1a'));
      await tester.pumpAndSettle();

      expect(auth.resets.single, [
        'juan@example.com',
        '654321',
        'Brand-New-Pass-9',
      ]);
      // Back on the login screen with the confirmation.
      expect(
        find.widgetWithText(FilledButton, 'Iniciar sesi\u00f3n'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Contrase\u00f1a actualizada'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reset success does not hang if the route is left mid-await', (
      tester,
    ) async {
      await _bigScreen(tester);
      final gate = Completer<AuthFlowResult<void>>();
      final auth = _FakeAuth()..onReset = (_, _, _) => gate.future;
      final h = _Harness(auth, initial: '/other');
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      h.router.go(
        '/reset-password',
        extra: const ResetPasswordArgs(email: 'juan@example.com'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '654321');
      await tester.enterText(
        find.byKey(const ValueKey('reset-password')),
        'Brand-New-Pass-9',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm')),
        'Brand-New-Pass-9',
      );
      await tester.ensureVisible(_primary('Cambiar contrase\u00f1a'));
      await tester.tap(_primary('Cambiar contrase\u00f1a'));
      await tester.pump();

      // Leave while the request is still in flight.
      h.router.go('/login');
      await tester.pumpAndSettle();
      gate.complete(AuthFlowResult.success());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithText(FilledButton, 'Iniciar sesi\u00f3n'),
        findsOneWidget,
      );
    });

    testWidgets('reset validates the same rules as register before calling', (
      tester,
    ) async {
      await _bigScreen(tester);
      final auth = _FakeAuth();
      final h = _Harness(auth, initial: '/other');
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      h.router.go(
        '/reset-password',
        extra: const ResetPasswordArgs(email: 'juan@example.com'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '654321');
      await tester.enterText(
        find.byKey(const ValueKey('reset-password')),
        'short',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm')),
        'different',
      );
      await tester.ensureVisible(_primary('Cambiar contrase\u00f1a'));
      await tester.tap(_primary('Cambiar contrase\u00f1a'));
      await tester.pump();

      expect(auth.resets, isEmpty);
      expect(find.textContaining('m\u00ednimo 8 caracteres'), findsOneWidget);
      expect(find.text('Entre 8 y 120 caracteres.'), findsOneWidget);
    });

    testWidgets('wrong or expired reset code and 429 are shown inline', (
      tester,
    ) async {
      await _bigScreen(tester);
      final auth = _FakeAuth()
        ..onReset = (_, _, _) async => AuthFlowResult.failure(
          AuthFailureKind.invalidCode,
          authInvalidCodeMessage,
        );
      final h = _Harness(auth, initial: '/other');
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      h.router.go(
        '/reset-password',
        extra: const ResetPasswordArgs(email: 'juan@example.com'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '000000');
      await tester.enterText(
        find.byKey(const ValueKey('reset-password')),
        'Brand-New-Pass-9',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reset-confirm')),
        'Brand-New-Pass-9',
      );
      await tester.ensureVisible(_primary('Cambiar contrase\u00f1a'));
      await tester.tap(_primary('Cambiar contrase\u00f1a'));
      await tester.pumpAndSettle();
      expect(find.text(authInvalidCodeMessage), findsOneWidget);

      auth.onReset = (_, _, _) async => AuthFlowResult.failure(
        AuthFailureKind.rateLimited,
        authRateLimitedMessage,
      );
      await tester.tap(_primary('Cambiar contrase\u00f1a'));
      await tester.pumpAndSettle();
      expect(find.text(authRateLimitedMessage), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await _bigScreen(tester);
      final auth = _FakeAuth();
      final h = _Harness(auth, initial: '/other');
      addTearDown(h.source.dispose);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      h.router.go(
        '/reset-password',
        extra: const ResetPasswordArgs(email: 'juan@example.com'),
      );
      await tester.pumpAndSettle();

      EditableText editable() => tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('reset-password')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable().obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility_outlined).first);
      await tester.pump();
      expect(editable().obscureText, isFalse);
    });
  });

  group('LAYOUT AND THEMES', () {
    for (final width in [220.0, 320.0]) {
      testWidgets('verify, forgot and reset fit a ${width.toInt()} px screen', (
        tester,
      ) async {
        final auth = _FakeAuth();
        await _bigScreen(tester, width: width);
        final h = _Harness(auth, initial: '/other');
        addTearDown(h.source.dispose);
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();

        h.router.go(
          '/verify-email',
          extra: const VerifyEmailArgs(email: 'juan@example.com'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Revisa tu correo'), findsOneWidget);
        expect(tester.takeException(), isNull);

        h.router.go('/forgot-password');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        h.router.go(
          '/reset-password',
          extra: const ResetPasswordArgs(email: 'juan@example.com'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    for (final dark in [true, false]) {
      testWidgets('verify screen follows ${dark ? 'Noche' : 'Crema'}', (
        tester,
      ) async {
        final auth = _FakeAuth();
        await _bigScreen(tester);
        final h = _Harness(auth, initial: '/other');
        addTearDown(h.source.dispose);
        final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        await tester.pumpWidget(h.app(theme: theme));
        await tester.pumpAndSettle();
        h.router.go(
          '/verify-email',
          extra: const VerifyEmailArgs(email: 'juan@example.com'),
        );
        await tester.pumpAndSettle();

        final expected = dark
            ? GarraSemanticColors.noche
            : GarraSemanticColors.crema;
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
        expect(scaffold.backgroundColor, expected.background);
        expect(
          tester.widget<Text>(find.text('Revisa tu correo')).style?.color,
          expected.textPrimary,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('AuthService (typed contract, HTTP level)', () {
    late SecureStorageService storage;

    Dio dioReturning(
      Response<dynamic> Function(RequestOptions) answer, {
      DioException Function(RequestOptions)? fail,
      List<RequestOptions>? sink,
    }) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sink?.add(options);
            if (fail != null) return handler.reject(fail(options));
            return handler.resolve(answer(options));
          },
        ),
      );
      return dio;
    }

    DioException status(
      RequestOptions o,
      int code,
      Map<String, dynamic> body, {
      Map<String, List<String>>? headers,
    }) => DioException(
      requestOptions: o,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: o,
        statusCode: code,
        data: body,
        headers: Headers.fromMap(headers ?? {}),
      ),
    );

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      storage = SecureStorageService();
    });

    test('register parses the typed flag and never reads tokens', () async {
      final service = AuthService(
        storage: storage,
        dio: dioReturning(
          (o) => Response(
            requestOptions: o,
            statusCode: 201,
            data: {
              'success': true,
              'message': 'ok',
              'data': {
                'token': null,
                'verificationRequired': true,
                'email': 'juan@example.com',
                'emailMasked': 'j***@example.com',
                'resendAvailableInSeconds': 60,
                'codeExpiresInSeconds': 600,
              },
            },
          ),
        ),
      );
      final result = await service.register(
        const RegisterRequest(
          email: 'juan@example.com',
          username: 'juanp',
          password: 'Password-123',
          fullName: 'Juan',
          favoriteStand: 'Norte',
        ),
      );
      expect(result.success, isTrue);
      expect(result.data!.verificationRequired, isTrue);
      expect(result.data!.resendAvailableInSeconds, 60);
      expect(await storage.getToken(), isNull);
    });

    test(
      'register failure kinds: duplicate, 429 with Retry-After, network',
      () async {
        const request = RegisterRequest(
          email: 'a@b.co',
          username: 'abcd',
          password: 'Password-123',
          fullName: 'Abc',
          favoriteStand: 'Sur',
        );
        var service = AuthService(
          storage: storage,
          dio: dioReturning(
            (o) => throw StateError('unused'),
            fail: (o) => status(o, 400, {
              'success': false,
              'message': 'Email is already registered',
            }),
          ),
        );
        var result = await service.register(request);
        expect(result.kind, AuthFailureKind.conflict);
        expect(result.message, 'Este correo ya est\u00e1 registrado');

        service = AuthService(
          storage: storage,
          dio: dioReturning(
            (o) => throw StateError('unused'),
            fail: (o) => status(
              o,
              429,
              {'success': false, 'message': 'x'},
              headers: {
                'retry-after': ['90'],
              },
            ),
          ),
        );
        result = await service.register(request);
        expect(result.kind, AuthFailureKind.rateLimited);
        expect(result.retryAfterSeconds, 90);
        expect(result.message, authRateLimitedMessage);

        service = AuthService(
          storage: storage,
          dio: dioReturning(
            (o) => throw StateError('unused'),
            fail: (o) => DioException(
              requestOptions: o,
              type: DioExceptionType.connectionError,
            ),
          ),
        );
        result = await service.register(request);
        expect(result.kind, AuthFailureKind.network);
      },
    );

    test(
      'register 503 EMAIL_DELIVERY_UNAVAILABLE maps to the typed outcome',
      () async {
        const request = RegisterRequest(
          email: 'a@b.co',
          username: 'abcd',
          password: 'Password-123',
          fullName: 'Abc',
          favoriteStand: 'Sur',
        );
        final service = AuthService(
          storage: storage,
          dio: dioReturning(
            (o) => throw StateError('unused'),
            fail: (o) => status(o, 503, {
              'success': false,
              'message': 'x',
              'errors': {'code': 'EMAIL_DELIVERY_UNAVAILABLE'},
            }),
          ),
        );
        final result = await service.register(request);
        expect(result.success, isFalse);
        expect(result.kind, AuthFailureKind.emailUnavailable);
        expect(result.message, authEmailUnavailableMessage);
        expect(await storage.getToken(), isNull);
      },
    );

    test(
      'verifyEmail persists the session and sends only email+code',
      () async {
        final sent = <RequestOptions>[];
        final service = AuthService(
          storage: storage,
          dio: dioReturning(
            sink: sent,
            (o) => Response(
              requestOptions: o,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'token': 'access-1',
                  'refreshToken': 'refresh-1',
                  'userId': 'u1',
                  'email': 'juan@example.com',
                  'username': 'juanp',
                  'fullName': 'Juan',
                  'status': 'ACTIVE',
                  'role': 'USER',
                },
              },
            ),
          ),
        );
        final result = await service.verifyEmail(
          email: ' Juan@Example.com ',
          code: '123456',
        );
        expect(result.success, isTrue);
        expect(result.data!.userId, 'u1');
        expect(await storage.getToken(), 'access-1');
        expect(await storage.getRefreshToken(), 'refresh-1');
        expect(sent.single.path, '/auth/email-verification/verify');
        expect(sent.single.data, {
          'email': 'juan@example.com',
          'code': '123456',
        });
      },
    );

    test('verifyEmail INVALID_CODE is typed and stores nothing', () async {
      final service = AuthService(
        storage: storage,
        dio: dioReturning(
          (o) => throw StateError('unused'),
          fail: (o) => status(o, 400, {
            'success': false,
            'message': 'x',
            'errors': {'code': 'INVALID_CODE'},
          }),
        ),
      );
      final result = await service.verifyEmail(email: 'a@b.co', code: '000000');
      expect(result.kind, AuthFailureKind.invalidCode);
      expect(await storage.getToken(), isNull);
    });

    test('login 403 with the typed code means verification required', () async {
      final service = AuthService(
        storage: storage,
        dio: dioReturning(
          (o) => throw StateError('unused'),
          fail: (o) => status(o, 403, {
            'success': false,
            'message': 'texto cualquiera',
            'errors': {'code': 'EMAIL_VERIFICATION_REQUIRED'},
          }),
        ),
      );
      final result = await service.login(email: 'a@b.co', password: 'x');
      expect(result.success, isFalse);
      expect(result.requiresEmailVerification, isTrue);
      expect(await storage.getToken(), isNull);
    });

    test(
      'a 403 without the typed code is NOT treated as verification',
      () async {
        final service = AuthService(
          storage: storage,
          dio: dioReturning(
            (o) => throw StateError('unused'),
            fail: (o) => status(o, 403, {
              'success': false,
              'message': 'Email verification required (just text)',
            }),
          ),
        );
        final result = await service.login(email: 'a@b.co', password: 'x');
        expect(result.requiresEmailVerification, isFalse);
      },
    );

    test(
      'forgot/resend answer the neutral ack and reset sends the password once',
      () async {
        final sent = <RequestOptions>[];
        final service = AuthService(
          storage: storage,
          dio: dioReturning(
            sink: sent,
            (o) => Response(
              requestOptions: o,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'message': authNeutralAcceptedMessage,
                  'resendAvailableInSeconds': 60,
                  'codeExpiresInSeconds': 600,
                },
              },
            ),
          ),
        );
        final forgot = await service.forgotPassword('Juan@Example.com');
        expect(forgot.success, isTrue);
        expect(forgot.data!.resendAvailableInSeconds, 60);
        final resend = await service.resendVerification('juan@example.com');
        expect(resend.success, isTrue);
        final reset = await service.resetPassword(
          email: 'juan@example.com',
          code: '123456',
          newPassword: 'Brand-New-Pass-9',
        );
        expect(reset.success, isTrue);
        expect(sent.map((o) => o.path), [
          '/auth/password/forgot',
          '/auth/email-verification/resend',
          '/auth/password/reset',
        ]);
        expect(sent.first.data, {'email': 'juan@example.com'});
        expect(sent.last.data, {
          'email': 'juan@example.com',
          'code': '123456',
          'newPassword': 'Brand-New-Pass-9',
        });
        // No session is started by a reset.
        expect(await storage.getToken(), isNull);
      },
    );

    test('maskEmail hides the local part', () {
      expect(maskEmail('juan@example.com'), 'j***@example.com');
      expect(maskEmail('nope'), '***');
    });
  });
}
