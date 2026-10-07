import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:garra_digital_app/core/discovery/garra_discovery_tip.dart';
import 'package:garra_digital_app/features/settings/presentation/garra_help_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('official help artwork assets are bundled', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final path in const [
      'assets/images/discovery/garra_help_hero.webp',
      'assets/images/discovery/garra_help_fan.webp',
      'assets/images/discovery/garra_help_digital.webp',
      'assets/images/discovery/garra_help_marketplace.webp',
      'assets/images/discovery/garra_help_solidarity.webp',
    ]) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(1024));
    }
  });

  testWidgets('first-use tip appears once, dismiss persists, IDs are independent',
      (tester) async {
    const store = DiscoveryTipStore();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      GarraDiscoveryTip(id: 'test.home.v1', title: 'Inicio', message: 'Descubre Garra'))));
    await tester.pumpAndSettle();
    expect(find.text('Descubre Garra'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar ayuda'));
    await tester.pump();
    expect(find.text('Descubre Garra'), findsNothing);
    expect(await store.hasSeen('test.home.v1'), isTrue);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      GarraDiscoveryTip(id: 'test.home.v1', title: 'Inicio', message: 'Descubre Garra'))));
    await tester.pumpAndSettle();
    expect(find.text('Descubre Garra'), findsNothing);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      GarraDiscoveryTip(key: ValueKey('other-tip'), id: 'test.marketplace.v1', title: 'Marketplace', message: 'En revisión'))));
    await tester.pumpAndSettle();
    expect(find.text('En revisión'), findsOneWidget);
  });

  testWidgets('tip leaves underlying content and navigation usable at 360px',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: Scaffold(body: GarraDiscoverySurface(
        id: 'test.overlay.v1', title: 'Descubre',
        message: 'Una ayuda pequeña y cerrable para explorar la comunidad.',
        child: Align(alignment: Alignment.topCenter,
          child: TextButton(onPressed: () => taps++, child: const Text('Contenido visible'))),
      )),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Contenido visible'), findsOneWidget);
    expect(find.text('Descubre'), findsOneWidget);
    await tester.tap(find.text('Contenido visible'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back dismisses the tip before leaving its page', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      GarraDiscoveryTip(id: 'test.back.v1', title: 'Ayuda', message: 'Puedes cerrarla'))));
    await tester.pumpAndSettle();
    expect(find.text('Puedes cerrarla'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Puedes cerrarla'), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('help links guide, FAQ, feedback, legal, privacy and diagnostics',
      (tester) async {
    final router = GoRouter(initialLocation: '/settings/help', routes: [
      GoRoute(path: '/settings/help', builder: (_, _) => const GarraHelpPage()),
      GoRoute(path: '/settings/help/guide', builder: (_, _) => const GarraGuidePage()),
      GoRoute(path: '/settings/help/faq', builder: (_, _) => const GarraFaqPage()),
      for (final path in ['/settings/feedback', '/settings/legal',
        '/settings/privacy', '/settings/help/diagnostics'])
        GoRoute(path: path, builder: (_, _) => Scaffold(body: Text(path))),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Cómo usar Garra'), findsOneWidget);
    expect(find.text('Preguntas frecuentes'), findsOneWidget);
    expect(find.text('Escríbenos'), findsOneWidget);
    expect(find.text('Términos y condiciones'), findsOneWidget);
    expect(find.text('Privacidad'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Diagnóstico'), 100);
    expect(find.text('Diagnóstico'), findsOneWidget);
    await tester.tap(find.text('Cómo usar Garra'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Marketplace'), 120);
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.textContaining('Revisamos las publicaciones'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Garra Solidaria'), 120);
    expect(find.textContaining('no procesa dinero'), findsOneWidget);
    router.go('/settings/help');
    await tester.pumpAndSettle();
    router.go('/settings/help/faq');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('¿Cómo funciona Garra Solidaria?'), 100);
    expect(find.text('¿Cómo funciona Garra Solidaria?'), findsOneWidget);
    for (final (label, path) in [
      ('Escríbenos', '/settings/feedback'),
      ('Términos y condiciones', '/settings/legal'),
      ('Privacidad', '/settings/privacy'),
      ('Diagnóstico', '/settings/help/diagnostics'),
    ]) {
      router.go('/settings/help');
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(find.text(label)),
        alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(path), findsOneWidget);
    }
  });

  testWidgets('guide hero, section cards and CTA work at 360px / 1.3 scale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/settings/help/guide', routes: [
      GoRoute(path: '/settings/help/guide', builder: (_, _) => const GarraGuidePage()),
      GoRoute(path: '/marketplace', builder: (_, _) => const Scaffold(body: Text('Marketplace abierto'))),
    ]);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('GARRA\nTE ENSEÑA\nGARRA'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    await tester.scrollUntilVisible(find.text('Marketplace'), 120);
    expect(find.textContaining('Solicita tu perfil vendedor'), findsOneWidget);
    await Scrollable.ensureVisible(tester.element(find.text('Ir a Marketplace')),
      alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir a Marketplace'));
    await tester.pumpAndSettle();
    expect(find.text('Marketplace abierto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guide remains readable at wider width and normal text scale',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: GarraGuidePage()));
    await tester.pumpAndSettle();
    expect(find.text('GARRA\nTE ENSEÑA\nGARRA'), findsOneWidget);
    expect(find.text('Primeros pasos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
