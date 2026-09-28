import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_media_service.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_models.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_service.dart';
import 'package:garra_digital_app/features/marketplace/presentation/providers/marketplace_provider.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_dashboard_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_listing_form_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_store_form_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_store_page.dart';
import 'package:go_router/go_router.dart';

/// MARKETPLACE_V2_A1: multi-business (max 3 non-archived stores). Every
/// request is observed on the wire (method + path + body) through a Dio
/// interceptor; store-specific calls must carry the explicit storeId and new
/// flows never touch the legacy singular /seller/me/store aliases.

const _me = '/marketplace/seller/me';

class _Call {
  _Call(this.method, this.path, this.data);

  final String method;
  final String path;
  final dynamic data;

  @override
  String toString() => '$method $path';
}

class _Wire {
  _Wire({List<Map<String, dynamic>>? stores, this.conflictOnCreate = false})
    : stores = stores ?? [] {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add(_Call(options.method, options.path, options.data));
          if (conflictOnCreate &&
              options.method == 'POST' &&
              options.path == '$_me/stores') {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 409,
                  data: {
                    'success': false,
                    'message': 'Puedes administrar hasta 3 negocios activos.',
                  },
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': _respond(options)},
            ),
          );
        },
      ),
    );
  }

  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
  final List<Map<String, dynamic>> stores;
  final bool conflictOnCreate;
  final List<_Call> calls = [];

  List<String> get lines => [for (final c in calls) c.toString()];

  Iterable<String> get writes => lines.where((l) => !l.startsWith('GET '));

  _Call last(String method, String path) =>
      calls.lastWhere((c) => c.method == method && c.path == path);

  dynamic _respond(RequestOptions o) {
    final path = o.path;
    if (path == '/marketplace/categories') {
      return [
        {'id': 'c1', 'slug': 'ropa-accesorios', 'name': 'Ropa'},
      ];
    }
    if (path == '$_me/summary') {
      return {
        'sellerStatus': 'ACTIVE',
        'activeListings': 0,
        'favoritesReceived': 0,
        'contactLeads': 0,
        'storeCount': stores.length,
        'nonArchivedStoreCount': stores
            .where((s) => s['status'] != 'ARCHIVED')
            .length,
      };
    }
    if (path == '$_me/plan') return <String, dynamic>{};
    if (path == '$_me/stores') {
      if (o.method == 'POST') {
        final body = Map<String, dynamic>.from(o.data as Map);
        final created = _store('s-new', body['name'] as String, 'DRAFT');
        stores.add(created);
        return created;
      }
      return stores;
    }
    final byId = RegExp('^$_me/stores/([^/]+)(/.*)?\$').firstMatch(path);
    if (byId != null) {
      final id = byId.group(1)!;
      final rest = byId.group(2) ?? '';
      final store = stores.firstWhere(
        (s) => s['id'] == id,
        orElse: () => _store(id, 'Desconocido', 'DRAFT'),
      );
      if (rest == '/listings' && o.method == 'GET') {
        return [_listing('$id-l1', 'Polo de $id', id)];
      }
      if (rest == '/listings' && o.method == 'POST') {
        final body = Map<String, dynamic>.from(o.data as Map);
        return _listing('new-listing', body['title'] as String, id);
      }
      if (rest == '/submit') return {...store, 'status': 'PENDING_REVIEW'};
      if (rest == '/archive') return {...store, 'status': 'ARCHIVED'};
      if (o.method == 'PATCH') {
        return {...store, ...Map<String, dynamic>.from(o.data as Map)};
      }
      return store;
    }
    return <String, dynamic>{};
  }
}

Map<String, dynamic> _store(String id, String name, String status) => {
  'id': id,
  'slug': 'slug-$id',
  'name': name,
  'status': status,
};

Map<String, dynamic> _listing(String id, String title, String storeId) => {
  'id': id,
  'slug': 'slug-$id',
  'title': title,
  'description': 'desc',
  'type': 'PRODUCT',
  'status': 'DRAFT',
  'priceAmount': 30,
  'currencyCode': 'PEN',
  'priceOnRequest': false,
  'category': {'id': 'c1', 'slug': 'ropa-accesorios', 'name': 'Ropa'},
  'images': <Map<String, dynamic>>[],
  'storeId': storeId,
};

List<Map<String, dynamic>> _stores(int count, {int archived = 0}) => [
  for (var i = 1; i <= count; i++) _store('s$i', 'Negocio $i', 'ACTIVE'),
  for (var i = 1; i <= archived; i++) _store('a$i', 'Viejo $i', 'ARCHIVED'),
];

Future<void> _pumpApp(
  WidgetTester tester,
  _Wire wire, {
  String initial = '/marketplace/seller/dashboard',
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/marketplace/seller/dashboard',
        builder: (_, _) => const SellerDashboardPage(),
      ),
      GoRoute(
        path: '/marketplace/seller/stores/new',
        builder: (_, _) => const SellerStoreFormPage(),
      ),
      GoRoute(
        path: '/marketplace/seller/stores/:storeId',
        builder: (_, s) =>
            SellerStorePage(storeId: s.pathParameters['storeId'] ?? ''),
      ),
      GoRoute(
        path: '/marketplace/seller/stores/:storeId/edit',
        builder: (_, s) =>
            SellerStoreFormPage(storeId: s.pathParameters['storeId'] ?? ''),
      ),
      GoRoute(
        path: '/marketplace/seller/stores/:storeId/listings/new',
        builder: (_, s) =>
            SellerListingFormPage(storeId: s.pathParameters['storeId'] ?? ''),
      ),
      GoRoute(
        path: '/marketplace/seller/listings/new',
        builder: (_, _) => const SellerListingFormPage(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketplaceServiceProvider.overrideWithValue(
          MarketplaceService(dio: wire.dio),
        ),
        marketplaceMediaServiceProvider.overrideWithValue(
          MarketplaceMediaService(dio: wire.dio),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fills the listing form (price on request, first category) without images.
Future<void> _fillListingForm(WidgetTester tester, String title) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), title);
  await tester.enterText(fields.at(1), 'Descripcion de prueba');
  await tester.tap(find.text('Precio a consultar'));
  await tester.pumpAndSettle();
  final dropdowns = find.byType(DropdownButtonFormField<String>);
  await tester.tap(dropdowns.last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ropa').last);
  await tester.pumpAndSettle();
}

void _expectNoLegacyStoreCalls(_Wire wire) {
  expect(
    wire.lines.where(
      (l) => l.contains('$_me/store/') || l.endsWith('$_me/store'),
    ),
    isEmpty,
  );
  expect(wire.lines, isNot(contains('POST $_me/listings')));
}

void main() {
  group('A1 service contract', () {
    test(
      'GET /seller/me/stores parses businesses with ids and statuses',
      () async {
        final wire = _Wire(stores: _stores(2, archived: 1));
        final stores = await MarketplaceService(
          dio: wire.dio,
        ).getSellerStores();

        expect(wire.lines, ['GET $_me/stores']);
        expect(stores.map((s) => s.id), ['s1', 's2', 'a1']);
        expect(stores.last.isArchived, isTrue);
        expect(stores.first.isArchived, isFalse);
      },
    );

    test('create business: POST /seller/me/stores with a valid slug', () async {
      final wire = _Wire();
      final store = await MarketplaceService(
        dio: wire.dio,
      ).createSellerStore(name: 'Caf\u00e9 Crema', city: 'Lima');

      expect(wire.lines, ['POST $_me/stores']);
      final body = wire.calls.single.data as Map;
      expect(body['name'], 'Caf\u00e9 Crema');
      expect(body['city'], 'Lima');
      expect(body['countryCode'], 'PE');
      expect(body['slug'], matches(RegExp(r'^cafe-crema-[a-z0-9]+$')));
      expect(store.id, 's-new');
    });

    test('4th business: 409 surfaces the backend limit message', () async {
      final wire = _Wire(stores: _stores(3), conflictOnCreate: true);
      await expectLater(
        MarketplaceService(dio: wire.dio).createSellerStore(name: 'Cuarto'),
        throwsA(
          isA<MarketplaceServiceException>().having(
            (e) => e.message,
            'message',
            'Puedes administrar hasta 3 negocios activos.',
          ),
        ),
      );
    });

    test('store operations use the explicit storeId', () async {
      final wire = _Wire(stores: _stores(3));
      final service = MarketplaceService(dio: wire.dio);

      final store = await service.getSellerStoreById('s2');
      await service.updateSellerStoreById('s2', {'name': 'Nuevo nombre'});
      final submitted = await service.submitSellerStoreById('s2');
      final archived = await service.archiveSellerStore('s3');
      final listings = await service.getSellerStoreListings('s2');
      await MarketplaceMediaService(
        dio: wire.dio,
      ).updateStoreMedia(storeId: 's2', logoMediaAssetId: 'asset-1');

      expect(wire.lines, [
        'GET $_me/stores/s2',
        'PATCH $_me/stores/s2',
        'POST $_me/stores/s2/submit',
        'POST $_me/stores/s3/archive',
        'GET $_me/stores/s2/listings',
        'PUT $_me/stores/s2/media',
      ]);
      expect(store.name, 'Negocio 2');
      expect(wire.calls[1].data, {'name': 'Nuevo nombre'});
      expect(wire.calls[2].data, {'ipAcknowledged': true});
      expect(submitted.status, 'PENDING_REVIEW');
      expect(archived.isArchived, isTrue);
      expect(listings.single.storeId, 's2');
      _expectNoLegacyStoreCalls(wire);
    });

    test(
      'create listing in store: POST /seller/me/stores/{id}/listings',
      () async {
        final wire = _Wire(stores: _stores(2));
        final listing = await MarketplaceService(dio: wire.dio)
            .createSellerListingInStore(
              's2',
              const SellerListingRequest(
                title: 'Gorro',
                description: 'Lana',
                categorySlug: 'ropa-accesorios',
                price: 40,
              ),
            );

        expect(wire.lines, ['POST $_me/stores/s2/listings']);
        final body = wire.calls.single.data as Map;
        expect(body['slug'], matches(RegExp(r'^gorro-[a-z0-9]+$')));
        expect(body['priceAmount'], 40);
        expect(body.containsKey('storeId'), isFalse);
        expect(listing.storeId, 's2');
      },
    );

    test('summary exposes store counters; store slug helper fits 3-64', () {
      final summary = SellerSummary.fromJson({
        'sellerStatus': 'ACTIVE',
        'storeCount': 4,
        'nonArchivedStoreCount': 3,
      });
      expect(summary.storeCount, 4);
      expect(summary.nonArchivedStoreCount, 3);

      final now = DateTime.utc(2026, 9, 28);
      final suffix = now.millisecondsSinceEpoch.toRadixString(36);
      final pattern = RegExp(r'^[a-z0-9-]{3,64}$');
      expect(marketplaceStoreSlug('!!', now: now), 'negocio-$suffix');
      for (final slug in [
        marketplaceStoreSlug('a' * 120, now: now),
        marketplaceStoreSlug('\u00d1', now: now),
        marketplaceStoreSlug('Tienda Sur', now: now),
      ]) {
        expect(pattern.hasMatch(slug), isTrue, reason: slug);
      }
      expect(kMarketplaceMaxStores, 3);
    });
  });

  group('A1 Mis negocios', () {
    for (final count in [1, 2, 3]) {
      testWidgets('renders $count business(es) from one GET /stores', (
        tester,
      ) async {
        final wire = _Wire(stores: _stores(count));
        await _pumpApp(tester, wire);

        expect(find.text('Mis negocios'), findsOneWidget);
        for (var i = 1; i <= count; i++) {
          expect(find.byKey(Key('seller-store-card-s$i')), findsOneWidget);
          expect(find.text('Negocio $i'), findsOneWidget);
        }
        expect(find.text('$count/3'), findsOneWidget);
        expect(wire.lines.where((l) => l == 'GET $_me/stores'), hasLength(1));
        expect(
          wire.lines.where((l) => l.startsWith('GET $_me/stores/')),
          isEmpty,
        );
        final create = tester.widget<OutlinedButton>(
          find.byKey(const Key('seller-store-create')),
        );
        if (count < 3) {
          expect(create.onPressed, isNotNull);
          expect(find.byKey(const Key('seller-stores-limit')), findsNothing);
        } else {
          expect(create.onPressed, isNull);
          expect(
            find.text('Puedes administrar hasta 3 negocios.'),
            findsOneWidget,
          );
        }
      });
    }

    testWidgets('archived businesses are history and free a slot', (
      tester,
    ) async {
      final wire = _Wire(stores: _stores(2, archived: 2));
      await _pumpApp(tester, wire);

      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('Archivados'), findsOneWidget);
      expect(find.byKey(const Key('seller-store-archived-a1')), findsOneWidget);
      expect(find.byKey(const Key('seller-store-card-a1')), findsNothing);
      final create = tester.widget<OutlinedButton>(
        find.byKey(const Key('seller-store-create')),
      );
      expect(create.onPressed, isNotNull);
    });

    for (final existing in [1, 2]) {
      testWidgets('creates business #${existing + 1} via POST /stores', (
        tester,
      ) async {
        final wire = _Wire(stores: _stores(existing));
        await _pumpApp(tester, wire);

        await tester.tap(find.byKey(const Key('seller-store-create')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('store-form-name')),
          'Tienda Nueva',
        );
        await tester.tap(find.byKey(const Key('store-form-save')));
        await tester.pumpAndSettle();

        final post = wire.last('POST', '$_me/stores');
        expect((post.data as Map)['name'], 'Tienda Nueva');
        expect(wire.writes, ['POST $_me/stores']);
        expect(wire.lines, isNot(contains('POST $_me')));
        // Lands on the new business managed by its id.
        expect(wire.lines, contains('GET $_me/stores/s-new'));
        expect(find.text('Estado: Borrador'), findsOneWidget);
        _expectNoLegacyStoreCalls(wire);
      });
    }

    testWidgets('manage opens the chosen store and scopes its listings', (
      tester,
    ) async {
      final wire = _Wire(stores: _stores(3));
      await _pumpApp(tester, wire);

      await tester.tap(find.byKey(const Key('seller-store-manage-s2')));
      await tester.pumpAndSettle();

      expect(wire.lines, contains('GET $_me/stores/s2'));
      expect(wire.lines, contains('GET $_me/stores/s2/listings'));
      expect(wire.lines.where((l) => l.contains('/stores/s1')), isEmpty);
      expect(wire.lines.where((l) => l.contains('/stores/s3')), isEmpty);
      expect(wire.lines, isNot(contains('GET $_me/listings')));
      expect(find.text('Publicaciones'), findsOneWidget);
      expect(find.text('Polo de s2'), findsOneWidget);
      expect(find.text('Polo de s1'), findsNothing);

      await tester.tap(find.byKey(const Key('seller-store-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('store-form-name')),
        'Negocio Dos',
      );
      await tester.tap(find.byKey(const Key('store-form-save')));
      await tester.pumpAndSettle();

      final patch = wire.last('PATCH', '$_me/stores/s2');
      expect((patch.data as Map)['name'], 'Negocio Dos');
      expect(wire.writes, ['PATCH $_me/stores/s2']);
      _expectNoLegacyStoreCalls(wire);
    });

    testWidgets('submit sends the managed storeId', (tester) async {
      final wire = _Wire(
        stores: [
          _store('s1', 'Negocio 1', 'ACTIVE'),
          _store('s2', 'Negocio 2', 'DRAFT'),
        ],
      );
      await _pumpApp(tester, wire, initial: '/marketplace/seller/stores/s2');

      await tester.tap(find.byKey(const Key('seller-store-submit')));
      await tester.pumpAndSettle();

      expect(wire.writes, ['POST $_me/stores/s2/submit']);
      expect(wire.last('POST', '$_me/stores/s2/submit').data, {
        'ipAcknowledged': true,
      });
      _expectNoLegacyStoreCalls(wire);
    });

    testWidgets(
      'statuses: pending waits, active operates, archived is read-only',
      (tester) async {
        final wire = _Wire(
          stores: [
            _store('p1', 'Pendiente', 'PENDING_REVIEW'),
            _store('x1', 'Archivado', 'ARCHIVED'),
          ],
        );
        await _pumpApp(tester, wire, initial: '/marketplace/seller/stores/p1');
        expect(find.text('Estado: En revisi\u00f3n'), findsOneWidget);
        expect(find.byKey(const Key('seller-store-submit')), findsNothing);
        expect(find.byKey(const Key('seller-store-edit')), findsOneWidget);
        expect(
          find.byKey(const Key('seller-store-new-listing')),
          findsOneWidget,
        );

        await _pumpApp(tester, wire, initial: '/marketplace/seller/stores/x1');
        expect(find.text('Estado: Archivado'), findsOneWidget);
        expect(find.byKey(const Key('seller-store-edit')), findsNothing);
        expect(find.byKey(const Key('seller-store-new-listing')), findsNothing);
        expect(wire.writes, isEmpty);
      },
    );
  });

  group('A1 listing creation is store-explicit', () {
    testWidgets('from a business the store is preselected', (tester) async {
      final wire = _Wire(stores: _stores(3));
      await _pumpApp(tester, wire, initial: '/marketplace/seller/stores/s3');

      await tester.tap(find.byKey(const Key('seller-store-new-listing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('listing-store-select')), findsNothing);
      expect(find.text('Negocio: Negocio 3'), findsOneWidget);

      await _fillListingForm(tester, 'Polo tres');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(wire.writes, ['POST $_me/stores/s3/listings']);
      expect(
        (wire.last('POST', '$_me/stores/s3/listings').data as Map)['title'],
        'Polo tres',
      );
      _expectNoLegacyStoreCalls(wire);
    });

    testWidgets('without context and one business it is auto-selected', (
      tester,
    ) async {
      final wire = _Wire(stores: _stores(1, archived: 1));
      await _pumpApp(tester, wire);

      await tester.tap(find.byTooltip('Nueva publicaci\u00f3n'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('listing-store-select')), findsNothing);
      expect(find.text('Negocio: Negocio 1'), findsOneWidget);

      await _fillListingForm(tester, 'Polo uno');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(wire.writes, ['POST $_me/stores/s1/listings']);
      _expectNoLegacyStoreCalls(wire);
    });

    testWidgets('without context and 2+ businesses the seller must choose', (
      tester,
    ) async {
      final wire = _Wire(stores: _stores(3));
      await _pumpApp(tester, wire);

      await tester.tap(find.byTooltip('Nueva publicaci\u00f3n'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('listing-store-select')), findsOneWidget);

      await _fillListingForm(tester, 'Polo elegido');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(wire.writes, isEmpty);
      expect(find.text('Elige el negocio'), findsWidgets);

      await tester.tap(find.byKey(const Key('listing-store-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Negocio 2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(wire.writes, ['POST $_me/stores/s2/listings']);
      _expectNoLegacyStoreCalls(wire);
    });
  });
}
