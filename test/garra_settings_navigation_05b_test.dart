import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/legal/garra_legal_documents.dart';
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

  Future<GoRouter> pumpApp(WidgetTester tester,
      {String initialLocation = '/passport'}) async {
    final router = createAppRouter(
      navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'settings-05b'),
      initialLocation: initialLocation,
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
    return router;
  }

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await settle(tester);
  }

  testWidgets('Perfil → Ajustes → Back returns to Perfil', (tester) async {
    final router = await pumpApp(tester);
    router.push('/settings');
    await settle(tester);
    expect(find.text('Ajustes'), findsOneWidget);
    await tapBack(tester);
    expect(router.routeInformationProvider.value.uri.path, '/passport');
    expect(find.byType(MainShell, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ajustes → Ayuda → Back returns to Ajustes', (tester) async {
    final router = await pumpApp(tester);
    router.go('/settings');
    await settle(tester);
    router.push('/settings/help');
    await settle(tester);
    expect(find.text('Ayuda y soporte'), findsOneWidget);
    await tapBack(tester);
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('Ayuda → Cómo usar Garra → Back returns to Ayuda',
      (tester) async {
    final router = await pumpApp(tester);
    router.go('/settings/help');
    await settle(tester);
    router.push('/settings/help/guide');
    await settle(tester);
    expect(find.text('Cómo usar Garra'), findsWidgets);
    await tapBack(tester);
    expect(router.routeInformationProvider.value.uri.path, '/settings/help');
    expect(find.text('Ayuda y soporte'), findsOneWidget);
  });

  testWidgets('direct /settings Back falls back to Perfil without exiting',
      (tester) async {
    final router = await pumpApp(tester, initialLocation: '/settings');
    expect(find.text('Ajustes'), findsOneWidget);
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await settle(tester);
    expect(router.routeInformationProvider.value.uri.path, '/passport');
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct /settings/legal Back falls back to Ajustes', (tester) async {
    final router = await pumpApp(tester, initialLocation: '/settings/legal');
    expect(find.text('Legal y privacidad'), findsOneWidget);
    await tapBack(tester);
    expect(router.routeInformationProvider.value.uri.path, '/settings');
  });

  testWidgets('Legal privacy opens in-app modal and Aceptar closes it',
      (tester) async {
    await pumpApp(tester, initialLocation: '/settings/legal');
    await tester.tap(find.text('Política de privacidad'));
    await settle(tester);
    expect(find.text(GarraLegalDocument.privacy.title), findsWidgets);
    expect(find.textContaining('comunidad independiente'), findsOneWidget);
    expect(find.textContaining('repositorio'), findsNothing);
    expect(find.textContaining('borrador técnico'), findsNothing);
    await tester.tap(find.text('Aceptar'));
    await settle(tester);
    expect(find.text('Legal y privacidad'), findsOneWidget);
    expect(find.textContaining('comunidad independiente'), findsNothing);
    expect(find.text('Aceptar'), findsNothing);
  });

  testWidgets('Legal terms opens modal with Aceptar', (tester) async {
    await pumpApp(tester, initialLocation: '/settings/legal');
    await tester.tap(find.text('Términos'));
    await settle(tester);
    expect(find.text(GarraLegalDocument.terms.title), findsOneWidget);
    await tester.tap(find.text('Aceptar'));
    await settle(tester);
    expect(find.text('Legal y privacidad'), findsOneWidget);
  });
}
