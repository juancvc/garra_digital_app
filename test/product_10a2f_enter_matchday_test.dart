// PRODUCT-10A.2F: RC2 'Entrar al partido / Entrar al Matchday' CTA recovered
// in Centro · Para ti · Hoy (not in Home, not in the fixture detail).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/config/app_config_service.dart';
import 'package:garra_digital_app/core/network/dio_client.dart';

import 'centro_matchday_harness.dart';
import 'home_screen_test.dart' show sampleHome, pumpHome;

Future<void> _setMatchdayFlag(WidgetTester tester, bool enabled) async {
  final stub = InterceptorsWrapper(onRequest: (options, handler) {
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
      'data': {
        'minimumSupportedVersion': '0.9.0', 'latestVersion': '1.0.0',
        'features': {'matchday': enabled, 'marketplace': true, 'community': true},
      },
    }));
  });
  DioClient.instance.interceptors.insert(0, stub);
  await tester.runAsync(() => appConfigService.fetch());
  DioClient.instance.interceptors.remove(stub);
}

final _cta = find.byKey(const ValueKey('centro_enter_matchday'));

Future<void> _pumpCentro(WidgetTester tester, String state, {bool withMatch = true}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(pumpCentroMatchday(
      sampleHome(matchdayState: state, withMatch: withMatch)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  testWidgets('MATCHDAY: Entrar al Matchday without MVP open, navigates and Back returns',
      (tester) async {
    await _setMatchdayFlag(tester, true);
    await _pumpCentro(tester, 'MATCHDAY');
    expect(_cta, findsOneWidget);
    expect(find.text('Entrar al Matchday'), findsOneWidget);
    expect(find.text('Vota por el MVP'), findsNothing); // mvpOpen false
    await tester.tap(_cta);
    await tester.pumpAndSettle();
    expect(find.text('MATCHDAY_POLLS'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('MATCHDAY_POLLS'), findsNothing);
    expect(_cta, findsOneWidget);
  });

  testWidgets('LIVE: Entrar al partido', (tester) async {
    await _setMatchdayFlag(tester, true);
    await _pumpCentro(tester, 'LIVE');
    expect(find.text('Entrar al partido'), findsOneWidget);
    await tester.tap(_cta);
    await tester.pumpAndSettle();
    expect(find.text('MATCHDAY_POLLS'), findsOneWidget);
  });

  testWidgets('hidden for upcoming match and without match', (tester) async {
    await _setMatchdayFlag(tester, true);
    await _pumpCentro(tester, 'UPCOMING');
    expect(_cta, findsNothing);
    await _pumpCentro(tester, 'NO_MATCH', withMatch: false);
    expect(_cta, findsNothing);
  });

  testWidgets('hidden when the matchday flag (destination) is off', (tester) async {
    await _setMatchdayFlag(tester, false);
    try {
      expect(appConfigService.current.feature('matchday'), isFalse);
      await _pumpCentro(tester, 'MATCHDAY');
      expect(_cta, findsNothing);
      expect(find.text('Pulso Crema'), findsOneWidget);
    } finally {
      await _setMatchdayFlag(tester, true);
    }
  });

  testWidgets('Home keeps no Entrar al partido/Matchday shortcut', (tester) async {
    await _setMatchdayFlag(tester, true);
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(pumpHome(sampleHome(matchdayState: 'LIVE')));
    await tester.pumpAndSettle();
    expect(find.text('Entrar al partido'), findsNothing);
    expect(find.text('Entrar al Matchday'), findsNothing);
    expect(_cta, findsNothing);
  });
}
