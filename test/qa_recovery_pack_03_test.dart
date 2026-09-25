import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/explore/presentation/explore_page.dart';
import 'package:garra_digital_app/features/locations/data/crema_point_model.dart';
import 'package:garra_digital_app/features/locations/data/location_service.dart';
import 'package:garra_digital_app/features/locations/presentation/mi_negocio_crema_page.dart';
import 'package:garra_digital_app/features/locations/presentation/negocios_cremas_page.dart';
import 'package:garra_digital_app/features/passport/data/passport_models.dart';
import 'package:garra_digital_app/features/passport/presentation/profile_edit_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/providers/passport_provider.dart';
import 'package:garra_digital_app/features/solidarity/presentation/solidaria_page.dart';
import 'package:go_router/go_router.dart';

import 'passport_screen_test.dart' show samplePassport;

void main() {
  test('signed upload uses the canonical media contract', () async {
    final calls = <String>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add('${options.method} ${options.path}');
          if (options.path == '/media/uploads') {
            expect(options.data['purpose'], 'PROFILE_AVATAR');
            expect(options.data['fileName'], 'photo.jpg');
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': {
                    'assetId': 'asset-1',
                    'uploadUrl': 'https://storage.example/put',
                    'method': 'PUT',
                    'requiredHeaders': {'Content-Type': 'image/jpeg'},
                  },
                },
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'data': {'mediaUrl': 'https://cdn.example/a.jpg'},
              },
            ),
          );
        },
      ),
    );
    final binary = Dio();
    binary.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add('${options.method} ${options.uri}');
          handler.resolve(Response(requestOptions: options, data: ''));
        },
      ),
    );
    final service = MediaUploadService(dio: dio, binaryClient: binary);
    final signed = await service.createSignedUpload(
      purpose: MediaUploadPurpose.profileAvatar,
      contentType: 'image/jpeg',
      sizeBytes: 12,
    );
    await service.putBytes(
      signed: signed,
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    await service.confirm(signed.assetId);

    expect(calls, [
      'POST /media/uploads',
      'PUT https://storage.example/put',
      'POST /media/asset-1/confirm',
    ]);
    expect(calls.join(' '), isNot(contains('signed-upload')));
    expect(
      ProfileUpdateRequest(
        displayName: 'Ana',
        avatarMediaAssetId: signed.assetId,
      ).toJson()['avatarMediaAssetId'],
      'asset-1',
    );
    expect(MediaUploadPurpose.solidarity.apiValue, 'SOLIDARITY_EVIDENCE');
    expect(MediaUploadService.communityPhotoLimit, 4);
    expect(
      MediaUploadService.uploadFailedMessage,
      'No pudimos subir la foto. Intenta nuevamente.',
    );
  });

  test('community photos request COMMUNITY_POST on /media/uploads', () async {
    String? purpose;
    String? path;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          path = options.path;
          purpose = options.data['purpose'] as String?;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'data': {
                  'assetId': 'post-1',
                  'uploadUrl': 'https://storage.example/post',
                  'method': 'PUT',
                  'requiredHeaders': {'Content-Type': 'image/jpeg'},
                },
              },
            ),
          );
        },
      ),
    );
    final signed = await MediaUploadService(dio: dio).createSignedUpload(
      purpose: MediaUploadPurpose.communityPost,
      contentType: 'image/jpeg',
      sizeBytes: 20,
    );
    expect(path, '/media/uploads');
    expect(purpose, 'COMMUNITY_POST');
    expect(signed.assetId, 'post-1');
  });

  testWidgets('explore lists ruta al templo as its own destination', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/explorar',
      routes: [
        GoRoute(path: '/explorar', builder: (_, _) => const ExplorePage()),
        GoRoute(
          path: '/ruta-templo',
          builder: (_, _) => const Scaffold(body: Text('STADIUM_ROUTE')),
        ),
        GoRoute(
          path: '/clans',
          builder: (_, _) => const Scaffold(body: Text('CLANS_ROUTE')),
        ),
        GoRoute(
          path: '/negocios',
          builder: (_, _) => const Scaffold(body: Text('NEGOCIOS_ROUTE')),
        ),
        GoRoute(
          path: '/marketplace',
          builder: (_, _) => const Scaffold(body: Text('MARKET_ROUTE')),
        ),
        GoRoute(
          path: '/eventos',
          builder: (_, _) => const Scaffold(body: Text('EVENTS_ROUTE')),
        ),
        GoRoute(
          path: '/solidaria',
          builder: (_, _) => const Scaffold(body: Text('SOLIDARIA_ROUTE')),
        ),
        GoRoute(
          path: '/rewards',
          builder: (_, _) => const Scaffold(body: Text('REWARDS_ROUTE')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    final exploreList = find
        .descendant(
          of: find.byType(ExplorePage),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final key in [
      'explore-comunidades',
      'explore-ruta-templo',
      'explore-negocios',
      'explore-marketplace',
      'explore-eventos',
      'explore-solidaria',
      'explore-beneficios',
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        400,
        scrollable: exploreList,
      );
      expect(find.byKey(Key(key)), findsOneWidget);
      if (key == 'explore-ruta-templo') {
        expect(
          find.text('Camino al estadio, puntos de encuentro y check-in'),
          findsOneWidget,
        );
      }
    }
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('explore-ruta-templo')),
      -400,
      scrollable: exploreList,
    );
    await tester.drag(exploreList, const Offset(0, 220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RUTA AL TEMPLO'));
    await tester.pumpAndSettle();
    expect(find.text('STADIUM_ROUTE'), findsOneWidget);
  });

  testWidgets('negocios empty state stays visible when only other points exist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: NegociosCremasBrowsePage(
          locationService: _Points([
            _point(type: 'STADIUM', name: 'Monumental'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay negocios registrados todavía'), findsOneWidget);
    expect(find.text('Monumental'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('negocios card shows directory fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: NegociosCremasBrowsePage(
          locationService: _Points([
            _point(
              type: 'BUSINESS',
              name: 'Café Monumental',
              description: 'Comida · Café y panadería cerca de la hinchada.',
              address: 'Av. Javier Prado 120, Lima',
              verified: true,
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Café Monumental'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Av. Javier Prado 120, Lima'), findsOneWidget);
    expect(find.text('Verificado'), findsOneWidget);
    expect(find.text('Café y panadería cerca de la hinchada.'), findsOneWidget);
    expect(find.text('Ver en el mapa'), findsOneWidget);
    expect(find.text('No hay negocios registrados todavía'), findsNothing);
  });

  testWidgets('profile solidarity and business forms fit a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    expect(find.text('IDENTIDAD'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('UBICACIÓN'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('HINCHA'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Año en que empezaste a alentar. Ejemplo: 2012'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('PRIVACIDAD'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Guardar cambios'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Guardar'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const SolidariaCreatePage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cuéntanos brevemente qué apoyo necesitas.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('TIPO'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('DETALLE'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('UBICACIÓN Y CONTACTO'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Enviar a revisión'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(
        'No procesamos dinero. Garra solo facilita el contacto entre hinchas.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const RegistrarNegocioCremaPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('TU NEGOCIO'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Elegir en mapa'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('CONTACTO'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('LEGAL'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Enviar solicitud'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quiero vender'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Points extends LocationService {
  _Points(this.points) : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<CremaPointModel> points;

  @override
  Future<List<CremaPointModel>> getActivePoints() async => points;
}

CremaPointModel _point({
  required String type,
  required String name,
  String description = '',
  String address = 'Lima',
  bool verified = false,
}) {
  return CremaPointModel(
    id: name,
    name: name,
    description: description,
    type: type,
    address: address,
    latitude: -12.05,
    longitude: -77.03,
    verified: verified,
    sponsor: false,
    status: 'ACTIVE',
    createdAt: '2026-09-25T00:00:00Z',
    updatedAt: '2026-09-25T00:00:00Z',
  );
}
