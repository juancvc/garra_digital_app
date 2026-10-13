// PRODUCT-10A.2E: navigation closure (Centro destinations, no Home shortcuts)
// and optional-update notice rules.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/config/app_config_service.dart';
import 'package:garra_digital_app/core/config/semver.dart';
import 'package:garra_digital_app/core/widgets/app_gates.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';

import 'centro_matchday_harness.dart';
import 'home_screen_test.dart' show sampleHome, pumpHome;

AppConfigModel _remote({String? storeUrl, String min = '0.9.0', String latest = '1.0.0'}) =>
    AppConfigModel.fromJson({
      'minimumSupportedVersion': min, 'latestVersion': latest,
      'storeUrl': ?storeUrl,
    });

void main() {
  group('Centro recovers the ex Partido surfaces', () {
    testWidgets('Polla -> Back returns to Centro with the hub, /home read once', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var homeLoads = 0;
      await tester.pumpWidget(pumpCentroMatchday(sampleHome(), onHomeLoad: () => homeLoads++));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('centro_matchday_hub')), findsOneWidget);
      expect(find.text('Pulso Crema'), findsOneWidget);
      await tester.tap(find.text('Hacer predicción'));
      await tester.pumpAndSettle();
      expect(find.text('POLLA_ROUTE'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('POLLA_ROUTE'), findsNothing);
      expect(find.byKey(const ValueKey('centro_matchday_hub')), findsOneWidget);
      expect(homeLoads, 1);
    });

    testWidgets('without match or pending items the hub is hidden and Centro still renders', (tester) async {
      await tester.pumpWidget(pumpCentroMatchday(sampleHome(withMatch: false)));
      await tester.pumpAndSettle();
      expect(find.text('Pulso Crema'), findsNothing);
      expect(find.text('Centro Garra'), findsOneWidget);
    });

    testWidgets('Home keeps no redundant Matchday shortcuts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(pumpHome(sampleHome(matchdayState: 'MATCHDAY')));
      await tester.pumpAndSettle();
      for (final t in ['Pulso Crema', 'Hacer predicción', 'Vota por el MVP',
          'Hacer check-in', 'Ver misión', 'Partido']) {
        expect(find.text(t), findsNothing, reason: t);
      }
      expect(find.byKey(const ValueKey('centro_matchday_hub')), findsNothing);
      expect(find.byKey(const ValueKey('countdown-DD')), findsNothing);
    });

    testWidgets('detail countdown hidden for unconfirmed or past kickoff', (tester) async {
      await tester.pumpWidget(pumpMatchDetail(FootballMatch(id: 9,
        competitionId: 'LIGA_1', competition: 'Liga 1', home: 'U', away: 'R',
        status: 'SCHEDULED', kickoff: DateTime(2030, 1, 1, 19), kickoffConfirmed: false)));
      await tester.pump();
      expect(find.byKey(const ValueKey('detail_countdown')), findsNothing);
      await tester.pumpWidget(pumpMatchDetail(FootballMatch(id: 10,
        competitionId: 'LIGA_1', competition: 'Liga 1', home: 'U', away: 'R',
        status: 'FINISHED', kickoff: DateTime(2020, 1, 1, 19), kickoffConfirmed: true,
        homeScore: 1, awayScore: 0)));
      await tester.pump();
      expect(find.byKey(const ValueKey('countdown-DD')), findsNothing);
    });
  });

  group('optional update notice (PRODUCT-10A.2E)', () {
    const optional = AppVersionStatus.updateAvailable;
    test('optional with valid https storeUrl is shown', () {
      expect(shouldShowOptionalUpdate(optional,
          _remote(storeUrl: 'https://play.google.com/store/apps/details?id=com.garradigital.app')), isTrue);
    });
    test('optional without storeUrl or with invalid storeUrl is hidden', () {
      expect(shouldShowOptionalUpdate(optional, _remote()), isFalse);
      expect(shouldShowOptionalUpdate(optional, _remote(storeUrl: '')), isFalse);
      expect(shouldShowOptionalUpdate(optional, _remote(storeUrl: 'market://details?id=x')), isFalse);
      expect(shouldShowOptionalUpdate(optional, _remote(storeUrl: 'not a url')), isFalse);
    });
    test('local fallback config never shows the optional notice', () {
      final fallback = AppConfigModel.fallback();
      expect(fallback.fromFallback, isTrue);
      expect(evaluateVersion(installed: '0.9.0',
          minimumSupported: fallback.minimumSupportedVersion,
          latest: fallback.latestVersion), optional);
      expect(shouldShowOptionalUpdate(optional, fallback), isFalse);
      expect(_remote().fromFallback, isFalse);
    });
    test('supported/required statuses never use the optional notice', () {
      final cfg = _remote(storeUrl: 'https://garradigital.pe/app');
      expect(shouldShowOptionalUpdate(AppVersionStatus.supported, cfg), isFalse);
      expect(shouldShowOptionalUpdate(AppVersionStatus.updateRequired, cfg), isFalse);
    });
    test('forced update decision is unchanged (installed < minimum)', () {
      expect(evaluateVersion(installed: '0.8.9', minimumSupported: '0.9.0', latest: '1.0.0'),
          AppVersionStatus.updateRequired);
      expect(evaluateVersion(installed: '0.9.0', minimumSupported: '0.9.0', latest: '1.0.0'),
          AppVersionStatus.updateAvailable);
    });
    testWidgets('forced page still blocks without storeUrl (staging button, no exit)', (tester) async {
      await tester.pumpWidget(MaterialApp(home: UpdateRequiredPage(config: _remote(min: '1.0.0'))));
      expect(find.text('Actualización requerida'), findsOneWidget);
      expect(find.textContaining('mínimo 1.0.0'), findsOneWidget);
      expect(find.text('Entendido (staging)'), findsOneWidget);
      expect(find.text('Actualizar'), findsNothing);
      await tester.tap(find.text('Entendido (staging)'));
      await tester.pump();
      expect(find.text('Actualización requerida'), findsOneWidget);
    });
    testWidgets('forced page with valid storeUrl offers Actualizar', (tester) async {
      await tester.pumpWidget(MaterialApp(home: UpdateRequiredPage(
          config: _remote(min: '1.0.0', storeUrl: 'https://garradigital.pe/app'))));
      expect(find.text('Actualizar'), findsOneWidget);
    });
  });
}
