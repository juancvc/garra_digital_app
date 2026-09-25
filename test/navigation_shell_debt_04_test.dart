import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/navigation/main_shell.dart';
import 'package:garra_digital_app/core/router/app_router.dart';
import 'package:garra_digital_app/features/explore/presentation/explore_page.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GoRouter router;

  setUp(() {
    router = createAppRouter(
      navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'shell-debt'),
      initialLocation: '/explorar',
      redirect: (_, _) => null,
    );
  });

  tearDown(() => router.dispose());

  Finder appBarTitle(String title) => find.widgetWithText(AppBar, title);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await settle(tester);
  }

  void expectExploreOwnsShell(WidgetTester tester) {
    expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    expect(find.byType(MainShell, skipOffstage: false), findsOneWidget);
  }

  void expectShellCovered(WidgetTester tester) {
    expect(find.byType(NavigationBar).hitTestable(), findsNothing);
    expect(find.byType(MainShell, skipOffstage: false), findsOneWidget);
  }

  Future<void> expectDestinationKeepsShell(
    WidgetTester tester,
    String path,
    String title,
  ) async {
    await pumpShell(tester);
    router.go('/explorar');
    await settle(tester);
    router.push(path);
    await settle(tester);
    expect(appBarTitle(title).hitTestable(), findsOneWidget);
    expectExploreOwnsShell(tester);
  }

  Future<void> pop(WidgetTester tester) async {
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await settle(tester);
  }

  testWidgets('Explore card opens Ruta al Templo inside the shell', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(appBarTitle('Explorar').hitTestable(), findsOneWidget);
    final scrollable = find.descendant(
      of: find.byType(ExplorePage),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('explore-ruta-templo')),
      240,
      scrollable: scrollable.first,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('explore-ruta-templo')));
    await settle(tester);
    expect(appBarTitle('Ruta al Templo').hitTestable(), findsOneWidget);
    expectExploreOwnsShell(tester);
    await pop(tester);
    expect(appBarTitle('Explorar').hitTestable(), findsOneWidget);
    expect(find.text('RUTA AL TEMPLO').hitTestable(), findsOneWidget);
    expect(appBarTitle('Ruta al Templo').hitTestable(), findsNothing);
    expectExploreOwnsShell(tester);
  });

  testWidgets('Explore destinations keep the shell and Explorar selected', (
    tester,
  ) async {
    await expectDestinationKeepsShell(tester, '/negocios', 'Negocios Cremas');
    await expectDestinationKeepsShell(
      tester,
      '/marketplace',
      'Marketplace Crema',
    );
    await expectDestinationKeepsShell(tester, '/clans', 'Comunidades Cremas');
    await expectDestinationKeepsShell(tester, '/eventos', 'Eventos');
    await expectDestinationKeepsShell(tester, '/solidaria', 'Garra Solidaria');
    await expectDestinationKeepsShell(tester, '/rewards', 'Beneficios');
  });

  testWidgets('task screens cover the bottom navigation', (tester) async {
    await pumpShell(tester);

    router.push('/comunidad/compose');
    await settle(tester);
    expect(appBarTitle('Nueva publicación').hitTestable(), findsOneWidget);
    expectShellCovered(tester);

    await pop(tester);
    expectExploreOwnsShell(tester);

    router.push('/passport/edit');
    await settle(tester);
    expect(appBarTitle('Editar perfil').hitTestable(), findsOneWidget);
    expectShellCovered(tester);

    await pop(tester);
    router.push('/negocios/mi-negocio/nuevo');
    await settle(tester);
    expect(appBarTitle('Registrar mi negocio').hitTestable(), findsOneWidget);
    expectShellCovered(tester);
  });

  testWidgets('android back returns to the explore parent', (tester) async {
    await pumpShell(tester);
    router.push('/marketplace');
    await settle(tester);
    router.push('/marketplace/listings/demo');
    await settle(tester);
    expectExploreOwnsShell(tester);

    await pop(tester);
    expect(appBarTitle('Marketplace Crema').hitTestable(), findsOneWidget);
    expectExploreOwnsShell(tester);

    await pop(tester);
    expect(appBarTitle('Explorar').hitTestable(), findsOneWidget);
    expectExploreOwnsShell(tester);

    router.push('/negocios');
    await settle(tester);
    router.push('/negocios/cafe-monumental');
    await settle(tester);
    await pop(tester);
    expect(appBarTitle('Negocios Cremas').hitTestable(), findsOneWidget);
    expect(find.text('Ver negocios').hitTestable(), findsOneWidget);
    expectExploreOwnsShell(tester);
    await pop(tester);
    expect(appBarTitle('Explorar').hitTestable(), findsOneWidget);

    router.push('/ruta-templo');
    await settle(tester);
    await pop(tester);
    expect(appBarTitle('Explorar').hitTestable(), findsOneWidget);
    expect(appBarTitle('Ruta al Templo').hitTestable(), findsNothing);
    expectExploreOwnsShell(tester);
  });

  testWidgets('switching tabs preserves the explore branch stack', (
    tester,
  ) async {
    await pumpShell(tester);
    router.push('/marketplace');
    await settle(tester);
    expect(appBarTitle('Marketplace Crema').hitTestable(), findsOneWidget);

    final nav = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: nav, matching: find.text('Comunidad')),
    );
    await settle(tester);
    expect(appBarTitle('Comunidad').hitTestable(), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(find.descendant(of: nav, matching: find.text('Explorar')));
    await settle(tester);
    expect(appBarTitle('Marketplace Crema').hitTestable(), findsOneWidget);
    expectExploreOwnsShell(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Explorar'),
      ),
    );
    await settle(tester);
    expect(appBarTitle('Marketplace Crema').hitTestable(), findsNothing);
    expect(appBarTitle('Explorar').hitTestable(), findsOneWidget);
    expectExploreOwnsShell(tester);
  });
}
