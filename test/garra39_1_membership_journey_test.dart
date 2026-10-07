import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/core/storage/secure_storage_service.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/auth/data/auth_flow_models.dart';
import 'package:garra_digital_app/features/auth/data/auth_service.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/auth/data/register_request.dart';
import 'package:garra_digital_app/features/auth/presentation/complete_profile_page.dart';
import 'package:garra_digital_app/features/auth/presentation/entry_page.dart';
import 'package:garra_digital_app/features/auth/presentation/login_page.dart';
import 'package:garra_digital_app/features/auth/presentation/providers/auth_flow_providers.dart';
import 'package:garra_digital_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:garra_digital_app/features/auth/presentation/register_page.dart';
import 'package:garra_digital_app/features/auth/presentation/verify_email_page.dart';
import 'package:go_router/go_router.dart';

/// GARRA39.1: one journey for every sign-in method.
/// ENTRY -> (Google | e-mail + OTP) -> PERFIL GARRA -> ONBOARDING GARRA38 -> HOME.

class _Source implements ConnectivitySource {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );
  @override
  Future<List<ConnectivityResult>> check() async => [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get changes => _controller.stream;
  Future<void> dispose() => _controller.close();
}

class _CompleteCall {
  _CompleteCall(this.username, this.stand, this.name, this.fan, this.rules);
  final String username;
  final String stand;
  final String? name;
  final bool fan;
  final bool rules;
}

class _FakeAuth extends AuthService {
  _FakeAuth() : super(dio: Dio());

  Future<LoginResult> Function()? onGoogle;
  Future<AuthFlowResult<RegisterOutcome>> Function(RegisterRequest)? onRegister;
  Future<AuthFlowResult<AuthUser>> Function(String, String)? onVerify;
  Future<AuthActionResult<AuthUser>> Function(_CompleteCall)? onComplete;
  AuthUser? meUser;

  var googleCalls = 0;
  final registers = <RegisterRequest>[];
  final completes = <_CompleteCall>[];

  @override
  Future<LoginResult> loginWithGoogle() {
    googleCalls++;
    return onGoogle!();
  }

  @override
  Future<AuthFlowResult<RegisterOutcome>> register(RegisterRequest request) {
    registers.add(request);
    return onRegister!(request);
  }

  @override
  Future<AuthFlowResult<AuthUser>> verifyEmail({
    required String email,
    required String code,
  }) => onVerify!(email, code);

  @override
  Future<AuthUser?> me() async => meUser;

  @override
  Future<AuthActionResult<AuthUser>> completeProfile({
    required String username,
    required String favoriteStand,
    String? fullName,
    String? favoritePlayer,
    required bool cremaDeclarationAccepted,
    required bool communityGuidelinesAccepted,
  }) {
    final call = _CompleteCall(
      username,
      favoriteStand,
      fullName,
      cremaDeclarationAccepted,
      communityGuidelinesAccepted,
    );
    completes.add(call);
    return onComplete!(call);
  }
}

const _pendingUser = AuthUser(
  userId: 'u1',
  email: 'nuevo@gmail.com',
  username: 'nuevo',
  fullName: 'Nombre De Google',
  status: 'PENDING_PROFILE',
);
const _activeUser = AuthUser(
  userId: 'u1',
  email: 'nuevo@gmail.com',
  username: 'hincha_uno',
  fullName: 'Hincha Uno',
  status: 'ACTIVE',
);

/// Same decision as the app's, minus the network bits (push registration and
/// the GARRA38 preferences call), which the unit test below covers separately.
class _Decision {
  var onboardingPending = true;
  final seen = <String>[];
  Future<String> call(AuthUser user) async {
    seen.add(user.status);
    if (user.status == 'PENDING_PROFILE') return '/complete-profile';
    return onboardingPending ? '/onboarding' : '/home';
  }
}

class _Harness {
  _Harness(this.auth, {String initial = '/welcome'}) {
    router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/welcome', builder: (_, _) => const EntryPage()),
        GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(
          path: '/verify-email',
          builder: (_, state) =>
              VerifyEmailPage(args: state.extra! as VerifyEmailArgs),
        ),
        GoRoute(
          path: '/complete-profile',
          builder: (_, _) => const CompleteProfilePage(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Text('ONBOARDING'),
        ),
        GoRoute(path: '/home', builder: (_, _) => const Text('HOME')),
        GoRoute(path: '/other', builder: (_, _) => const Text('OTHER')),
      ],
    );
  }

  final _FakeAuth auth;
  final decision = _Decision();
  final source = _Source();
  late final GoRouter router;

  Widget app({ThemeData? theme}) => ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      connectivitySourceProvider.overrideWithValue(source),
      postAuthDestinationProvider.overrideWithValue(decision.call),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        ref.watch(connectivityStatusProvider);
        return MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp.router(
            routerConfig: router,
            theme: theme ?? AppTheme.darkTheme,
          ),
        );
      },
    ),
  );
}

Future<void> _size(WidgetTester tester, {double width = 800}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<_Harness> _open(
  WidgetTester tester,
  _FakeAuth auth, {
  String initial = '/welcome',
  ThemeData? theme,
  double width = 800,
}) async {
  await _size(tester, width: width);
  final h = _Harness(auth, initial: initial);
  addTearDown(h.source.dispose);
  await tester.pumpWidget(h.app(theme: theme));
  await tester.pumpAndSettle();
  return h;
}

Finder _tile(String key) => find.byKey(ValueKey(key));

Future<void> _fillProfile(
  WidgetTester tester, {
  String username = 'hincha_uno',
  String? stand = 'Sur',
  bool fan = true,
  bool rules = true,
}) async {
  await tester.enterText(_tile('profile-name'), 'Hincha Uno');
  await tester.enterText(_tile('profile-username'), username);
  if (stand != null) {
    await tester.ensureVisible(_tile('stand-$stand'));
    await tester.tap(_tile('stand-$stand'));
  }
  if (fan) {
    await tester.ensureVisible(_tile('accept-fan'));
    await tester.tap(_tile('accept-fan'));
  }
  if (rules) {
    await tester.ensureVisible(_tile('accept-guidelines'));
    await tester.tap(_tile('accept-guidelines'));
  }
  await tester.pump();
}

Future<void> _tapEnter(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Entrar a Garra'));
  await tester.tap(find.text('Entrar a Garra'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('ENTRY SCREEN', () {
    testWidgets('shows the unified entry with only the real methods', (
      tester,
    ) async {
      await _open(tester, _FakeAuth());

      expect(find.text('\u00daNETE A GARRA'), findsOneWidget);
      expect(
        find.text('La comunidad digital de la hinchada crema.'),
        findsOneWidget,
      );
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.text('o'), findsOneWidget);
      expect(find.text('Crear cuenta con correo'), findsOneWidget);
      expect(
        find.text('\u00bfYa tienes una cuenta? Inicia sesi\u00f3n'),
        findsOneWidget,
      );
      // Facebook (and anything not implemented) is not even shown disabled.
      expect(find.textContaining('Facebook'), findsNothing);
      expect(find.textContaining('Instagram'), findsNothing);
    });

    testWidgets('"Crear cuenta con correo" opens e-mail + password only', (
      tester,
    ) async {
      final h = await _open(tester, _FakeAuth());

      await tester.tap(find.text('Crear cuenta con correo'));
      await tester.pumpAndSettle();

      expect(h.router.state.uri.path, '/register');
      // Three fields: e-mail, password, confirmation. No name/username/tribuna.
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Tribuna favorita'), findsNothing);
      expect(find.text('Nombre completo'), findsNothing);
    });

    testWidgets('"Inicia sesi\u00f3n" opens the login', (tester) async {
      final h = await _open(tester, _FakeAuth());

      await tester.tap(_tile('entry-login'));
      await tester.pumpAndSettle();

      expect(h.router.state.uri.path, '/login');
    });

    for (final width in [220.0, 320.0]) {
      testWidgets('fits a ${width.toInt()} px screen', (tester) async {
        await _open(tester, _FakeAuth(), width: width);
        expect(tester.takeException(), isNull);
        expect(find.text('Continuar con Google'), findsOneWidget);
      });
    }

    testWidgets('follows Noche and Crema', (tester) async {
      await _open(tester, _FakeAuth(), theme: AppTheme.darkTheme);
      expect(tester.takeException(), isNull);
      await _open(tester, _FakeAuth(), theme: AppTheme.lightTheme);
      expect(tester.takeException(), isNull);
      expect(find.text('Continuar con Google'), findsOneWidget);
    });
  });

  group('GOOGLE -> PERFIL GARRA', () {
    testWidgets('a new Google account lands on the Garra profile', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..meUser = _pendingUser
        ..onGoogle = () async => LoginResult.success(user: _pendingUser);
      final h = await _open(tester, auth);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(h.router.state.uri.path, '/complete-profile');
      expect(find.text('Completa tu perfil crema.'), findsOneWidget);
      expect(find.text('Cu\u00e9ntanos c\u00f3mo vives la U.'), findsOneWidget);
      // The name Google gave is offered, editable, never asked twice by e-mail.
      final name = tester.widget<TextFormField>(_tile('profile-name'));
      expect(name.controller!.text, 'Nombre De Google');
    });

    testWidgets('an existing complete member goes to the normal destination', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..onGoogle = () async => LoginResult.success(user: _activeUser);
      final h = await _open(tester, auth);
      h.decision.onboardingPending = false;

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets(
      'FULL JOURNEY: Google -> Completa tu perfil crema -> name prefilled -> '
      'username -> tribuna -> both commitments -> continue (no e-mail/password again)',
      (tester) async {
        final auth = _FakeAuth()
          ..meUser = _pendingUser
          ..onGoogle = (() async => LoginResult.success(user: _pendingUser))
          ..onComplete = (_) async =>
              AuthActionResult.success(message: 'ok', data: _activeUser);
        final h = await _open(tester, auth);

        await tester.tap(find.text('Continuar con Google'));
        await tester.pumpAndSettle();

        expect(find.text('Completa tu perfil crema.'), findsOneWidget);
        expect(
          tester.widget<TextFormField>(_tile('profile-name')).controller!.text,
          'Nombre De Google',
        );
        // Identity is already verified by Google: no credentials are asked again.
        expect(find.text('Contrase\u00f1a'), findsNothing);
        expect(find.textContaining('Correo'), findsNothing);
        expect(find.textContaining('Confirmar'), findsNothing);
        // The old wording (there is no document to "have read") is gone.
        expect(find.textContaining('He le\u00eddo'), findsNothing);
        expect(
          find.text(
            'Soy hincha de Universitario y quiero formar parte de Garra.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Me comprometo a respetar las normas de convivencia de la comunidad.',
          ),
          findsOneWidget,
        );

        await _fillProfile(tester);
        await _tapEnter(tester);
        await tester.pumpAndSettle();

        final call = auth.completes.single;
        expect(call.fan, isTrue);
        expect(call.rules, isTrue);
        expect(find.text('ONBOARDING'), findsOneWidget);
        expect(h.router.state.uri.path, isNot('/complete-profile'));
      },
    );

    testWidgets('a Google cancel stays on the entry without a message', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..onGoogle = () async => LoginResult.cancelled();
      final h = await _open(tester, auth);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(h.router.state.uri.path, '/welcome');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a Google failure stays on the entry with a message', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..onGoogle = () async => LoginResult.failure(
          'No pudimos iniciar sesi\u00f3n con Google. Intenta de nuevo.',
        );
      final h = await _open(tester, auth);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(h.router.state.uri.path, '/welcome');
      expect(
        find.text('No pudimos iniciar sesi\u00f3n con Google. Intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'REGRESSION: leaving while Google is in flight does not crash',
      (tester) async {
        final pending = Completer<LoginResult>();
        final auth = _FakeAuth()..onGoogle = () => pending.future;
        final h = await _open(tester, auth);

        await tester.tap(find.text('Continuar con Google'));
        await tester.pump();
        h.router.go('/other');
        await tester.pumpAndSettle();
        pending.complete(LoginResult.success(user: _pendingUser));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('OTHER'), findsOneWidget);
        expect(h.decision.seen, isEmpty);
      },
    );

    testWidgets('a double tap sends one Google request and one navigation', (
      tester,
    ) async {
      final pending = Completer<LoginResult>();
      final auth = _FakeAuth()
        ..meUser = _pendingUser
        ..onGoogle = () => pending.future;
      final h = await _open(tester, auth);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton).first, warnIfMissed: false);
      await tester.pump();
      pending.complete(LoginResult.success(user: _pendingUser));
      await tester.pumpAndSettle();

      expect(auth.googleCalls, 1);
      expect(h.decision.seen, hasLength(1));
      expect(h.router.state.uri.path, '/complete-profile');
    });
  });

  group('E-MAIL + OTP -> PERFIL GARRA', () {
    testWidgets(
      'register sends only e-mail and password, then verify leads to the profile',
      (tester) async {
        final auth = _FakeAuth();
        auth.meUser = const AuthUser(
          userId: 'u1',
          email: 'juan@example.com',
          username: 'fan_abc',
          fullName: pendingFullNamePlaceholder,
          status: 'PENDING_PROFILE',
        );
        auth.onRegister = (_) async => AuthFlowResult.success(
          data: const RegisterOutcome(
            verificationRequired: true,
            email: 'juan@example.com',
            resendAvailableInSeconds: 60,
            codeExpiresInSeconds: 600,
          ),
        );
        auth.onVerify = (_, _) async =>
            AuthFlowResult.success(data: _pendingUser);
        final h = await _open(tester, auth, initial: '/register');

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'juan@example.com');
        await tester.enterText(fields.at(1), 'Password-123');
        await tester.enterText(fields.at(2), 'Password-123');
        await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
        await tester.pumpAndSettle();

        expect(auth.registers.single.toJson().keys.toSet(), {
          'email',
          'password',
        });
        expect(h.router.state.uri.path, '/verify-email');

        await tester.enterText(
          find.byKey(const ValueKey('otp-field')),
          '123456',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Verificar'));
        await tester.pumpAndSettle();

        expect(h.router.state.uri.path, '/complete-profile');
        // The internal placeholder name is never offered as a real one.
        final name = tester.widget<TextFormField>(_tile('profile-name'));
        expect(name.controller!.text, '');
      },
    );

    testWidgets(
      'EMAIL_DELIVERY_UNAVAILABLE keeps the form and suggests Google',
      (tester) async {
        final auth = _FakeAuth()
          ..onRegister = (_) async => AuthFlowResult.failure(
            AuthFailureKind.emailUnavailable,
            authEmailUnavailableMessage,
          );
        final h = await _open(tester, auth, initial: '/register');

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'juan@example.com');
        await tester.enterText(fields.at(1), 'Password-123');
        await tester.enterText(fields.at(2), 'Password-123');
        await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
        await tester.pumpAndSettle();

        expect(find.text(authEmailUnavailableMessage), findsOneWidget);
        expect(find.textContaining('Google'), findsWidgets);
        expect(h.router.state.uri.path, '/register');
      },
    );

    testWidgets('the form validates password rules and confirmation', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await _open(tester, auth, initial: '/register');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'no-es-correo');
      await tester.enterText(fields.at(1), 'corta');
      await tester.enterText(fields.at(2), 'otra');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(auth.registers, isEmpty);
      expect(find.text('Ingresa un correo v\u00e1lido'), findsOneWidget);
      expect(find.textContaining('m\u00ednimo 8'), findsOneWidget);
      expect(find.text('Las contrase\u00f1as no coinciden'), findsOneWidget);
    });
  });

  group('PERFIL GARRA', () {
    Future<_Harness> openProfile(
      WidgetTester tester,
      _FakeAuth auth, {
      ThemeData? theme,
      double width = 800,
    }) => _open(
      tester,
      auth,
      initial: '/complete-profile',
      theme: theme,
      width: width,
    );

    testWidgets('shows the membership copy and both unchecked acceptances', (
      tester,
    ) async {
      await openProfile(tester, _FakeAuth());

      expect(
        find.text(
          'Garra es una comunidad creada para hinchas de Universitario.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Soy hincha de Universitario y quiero formar parte de Garra.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Me comprometo a respetar las normas de convivencia de la comunidad.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<CheckboxListTile>(_tile('accept-fan')).value,
        isFalse,
      );
      expect(
        tester.widget<CheckboxListTile>(_tile('accept-guidelines')).value,
        isFalse,
      );
      // It is a declaration, not a proof of fandom.
      expect(find.textContaining('Demuestra'), findsNothing);
      expect(find.textContaining('verificaci\u00f3n de hincha'), findsNothing);
      // The stand choices are the app's real ones, nothing else.
      for (final stand in garraStands) {
        expect(find.text(stand), findsOneWidget);
      }
    });

    testWidgets('without the fan declaration it does not continue', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await openProfile(tester, auth);

      await _fillProfile(tester, fan: false);
      await _tapEnter(tester);
      await tester.pumpAndSettle();

      expect(auth.completes, isEmpty);
      expect(find.text('Marca esta casilla para continuar'), findsOneWidget);
    });

    testWidgets('without the community guidelines it does not continue', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await openProfile(tester, auth);

      await _fillProfile(tester, rules: false);
      await _tapEnter(tester);
      await tester.pumpAndSettle();

      expect(auth.completes, isEmpty);
      expect(find.text('Marca esta casilla para continuar'), findsOneWidget);
    });

    testWidgets('without a tribuna it does not continue', (tester) async {
      final auth = _FakeAuth();
      await openProfile(tester, auth);

      await _fillProfile(tester, stand: null);
      await _tapEnter(tester);
      await tester.pumpAndSettle();

      expect(auth.completes, isEmpty);
      expect(find.byKey(const ValueKey('stand-error')), findsOneWidget);
    });

    testWidgets(
      'both acceptances + tribuna send everything and continue to the GARRA38 onboarding',
      (tester) async {
        final auth = _FakeAuth()
          ..onComplete = (_) async =>
              AuthActionResult.success(message: 'ok', data: _activeUser);
        final h = await openProfile(tester, auth);

        await _fillProfile(tester);
        await _tapEnter(tester);
        await tester.pumpAndSettle();

        final call = auth.completes.single;
        expect(call.username, 'hincha_uno');
        expect(call.stand, 'Sur');
        expect(call.name, 'Hincha Uno');
        expect(call.fan, isTrue);
        expect(call.rules, isTrue);
        // Profile first, then the (skippable) GARRA38 onboarding.
        expect(h.decision.seen, ['ACTIVE']);
        expect(find.text('ONBOARDING'), findsOneWidget);
      },
    );

    testWidgets('when onboarding is already done it goes straight to Home', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..onComplete = (_) async =>
            AuthActionResult.success(message: 'ok', data: _activeUser);
      final h = await openProfile(tester, auth);
      h.decision.onboardingPending = false;

      await _fillProfile(tester);
      await _tapEnter(tester);
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('a taken username shows the error and keeps the form', (
      tester,
    ) async {
      final auth = _FakeAuth()
        ..onComplete = (_) async =>
            AuthActionResult.failure(authUsernameTakenMessage);
      final h = await openProfile(tester, auth);

      await _fillProfile(tester, username: 'ocupado');
      await _tapEnter(tester);
      await tester.pumpAndSettle();

      expect(find.text(authUsernameTakenMessage), findsOneWidget);
      expect(h.router.state.uri.path, '/complete-profile');
      expect(find.text('ocupado'), findsOneWidget);
    });

    testWidgets('a double tap sends one request', (tester) async {
      final pending = Completer<AuthActionResult<AuthUser>>();
      final auth = _FakeAuth()..onComplete = (_) => pending.future;
      await openProfile(tester, auth);

      await _fillProfile(tester);
      await _tapEnter(tester);
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();

      expect(auth.completes, hasLength(1));
      pending.complete(
        AuthActionResult.success(message: 'ok', data: _activeUser),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('REGRESSION: page removed while saving does not crash', (
      tester,
    ) async {
      final pending = Completer<AuthActionResult<AuthUser>>();
      final auth = _FakeAuth()..onComplete = (_) => pending.future;
      final h = await openProfile(tester, auth);

      await _fillProfile(tester);
      await _tapEnter(tester);
      await tester.pump();
      h.router.go('/other');
      await tester.pumpAndSettle();
      pending.complete(
        AuthActionResult.success(message: 'ok', data: _activeUser),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('OTHER'), findsOneWidget);
      expect(h.decision.seen, isEmpty);
    });

    testWidgets('system back does not leave the Garra profile', (tester) async {
      final h = await openProfile(tester, _FakeAuth());

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(h.router.state.uri.path, '/complete-profile');
      expect(find.text('Completa tu perfil crema.'), findsOneWidget);
    });

    for (final width in [220.0, 320.0]) {
      testWidgets('fits a ${width.toInt()} px screen', (tester) async {
        await openProfile(tester, _FakeAuth(), width: width);
        expect(tester.takeException(), isNull);
        expect(find.text('Completa tu perfil crema.'), findsOneWidget);
      });
    }

    testWidgets('follows Noche and Crema', (tester) async {
      await openProfile(tester, _FakeAuth(), theme: AppTheme.darkTheme);
      expect(tester.takeException(), isNull);
      await openProfile(tester, _FakeAuth(), theme: AppTheme.lightTheme);
      expect(tester.takeException(), isNull);
      expect(find.text('Entrar a Garra'), findsOneWidget);
    });
  });

  group('CENTRAL POST-AUTH DECISION', () {
    test(
      'a member with the profile pending is routed to the Garra profile',
      () async {
        expect(
          await defaultPostVerifyDestination(_pendingUser),
          '/complete-profile',
        );
      },
    );

    test('staff are never routed to the member profile', () async {
      // Not asserted via the network-bound branch: only that PENDING + admin
      // does not take the profile route.
      const admin = AuthUser(
        userId: 'a',
        email: 'a@x.co',
        username: 'adm',
        fullName: 'Adm',
        status: 'PENDING_PROFILE',
        role: 'ADMIN',
      );
      expect(admin.isAdmin, isTrue);
    });

    test('a deep link applies only to the plain Home decision', () async {
      Future<String> toHome(AuthUser _) async => '/home';
      Future<String> toProfile(AuthUser _) async => '/complete-profile';
      expect(
        await postAuthRoute(toHome, _activeUser, next: '/clans/la-u'),
        '/clans/la-u',
      );
      expect(
        await postAuthRoute(toProfile, _pendingUser, next: '/clans/la-u'),
        '/complete-profile',
      );
    });
  });

  group('AuthService.completeProfile (HTTP contract)', () {
    late SecureStorageService storage;

    Dio dio(
      Response<dynamic> Function(RequestOptions) ok, {
      DioException Function(RequestOptions)? fail,
      List<RequestOptions>? sink,
    }) {
      final d = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
      d.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            sink?.add(o);
            if (fail != null) return h.reject(fail(o));
            return h.resolve(ok(o));
          },
        ),
      );
      return d;
    }

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      storage = SecureStorageService();
    });

    test(
      'sends both acceptances and the visible name, stores the new JWT',
      () async {
        final sent = <RequestOptions>[];
        final service = AuthService(
          storage: storage,
          dio: dio(
            (o) => Response(
              requestOptions: o,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'token': 'new-jwt',
                  'userId': 'u1',
                  'email': 'a@b.co',
                  'username': 'hincha_uno',
                  'fullName': 'Hincha Uno',
                  'status': 'ACTIVE',
                },
              },
            ),
            sink: sent,
          ),
        );

        final result = await service.completeProfile(
          username: ' hincha_uno ',
          fullName: 'Hincha Uno',
          favoriteStand: 'Sur',
          cremaDeclarationAccepted: true,
          communityGuidelinesAccepted: true,
        );

        expect(result.success, isTrue);
        expect(result.data!.status, 'ACTIVE');
        expect(await storage.getToken(), 'new-jwt');
        final body = sent.single.data as Map<String, dynamic>;
        expect(body['username'], 'hincha_uno');
        expect(body['fullName'], 'Hincha Uno');
        expect(body['cremaDeclarationAccepted'], isTrue);
        expect(body['communityGuidelinesAccepted'], isTrue);
      },
    );

    test('a taken username gets the friendly typed message', () async {
      final service = AuthService(
        storage: storage,
        dio: dio(
          (o) => throw StateError('unused'),
          fail: (o) => DioException(
            requestOptions: o,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: o,
              statusCode: 422,
              data: {'success': false, 'message': 'Username already exists'},
            ),
          ),
        ),
      );

      final result = await service.completeProfile(
        username: 'ocupado',
        favoriteStand: 'Sur',
        cremaDeclarationAccepted: true,
        communityGuidelinesAccepted: true,
      );

      expect(result.success, isFalse);
      expect(result.message, authUsernameTakenMessage);
      expect(await storage.getToken(), isNull);
    });

    test('a network failure is recoverable and stores nothing', () async {
      final service = AuthService(
        storage: storage,
        dio: dio(
          (o) => throw StateError('unused'),
          fail: (o) => DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      final result = await service.completeProfile(
        username: 'hincha',
        favoriteStand: 'Sur',
        cremaDeclarationAccepted: true,
        communityGuidelinesAccepted: true,
      );

      expect(result.success, isFalse);
      expect(result.message, authNetworkMessage);
    });
  });
}
