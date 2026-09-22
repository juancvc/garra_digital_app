import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_brand_visual.dart';

void main() {
  testWidgets('brand lockup keeps unofficial positioning on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: GarraBrandLockup(crestSize: 38),
            ),
          ),
        ),
      ),
    );

    expect(find.text('GARRA DIGITAL'), findsOneWidget);
    expect(find.text('COMUNIDAD NO OFICIAL DE HINCHAS CREMAS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('atmospheric hero renders crest content without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(12),
            child: GarraAtmosphericHero(
              child: Row(
                children: [
                  GarraCrest(size: 48),
                  SizedBox(width: 12),
                  Expanded(child: Text('La pasión crema vive aquí')),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('La pasión crema vive aquí'), findsOneWidget);
    expect(find.text('U'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
