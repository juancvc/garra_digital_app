import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/core/widgets/garra_ui.dart';
import 'package:garra_digital_app/features/passport/data/passport_models.dart';
import 'package:garra_digital_app/features/passport/data/passport_service.dart';
import 'package:garra_digital_app/features/passport/presentation/passport_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/profile_edit_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/providers/passport_provider.dart';

PassportModel samplePassport() {
  return PassportModel(
    identity: const PassportIdentity(
      username: 'cremafan',
      displayName: 'Hincha Crema',
      city: 'Lima',
      countryCode: 'PE',
      supporterSinceYear: 1998,
      bio: 'Desde la U',
    ),
    level: const PassportLevel(
      number: 2,
      name: 'Hincha Fiel',
      points: 100,
      levelMinPoints: 50,
      nextLevelPoints: 150,
      progressPercent: 50,
      pointsToNextLevel: 50,
    ),
    stats: const PassportStats(
      checkIns: 3,
      predictions: 5,
      predictionPoints: 21,
      posts: 2,
      streakCurrent: 2,
      streakBest: 5,
    ),
    globalRank: 12,
    profileVisibility: 'PUBLIC',
    viewerIsOwner: true,
  );
}

void main() {
  testWidgets('PASSPORT_LOADING_STATE', (tester) async {
    final completer = Completer<PassportModel>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PassportScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(GarraPassportSkeleton), findsOneWidget);
    completer.complete(samplePassport());
    await tester.pumpAndSettle();
  });

  testWidgets('PASSPORT_SUCCESS_STATE', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith((ref) async => samplePassport()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PassportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Hincha Crema'), findsOneWidget);
    expect(find.text('@cremafan'), findsOneWidget);
    expect(find.textContaining('Puntos Garra'), findsOneWidget);
    expect(find.text('Check-ins'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Encuentra tu clan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Encuentra tu clan'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cerrar sesión'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('PASSPORT_ERROR_STATE', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraErrorState(
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.byType(GarraErrorState), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retried, isTrue);
  });

  testWidgets('PASSPORT_PRIVATE_FIELDS_NOT_PRESENT', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith((ref) async => samplePassport()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PassportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('email'), findsNothing);
    expect(find.textContaining('phone'), findsNothing);
  });

  testWidgets('LEVEL_PROGRESS_RENDER', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith((ref) async => samplePassport()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PassportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GarraProgressBar), findsOneWidget);
    expect(find.textContaining('Nivel 2'), findsOneWidget);
  });

  testWidgets('PROFILE_EDIT_VALIDATION', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith((ref) async => samplePassport()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ProfileEditScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'A');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Mínimo 2 caracteres'), findsOneWidget);
  });

  testWidgets('PROFILE_EDIT_SUCCESS', (tester) async {
    var updated = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith((ref) async => samplePassport()),
          passportServiceProvider.overrideWith(
            (ref) => _FakePassportService(onUpdate: () => updated = true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => const ProfileEditScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Nuevo Nombre');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(updated, isTrue);
  });
}

class _FakePassportService extends PassportService {
  _FakePassportService({required this.onUpdate})
      : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost')));

  final VoidCallback onUpdate;

  @override
  Future<PassportModel> updateMyProfile(ProfileUpdateRequest request) async {
    onUpdate();
    return samplePassport();
  }

  @override
  Future<PassportModel> getMyPassport() async => samplePassport();
}
