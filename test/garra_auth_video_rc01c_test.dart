import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:garra_digital_app/features/auth/presentation/widgets/garra_auth_entry_layout.dart';
import 'package:garra_digital_app/features/auth/presentation/widgets/garra_auth_video_backdrop.dart';

class _FakeVideoPlatform extends VideoPlayerPlatform {
  _FakeVideoPlatform({this.failCreation = false});

  final bool failCreation;
  final _events = StreamController<VideoEvent>.broadcast();
  int created = 0;
  int disposed = 0;
  int played = 0;
  int paused = 0;
  double? volume;
  bool? looping;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    created++;
    if (failCreation) throw StateError('simulated decoder failure');
    expect(dataSource.asset, GarraAuthVideoBackdrop.asset);
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    scheduleMicrotask(() {
      _events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 5),
          size: const Size(768, 1344),
        ),
      );
    });
    return _events.stream;
  }

  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.black);

  @override
  Future<void> setLooping(int playerId, bool value) async => looping = value;

  @override
  Future<void> setVolume(int playerId, double value) async => volume = value;

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async {
    played++;
  }

  @override
  Future<void> pause(int playerId) async {
    paused++;
  }

  @override
  Future<void> dispose(int playerId) async {
    disposed++;
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  Future<void> close() => _events.close();
}

Widget _page(String label) => GarraAuthEntryLayout(
  heroTitle: label,
  body: Builder(
    builder: (context) => TextButton(
      onPressed: () => context.push('/login'),
      child: const Text('Next'),
    ),
  ),
);

void main() {
  late VideoPlayerPlatform original;
  setUp(() => original = VideoPlayerPlatform.instance);
  tearDown(() => VideoPlayerPlatform.instance = original);

  testWidgets('reduced motion keeps WebP and never creates a player', (
    tester,
  ) async {
    final fake = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = fake;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _page('Welcome'),
        ),
      ),
    );
    await tester.pump();
    expect(fake.created, 0);
    expect(find.byKey(const ValueKey('auth-ambient-aura')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).image?.image ==
                const AssetImage(GarraAuthEntryLayout.stadiumAsset),
      ),
      findsOneWidget,
    );
    expect(
      (await rootBundle.load(GarraAuthVideoBackdrop.asset)).lengthInBytes,
      greaterThan(0),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await fake.close();
  });

  testWidgets('decoder failure retains the still image', (tester) async {
    final fake = _FakeVideoPlatform(failCreation: true);
    VideoPlayerPlatform.instance = fake;
    await tester.pumpWidget(MaterialApp(home: _page('Welcome')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(fake.created, 1);
    expect(find.byType(GarraAuthEntryLayout), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await fake.close();
  });

  testWidgets('Auth routes share one muted loop and pause on background', (
    tester,
  ) async {
    final fake = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = fake;
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(path: '/welcome', builder: (_, state) => _page('Welcome')),
        GoRoute(path: '/login', builder: (_, state) => _page('Login')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 500));
    expect(fake.created, 1);
    expect(fake.looping, isTrue);
    expect(fake.volume, 0);
    expect(fake.played, greaterThan(0));
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(fake.created, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(fake.paused, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(fake.played, greaterThan(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await fake.close();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(fake.disposed, 1);
    router.dispose();
  });
}
