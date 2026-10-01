import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:garra_digital_app/features/locations/data/business_social_links.dart';
import 'package:garra_digital_app/features/locations/data/crema_point_model.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_application_service.dart';
import 'package:garra_digital_app/features/locations/data/location_service.dart';
import 'package:garra_digital_app/features/locations/presentation/mi_negocio_crema_page.dart';
import 'package:garra_digital_app/features/locations/presentation/map_crema_page.dart';
import 'package:garra_digital_app/features/locations/presentation/negocios_cremas_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class _FakeLocations extends LocationService {
  _FakeLocations(this.point);
  final CremaPointModel point;

  @override
  Future<List<CremaPointModel>> getActivePoints() async => [point];
}

class _FakeCategories extends CremaBusinessApplicationService {
  _FakeCategories({this.fail = false});
  bool fail;
  int calls = 0;

  @override
  Future<List<String>> listCategories() async {
    calls++;
    if (fail) throw StateError('offline');
    return ['Comida', 'Servicios'];
  }
}

const _point = CremaPointModel(
  id: 'business-123',
  name: 'Negocio Crema',
  description: 'Comida',
  type: 'BUSINESS',
  address: 'San Miguel',
  latitude: -12.08,
  longitude: -77.09,
  verified: true,
  sponsor: false,
  status: 'ACTIVE',
  createdAt: '',
  updatedAt: '',
  instagram: 'https://www.instagram.com/crema',
);

void main() {
  test('social links accept handles and only official HTTPS profile URLs', () {
    expect(
      businessSocialUri(BusinessSocialNetwork.instagram, '@crema').toString(),
      'https://www.instagram.com/crema',
    );
    expect(
      businessSocialUri(
        BusinessSocialNetwork.facebook,
        'https://facebook.com/crema',
      ).toString(),
      'https://www.facebook.com/crema',
    );
    expect(
      businessSocialUri(BusinessSocialNetwork.tiktok, '@crema').toString(),
      'https://www.tiktok.com/@crema',
    );
    expect(
      businessSocialUri(
        BusinessSocialNetwork.instagram,
        'https://evil.example/crema',
      ),
      isNull,
    );
    expect(
      businessSocialUri(
        BusinessSocialNetwork.facebook,
        'http://facebook.com/crema',
      ),
      isNull,
    );
  });

  test(
    'focused business map uses saved coordinates without requesting GPS',
    () {
      expect(shouldLoadMapCurrentLocation(_point.id), isFalse);
      expect(shouldLoadMapCurrentLocation(null), isTrue);
      final target = initialBusinessMapTarget(
        _point,
        const LatLng(-12.1, -77.1),
      );
      expect(target.latitude, _point.latitude);
      expect(target.longitude, _point.longitude);
    },
  );

  testWidgets('business detail opens map focused on stored business ID', (
    tester,
  ) async {
    String? selectedId;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => NegocioCremaDetailPage(
            idOrSlug: _point.id,
            locationService: _FakeLocations(_point),
          ),
        ),
        GoRoute(
          path: '/negocios/mapa',
          builder: (_, state) {
            selectedId = state.uri.queryParameters['pointId'];
            return const Scaffold(body: Text('Mapa del negocio'));
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('San Miguel'), findsOneWidget);
    await tester.tap(find.text('Ver ubicación del negocio'));
    await tester.pumpAndSettle();
    expect(selectedId, _point.id);
  });

  testWidgets(
    'registration keeps selected location label and controlled category',
    (tester) async {
      final categories = _FakeCategories();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                RegistrarNegocioCremaPage(categoryService: categories),
          ),
          GoRoute(
            path: '/negocios/mi-negocio/ubicacion',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(<String, dynamic>{
                  'lat': -12.08,
                  'lng': -77.09,
                  'label': 'San Miguel',
                }),
                child: const Text('Confirmar punto'),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(categories.calls, 1);
      expect(find.byType(DropdownMenu<String>), findsOneWidget);
      await tester.ensureVisible(find.text('Elegir ubicación en mapa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir ubicación en mapa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar punto'));
      await tester.pumpAndSettle();
      expect(find.text('San Miguel'), findsOneWidget);
      expect(find.text('Cambiar ubicación'), findsOneWidget);
    },
  );

  testWidgets('category error offers retry without losing draft', (
    tester,
  ) async {
    final categories = _FakeCategories(fail: true);
    await tester.pumpWidget(
      MaterialApp(home: RegistrarNegocioCremaPage(categoryService: categories)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar las categorías'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Mi negocio');
    categories.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar las categorías'), findsNothing);
    expect(find.text('Mi negocio'), findsOneWidget);
    expect(categories.calls, 2);
  });

  testWidgets('legacy category remains selected outside current catalogue', (
    tester,
  ) async {
    const legacy = CremaBusinessApplication(
      id: 'legacy',
      businessName: 'Bar Crema',
      category: 'Bar',
      address: 'Callao',
      latitude: -12.04,
      longitude: -77.13,
      status: CremaBusinessApplicationStatus.draft,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrarNegocioCremaPage(
          existing: legacy,
          categoryService: _FakeCategories(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bar'), findsOneWidget);
  });
}
