import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/auth/presentation/login_page.dart';
import 'package:garra_digital_app/features/splash/data/first_launch_experience_service.dart';
import 'package:garra_digital_app/features/splash/data/intro_audio.dart';
import 'package:garra_digital_app/features/splash/presentation/garra_primordial_intro_page.dart';
import 'package:garra_digital_app/features/splash/presentation/intro_replay_action.dart';
import 'package:garra_digital_app/features/splash/presentation/splash_page.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('first launch returns introSeen false', () async {
    final service = FirstLaunchExperienceService(store: MemoryIntroFlagStore());
    expect(await service.hasSeenIntro(), isFalse);
  });

  testWidgets('puma renders before GARRA', (tester) async {
    await tester.pumpWidget(
      _flow(
        intro: FirstLaunchExperienceService(store: MemoryIntroFlagStore()),
        session: false,
        audio: _FakeAudio(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.byKey(const Key('intro-puma')), findsOneWidget);
    expect(find.byKey(const Key('intro-garra')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('GARRA renders before DIGITAL', (tester) async {
    await tester.pumpWidget(
      _flow(
        intro: FirstLaunchExperienceService(store: MemoryIntroFlagStore()),
        session: false,
        audio: _FakeAudio(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.byKey(const Key('intro-garra')), findsOneWidget);
    expect(find.byKey(const Key('intro-digital')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('full lockup appears before exit', (tester) async {
    await tester.pumpWidget(
      _flow(
        intro: FirstLaunchExperienceService(store: MemoryIntroFlagStore()),
        session: false,
        audio: _FakeAudio(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4500));

    expect(find.byKey(const Key('intro-puma')), findsOneWidget);
    expect(find.byKey(const Key('intro-garra')), findsOneWidget);
    expect(find.byKey(const Key('intro-digital')), findsOneWidget);
    expect(find.text('De hinchas para hinchas'), findsOneWidget);
    expect(find.text('Comunidad no oficial de hinchas cremas'), findsOneWidget);
    expect(find.text('LOGIN'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('completing the intro stores introSeen', (tester) async {
    final store = MemoryIntroFlagStore();
    final service = FirstLaunchExperienceService(store: store);
    await tester.pumpWidget(
      _flow(intro: service, session: false, audio: _FakeAudio()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 6300));
    await tester.pump();
    await tester.pump();

    expect(await service.hasSeenIntro(), isTrue);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('skipping the intro stores introSeen and stops audio', (
    tester,
  ) async {
    final store = MemoryIntroFlagStore();
    final service = FirstLaunchExperienceService(store: store);
    final audio = _FakeAudio();
    await tester.pumpWidget(
      _flow(intro: service, session: false, audio: audio),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text('Omitir'));
    await tester.pump();
    await tester.pump();

    expect(await service.hasSeenIntro(), isTrue);
    expect(audio.stops, greaterThan(0));
    expect(audio.disposes, greaterThan(0));
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('second launch bypasses the cinematic intro', (tester) async {
    final store = MemoryIntroFlagStore()..values['garra_intro_seen_v1'] = true;
    await tester.pumpWidget(
      _flow(
        intro: FirstLaunchExperienceService(store: store),
        session: false,
        audio: _FakeAudio(),
        settle: Duration.zero,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Omitir'), findsNothing);
  });

  testWidgets('unauthenticated second launch routes to login', (tester) async {
    final store = MemoryIntroFlagStore()..values['garra_intro_seen_v1'] = true;
    await tester.pumpWidget(
      _flow(
        intro: FirstLaunchExperienceService(store: store),
        session: false,
        audio: _FakeAudio(),
        settle: Duration.zero,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('authenticated second launch routes to home', (tester) async {
    final store = MemoryIntroFlagStore()..values['garra_intro_seen_v1'] = true;
    await tester.pumpWidget(
      _flow(
        intro: FirstLaunchExperienceService(store: store),
        session: true,
        audio: _FakeAudio(),
        settle: Duration.zero,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('intro preserves an authenticated session', (tester) async {
    final service = FirstLaunchExperienceService(store: MemoryIntroFlagStore());
    await tester.pumpWidget(
      _flow(intro: service, session: true, audio: _FakeAudio()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 6300));
    await tester.pump();
    await tester.pump();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('LOGIN'), findsNothing);
  });

  testWidgets('audio failure does not prevent completion', (tester) async {
    final service = FirstLaunchExperienceService(store: MemoryIntroFlagStore());
    await tester.pumpWidget(
      _flow(
        intro: service,
        session: false,
        audio: _FakeAudio()..startError = StateError('missing bed'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 6300));
    await tester.pump();
    await tester.pump();
    expect(await service.hasSeenIntro(), isTrue);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('intro has no overlay tooltip', (tester) async {
    await tester.pumpWidget(
      _flow(
        intro: FirstLaunchExperienceService(store: MemoryIntroFlagStore()),
        session: false,
        audio: _FakeAudio(),
      ),
    );
    await tester.pump();
    expect(find.byType(Tooltip), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion still completes the first use', (tester) async {
    final service = FirstLaunchExperienceService(store: MemoryIntroFlagStore());
    await tester.pumpWidget(
      _flow(intro: service, session: false, audio: _FakeAudio(), reduced: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    await tester.pump();
    expect(await service.hasSeenIntro(), isTrue);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('login still exposes email, password, Google and register', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.darkTheme, home: const LoginPage()),
      ),
    );
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('De hinchas para hinchas'), findsOneWidget);
  });

  testWidgets('staging replay action is hidden when not offered', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IntroReplayAction(visible: false, onReplay: () async {}),
        ),
      ),
    );
    expect(find.text('Reproducir introducción'), findsNothing);
  });

  test('staging replay clears only the intro flag', () async {
    final store = MemoryIntroFlagStore()
      ..values['auth_token'] = 'keep-me'
      ..values[FirstLaunchExperienceService.introSeenKey] = true;
    final service = FirstLaunchExperienceService(store: store);
    await service.resetIntro();
    expect(store.values['auth_token'], 'keep-me');
    expect(await service.hasSeenIntro(), isFalse);
  });

  testWidgets('intro has no overflow on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _flow(
        intro: FirstLaunchExperienceService(store: MemoryIntroFlagStore()),
        session: false,
        audio: _FakeAudio(),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _flow({
  required FirstLaunchExperienceService intro,
  required bool session,
  required IntroAudio audio,
  Duration settle = const Duration(milliseconds: 280),
  bool reduced = false,
}) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => SplashPage(
          intro: intro,
          hasSession: () async => session,
          settle: settle,
        ),
      ),
      GoRoute(
        path: '/intro',
        builder: (context, _) {
          final page = GarraPrimordialIntroPage(
            intro: intro,
            hasSession: () async => session,
            audio: audio,
          );
          if (!reduced) return page;
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: page,
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  return MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router);
}

class _FakeAudio implements IntroAudio {
  int stops = 0;
  int disposes = 0;
  Object? startError;

  @override
  Future<void> start() async {
    if (startError != null) throw startError!;
  }

  @override
  Future<void> stop() async {
    stops += 1;
  }

  @override
  void dispose() {
    disposes += 1;
  }
}
