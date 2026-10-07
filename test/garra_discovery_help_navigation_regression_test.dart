import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/navigation/main_shell.dart';
import 'package:garra_digital_app/core/router/app_router.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/data/garra_football_service.dart';
import 'package:garra_digital_app/features/football/presentation/centro_garra_page.dart';
import 'package:go_router/go_router.dart';

class _EmptyFootball extends GarraFootballService {
  _EmptyFootball() : super(dio: Dio());
  @override
  Future<List<FootballCompetition>> competitions() async => const [];
  @override
  Future<FootballPage<FootballMatch>> matches(FootballView view,
          {String? competition}) async =>
      const FootballPage(
          items: [], stale: false, unavailable: true, partial: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<GoRouter> pumpGuide(WidgetTester tester) async {
    final router = createAppRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/home',
      redirect: (_, _) => null,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garraFootballServiceProvider.overrideWithValue(_EmptyFootball()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);
    // Real device path: shell stays under pushed settings/help pages.
    router.push('/settings');
    await settle(tester);
    router.push('/settings/help');
    await settle(tester);
    router.push('/settings/help/guide');
    await settle(tester);
    expect(find.text('Cómo usar Garra'), findsOneWidget);
    return router;
  }

  const ctas = <(String label, String path, String appBarTitle)>[
    ('Ir a Comunidad', '/comunidad', 'Comunidad'),
    ('Ir a Centro Garra', '/centro-garra', 'Centro Garra'),
    ('Ver negocios', '/negocios', 'Negocios Cremas'),
    ('Ir a Marketplace', '/marketplace', 'Marketplace Crema'),
    ('Ver Garra Solidaria', '/solidaria', 'Garra Solidaria'),
  ];

  for (final (label, path, title) in ctas) {
    testWidgets('guide CTA "$label" reaches $path without duplicate shell',
        (tester) async {
      await pumpGuide(tester);
      await tester.scrollUntilVisible(find.text(label), 120);
      await tester.pump();
      await tester.tap(find.text(label));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(MainShell, skipOffstage: false), findsOneWidget);
      expect(find.widgetWithText(AppBar, title).hitTestable(), findsOneWidget);
      expect(
        find.byType(NavigationBar).hitTestable(),
        findsOneWidget,
      );
    });
  }

  testWidgets('guide compose CTA pushes task route and back restores shell',
      (tester) async {
    await pumpGuide(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Escribe lo que quieres compartir'),
      120,
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Crear publicación'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(MainShell, skipOffstage: false), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Nueva publicación').hitTestable(),
        findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Nueva publicación').hitTestable(),
        findsNothing);
    expect(find.byType(MainShell, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guide settings CTA opens settings hub with single shell off-tree',
      (tester) async {
    await pumpGuide(tester);
    await tester.scrollUntilVisible(find.text('Abrir Ajustes'), 120);
    await tester.pump();
    await tester.tap(find.text('Abrir Ajustes'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(AppBar, 'Ajustes').hitTestable(), findsOneWidget);
    expect(find.byType(MainShell, skipOffstage: false), findsNothing);
  });
}
