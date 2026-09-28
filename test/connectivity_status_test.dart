import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_banner.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';

class FakeConnectivitySource implements ConnectivitySource {
  FakeConnectivitySource(this.initial);

  final List<ConnectivityResult> initial;
  final _changes = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );

  @override
  Future<List<ConnectivityResult>> check() async => initial;

  @override
  Stream<List<ConnectivityResult>> get changes => _changes.stream;

  void emit(ConnectivityResult result) => _changes.add([result]);

  Future<void> dispose() => _changes.close();
}

void main() {
  test('ONLINE → OFFLINE → ONLINE follows transport changes', () async {
    final source = FakeConnectivitySource([ConnectivityResult.wifi]);
    final container = ProviderContainer(
      overrides: [connectivitySourceProvider.overrideWithValue(source)],
    );
    addTearDown(container.dispose);
    addTearDown(source.dispose);

    expect(
      container.read(connectivityStatusProvider),
      NetworkConnectivity.online,
    );
    await Future<void>.delayed(Duration.zero);
    source.emit(ConnectivityResult.none);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(connectivityStatusProvider),
      NetworkConnectivity.offline,
    );

    source.emit(ConnectivityResult.mobile);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(connectivityStatusProvider),
      NetworkConnectivity.online,
    );
  });

  test(
    'DEGRADED is preserved by transport and cleared by a healthy signal',
    () async {
      final source = FakeConnectivitySource([ConnectivityResult.wifi]);
      final container = ProviderContainer(
        overrides: [connectivitySourceProvider.overrideWithValue(source)],
      );
      addTearDown(container.dispose);
      addTearDown(source.dispose);

      container.read(connectivityStatusProvider);
      await Future<void>.delayed(Duration.zero);
      container.read(connectivityStatusProvider.notifier).reportDegraded();
      source.emit(ConnectivityResult.mobile);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(connectivityStatusProvider),
        NetworkConnectivity.degraded,
      );
      container.read(connectivityStatusProvider.notifier).reportHealthy();
      expect(
        container.read(connectivityStatusProvider),
        NetworkConnectivity.online,
      );
    },
  );

  testWidgets('banner follows status without replacing content or navigation', (
    tester,
  ) async {
    final source = FakeConnectivitySource([ConnectivityResult.wifi]);
    addTearDown(source.dispose);
    var refreshes = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [connectivitySourceProvider.overrideWithValue(source)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            navigatorKey: navigatorKey,
            home: ConnectivityBanner(
              status: ref.watch(connectivityStatusProvider),
              child: Scaffold(
                body: Column(
                  children: [
                    const Text('Contenido existente'),
                    TextButton(
                      onPressed: () => navigatorKey.currentState!.push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const Scaffold(body: Text('Otra ruta')),
                        ),
                      ),
                      child: const Text('Navegar'),
                    ),
                    TextButton(
                      onPressed: () => refreshes++,
                      child: const Text('Actualizar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Sin conexión a internet'), findsNothing);
    expect(find.text('Conexión inestable'), findsNothing);

    source.emit(ConnectivityResult.none);
    await tester.pump();
    expect(find.text('Sin conexión a internet'), findsOneWidget);
    expect(find.text('Contenido existente'), findsOneWidget);
    expect(refreshes, 0);

    await tester.tap(find.text('Navegar'));
    await tester.pumpAndSettle();
    expect(find.text('Otra ruta'), findsOneWidget);

    source.emit(ConnectivityResult.mobile);
    await tester.pump();
    expect(find.text('Sin conexión a internet'), findsNothing);
    expect(refreshes, 0);
  });

  testWidgets('DEGRADED shows distinct banner; ONLINE shows none', (
    tester,
  ) async {
    final source = FakeConnectivitySource([ConnectivityResult.wifi]);
    addTearDown(source.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [connectivitySourceProvider.overrideWithValue(source)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            home: ConnectivityBanner(
              status: ref.watch(connectivityStatusProvider),
              child: const Scaffold(body: Text('Contenido')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Conexión inestable'), findsNothing);
    final element = tester.element(find.text('Contenido'));
    ProviderScope.containerOf(
      element,
    ).read(connectivityStatusProvider.notifier).reportDegraded();
    await tester.pump();
    expect(find.text('Conexión inestable'), findsOneWidget);
    expect(find.text('Contenido'), findsOneWidget);
  });
}
