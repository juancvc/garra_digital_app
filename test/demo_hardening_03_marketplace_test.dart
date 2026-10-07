import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/router/app_router.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_media_service.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_models.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_service.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_url_launcher.dart';
import 'package:garra_digital_app/features/marketplace/presentation/listing_detail_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/marketplace_chat_button.dart';
import 'package:garra_digital_app/features/marketplace/presentation/marketplace_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/providers/marketplace_provider.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_dashboard_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_listing_form_page.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_store_page.dart';
import 'package:go_router/go_router.dart';

/// DEMO_HARDENING_03: Marketplace demo lifecycle against the real wire
/// contract (Dio interceptor, real MarketplaceService/MediaService).
/// seller create -> review -> buyer discover/detail/contact -> seller
/// edit/deactivate -> buyer no longer discovers it.

const _me = '/marketplace/seller/me';
const _id = '7b0c2a52-1111-4a5e-9a51-000000000001';

class _Call {
  _Call(this.method, this.path, this.data, this.query);
  final String method;
  final String path;
  final dynamic data;
  final Map<String, dynamic> query;
  @override
  String toString() => '$method $path';
}

class _Fail {
  const _Fail(this.status, [this.message = '']);
  final int status;
  final String message;
}

class _Wire {
  _Wire() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          calls.add(
            _Call(
              options.method,
              options.path,
              options.data,
              Map<String, dynamic>.from(options.queryParameters),
            ),
          );
          final gate = gates['${options.method} ${options.path}'];
          if (gate != null) await gate.future;
          final result = _respond(options);
          if (result is _Fail) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: result.status,
                  data: {'success': false, 'message': result.message},
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': result},
            ),
          );
        },
      ),
    );
  }

  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
  final List<_Call> calls = [];
  final Map<String, Completer<void>> gates = {};

  /// Server-side state.
  final Map<String, Map<String, dynamic>> listings = {};
  String storeStatus = 'ACTIVE';
  int listingsFailures = 0;
  int submitFailures = 0;
  String submitFailureMessage = 'Store must be ACTIVE to publish listings';
  bool contactRejected = false;

  /// Who is looking at public detail: owner sees non-public (canContact
  /// false), buyers get 404 like MarketplaceService.getListingBySlug.
  bool viewerIsOwner = false;

  List<String> get lines => calls.map((c) => c.toString()).toList();
  List<String> get writes =>
      calls.where((c) => c.method != 'GET').map((c) => c.toString()).toList();
  _Call last(String method, String path) =>
      calls.lastWhere((c) => c.method == method && c.path == path);

  Map<String, dynamic> get store => {
    'id': 's1',
    'slug': 'tienda-crema',
    'name': 'Tienda Crema',
    'status': storeStatus,
  };

  bool _public(Map<String, dynamic> l) =>
      l['status'] == 'ACTIVE' && storeStatus == 'ACTIVE';

  Map<String, dynamic> _detail(Map<String, dynamic> l) => {
    ...l,
    'canContact': _public(l),
    'store': {'slug': 'tienda-crema', 'name': 'Tienda Crema'},
  };

  Object? _respond(RequestOptions o) {
    final p = o.path;
    final m = o.method;
    if (p == '/marketplace/categories') {
      return [
        {'id': 'c1', 'slug': 'ropa-accesorios', 'name': 'Ropa'},
      ];
    }
    if (p == '/marketplace/featured') return <String, dynamic>{};
    if (p == _me && m == 'GET') return null;
    if (p == '$_me/summary') {
      return {'sellerStatus': 'ACTIVE', 'storeStatus': storeStatus};
    }
    if (p == '$_me/plan') return <String, dynamic>{};
    if (p == '$_me/stores') return [store];
    if (p == '$_me/stores/s1') return store;
    if (p == '$_me/stores/s1/listings' && m == 'GET') {
      return listings.values.toList();
    }
    if (p == '$_me/stores/s1/listings' && m == 'POST') {
      final body = Map<String, dynamic>.from(o.data as Map);
      final created = _listing(
        id: _id,
        slug: body['slug'] as String,
        title: body['title'] as String,
        status: 'DRAFT',
        images: [
          for (final (i, img) in (body['images'] as List? ?? []).indexed)
            {
              'id': 'img-$i',
              'mediaAssetId': (img as Map)['mediaAssetId'],
              'imageUrl': 'https://cdn.test/$i.jpg',
              'sortOrder': i,
            },
        ],
      );
      listings[_id] = created;
      return created;
    }
    final own = RegExp('^$_me/listings/([^/]+)(/[a-z]+)?\$').firstMatch(p);
    if (own != null) {
      final l = listings[own.group(1)];
      if (l == null) return const _Fail(404, 'Marketplace listing not found');
      switch (own.group(2)) {
        case null when m == 'PATCH':
          final body = Map<String, dynamic>.from(o.data as Map);
          if (l['status'] == 'ARCHIVED') {
            return const _Fail(400, 'Listing cannot be edited in current status');
          }
          l['title'] = body['title'] ?? l['title'];
          if (body['images'] is List) {
            l['images'] = [
              for (final (i, img) in (body['images'] as List).indexed)
                {
                  'id': 'img-$i',
                  'mediaAssetId': (img as Map)['mediaAssetId'],
                  'imageUrl': 'https://cdn.test/$i.jpg',
                  'sortOrder': i,
                },
            ];
          }
          return l;
        case '/submit':
          if (submitFailures > 0) {
            submitFailures--;
            return _Fail(400, submitFailureMessage);
          }
          l['status'] = 'PENDING_REVIEW';
          return l;
        case '/archive':
          l['status'] = 'ARCHIVED';
          return l;
      }
    }
    if (p == '/marketplace/listings' && m == 'GET') {
      if (listingsFailures > 0) {
        listingsFailures--;
        return const _Fail(500, 'boom');
      }
      final search = (o.queryParameters['search'] as String?) ?? '';
      final items = listings.values
          .where(_public)
          .where(
            (l) => (l['title'] as String).toLowerCase().contains(
              search.toLowerCase(),
            ),
          )
          .map(_detail)
          .toList();
      return {'items': items, 'page': 0, 'size': 20, 'hasNext': false};
    }
    final contact = RegExp(r'^/marketplace/listings/([^/]+)/contact$').firstMatch(p);
    if (contact != null) {
      if (contactRejected) {
        return const _Fail(400, 'Listing is not available for contact');
      }
      return {
        'whatsappUri': 'https://wa.me/51911112222?text=Hola',
        'message': 'Hola',
      };
    }
    final detail = RegExp(r'^/marketplace/listings/([^/]+)$').firstMatch(p);
    if (detail != null) {
      final match = listings.values.where((l) => l['slug'] == detail.group(1));
      if (match.isEmpty) return const _Fail(404, 'Marketplace listing not found');
      final l = match.first;
      if (!_public(l) && !viewerIsOwner) {
        return const _Fail(404, 'Marketplace listing not found');
      }
      return _detail(l);
    }
    return <String, dynamic>{};
  }
}

Map<String, dynamic> _listing({
  String id = _id,
  String slug = 'polo-crema',
  String title = 'Polo Crema',
  String status = 'ACTIVE',
  List<Map<String, dynamic>> images = const [],
}) => {
  'id': id,
  'slug': slug,
  'title': title,
  'description': 'Talla M, nuevo',
  'type': 'PRODUCT',
  'status': status,
  'priceAmount': 80,
  'currencyCode': 'PEN',
  'priceOnRequest': false,
  'category': {'id': 'c1', 'slug': 'ropa-accesorios', 'name': 'Ropa'},
  'images': images,
  'storeId': 's1',
};

Future<GoRouter> _pump(
  WidgetTester tester,
  _Wire wire, {
  required String initial,
  Size size = const Size(900, 2400),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/marketplace', builder: (_, _) => const MarketplacePage()),
      GoRoute(
        path: '/marketplace/listings/:slug',
        builder: (_, s) =>
            ListingDetailPage(slug: s.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/marketplace/stores/:slug',
        builder: (_, s) => Scaffold(body: Text('store ${s.pathParameters['slug']}')),
      ),
      GoRoute(
        path: '/marketplace/seller',
        builder: (_, _) => const Scaffold(body: Text('onboarding')),
      ),
      GoRoute(
        path: '/marketplace/seller/dashboard',
        builder: (_, _) => const SellerDashboardPage(),
      ),
      GoRoute(
        path: '/marketplace/seller/stores/:storeId',
        builder: (_, s) =>
            SellerStorePage(storeId: s.pathParameters['storeId'] ?? ''),
      ),
      GoRoute(
        path: '/marketplace/seller/stores/:storeId/listings/new',
        builder: (_, s) =>
            SellerListingFormPage(storeId: s.pathParameters['storeId'] ?? ''),
      ),
      GoRoute(
        path: '/marketplace/seller/listings/:slug/edit',
        builder: (_, s) =>
            SellerListingFormPage(slug: s.pathParameters['slug'] ?? ''),
      ),
    ],
  );
  addTearDown(router.dispose);
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
      child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _fillForm(
  WidgetTester tester, {
  String title = 'Polo Crema',
  String price = '80',
  bool pickCategory = true,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), title);
  await tester.enterText(fields.at(1), 'Talla M, nuevo');
  await tester.enterText(fields.at(2), price);
  if (pickCategory) {
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ropa').last);
    await tester.pumpAndSettle();
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  group('DH03 navigation audit (ids per route)', () {
    test('literal seller routes win over params; ids are the expected kind', () {
      final router = createAppRouter(redirect: (_, _) => null);
      addTearDown(router.dispose);
      String? name(String uri) =>
          router.configuration.findMatch(Uri.parse(uri)).last.route.name;
      expect(name('/marketplace/seller/listings/new'), 'marketplace-seller-listing-new');
      expect(name('/marketplace/seller/stores/new'), 'marketplace-seller-store-new');
      final storeNew = router.configuration.findMatch(
        Uri.parse('/marketplace/seller/stores/s1/listings/new'),
      );
      expect(storeNew.last.route.name, 'marketplace-seller-store-listing-new');
      expect(storeNew.pathParameters['storeId'], 's1');
      final edit = router.configuration.findMatch(
        Uri.parse('/marketplace/seller/listings/polo-crema-1a2b/edit'),
      );
      expect(edit.last.route.name, 'marketplace-seller-listing-edit');
      expect(edit.pathParameters['slug'], 'polo-crema-1a2b');
      final detail = router.configuration.findMatch(
        Uri.parse('/marketplace/listings/polo-crema-1a2b'),
      );
      expect(detail.last.route.name, 'marketplace-listing');
      expect(detail.pathParameters['slug'], 'polo-crema-1a2b');
    });
  });

  group('DH03 request contract', () {
    test('ordered photo set: cover first, only valid refs, null keeps photos', () {
      const request = SellerListingRequest(
        title: ' Polo ',
        description: 'd',
        categorySlug: 'ropa-accesorios',
        price: 80,
        images: [
          SellerListingImageRef(mediaAssetId: 'a2'),
          SellerListingImageRef(imageUrl: 'http://insecure/x.jpg'),
          SellerListingImageRef(imageUrl: 'https://legacy/y.jpg'),
          SellerListingImageRef(mediaAssetId: 'a1'),
        ],
      );
      expect(request.toJson()['images'], [
        {'mediaAssetId': 'a2', 'sortOrder': 0},
        {'imageUrl': 'https://legacy/y.jpg', 'sortOrder': 1},
        {'mediaAssetId': 'a1', 'sortOrder': 2},
      ]);
      expect(request.toCreateJson()['images'], hasLength(3));
      const noImages = SellerListingRequest(
        title: 'x',
        description: 'd',
        categorySlug: 'c',
      );
      expect(noImages.toJson().containsKey('images'), isFalse);
    });

    test('canContact and lifecycle helpers mirror the backend', () {
      final owner = MarketplaceListing.fromJson({
        ..._listing(status: 'PENDING_REVIEW'),
        'canContact': false,
      });
      expect(owner.canContact, isFalse);
      expect(owner.canSubmitForReview, isFalse);
      expect(owner.isEditableByOwner, isTrue);
      expect(MarketplaceListing.fromJson(_listing()).canContact, isTrue);
      final archived = MarketplaceListing.fromJson(_listing(status: 'ARCHIVED'));
      expect(archived.isEditableByOwner, isFalse);
      expect(MarketplaceListing.fromJson(_listing(status: 'REJECTED')).canSubmitForReview, isTrue);
      expect(marketplaceListingStatusLabel('ARCHIVED'), 'Desactivada');
      expect(marketplaceListingStatusLabel('PENDING_REVIEW'), 'En revisi\u00f3n');
      expect(marketplaceListingStatusLabel('ACTIVE'), 'Publicada');
    });

    test('backend lifecycle errors are shown in Spanish', () {
      DioException fail(String message, [int status = 400]) {
        final o = RequestOptions(path: '/x');
        return DioException(
          requestOptions: o,
          response: Response(
            requestOptions: o,
            statusCode: status,
            data: {'message': message},
          ),
        );
      }

      expect(
        marketplaceListingErrorMessage(fail('Store must be ACTIVE to publish listings')),
        contains('negocio a\u00fan no est\u00e1 aprobado'),
      );
      expect(
        marketplaceListingErrorMessage(fail('Seller must be ACTIVE')),
        contains('perfil de vendedor'),
      );
      expect(
        marketplaceListingErrorMessage(fail('Listing cannot be edited in current status')),
        'Esta publicaci\u00f3n ya no se puede editar.',
      );
      expect(
        marketplaceListingErrorMessage(fail('Max listing images exceeded')),
        contains('5 fotos'),
      );
      expect(marketplaceListingErrorMessage(fail('???', 500)), contains('No pudimos guardar'));
    });
  });

  group('DH03 buyer discovery', () {
    testWidgets('loads community products with title and price; opens detail', (tester) async {
      final wire = _Wire()..listings[_id] = _listing();
      await _pump(tester, wire, initial: '/marketplace');
      expect(find.text('Polo Crema'), findsOneWidget);
      expect(find.text('S/ 80'), findsWidgets);
      await tester.tap(find.text('Polo Crema'));
      await tester.pumpAndSettle();
      expect(find.text('Publicaci\u00f3n'), findsOneWidget);
      expect(find.text('Contactar por WhatsApp'), findsOneWidget);
    });

    testWidgets('empty discovery has the published copy and no owner CTA', (tester) async {
      final wire = _Wire();
      await _pump(tester, wire, initial: '/marketplace');
      expect(find.byKey(const Key('marketplace-discovery-empty')), findsOneWidget);
      expect(find.text('A\u00fan no hay productos publicados'), findsOneWidget);
      expect(find.text('Ir a mis negocios'), findsNothing);
    });

    testWidgets('error ends in retry and retry recovers content', (tester) async {
      // Persistent outage (Riverpod's own retry cannot recover it).
      final wire = _Wire()
        ..listings[_id] = _listing()
        ..listingsFailures = 1 << 30;
      await _pump(tester, wire, initial: '/marketplace');
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Polo Crema'), findsNothing);
      // No silent provider retries behind a skeleton: one GET, then the CTA.
      expect(wire.lines.where((l) => l == 'GET /marketplace/listings'), hasLength(1));
      wire.listingsFailures = 0;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Polo Crema'), findsOneWidget);
    });

    testWidgets('search without results explains it and resets', (tester) async {
      final wire = _Wire()..listings[_id] = _listing();
      await _pump(tester, wire, initial: '/marketplace');
      await tester.enterText(find.byType(TextField).first, 'zapatillas');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('marketplace-search-empty')), findsOneWidget);
      expect(find.text('A\u00fan no hay productos publicados'), findsNothing);
      await tester.tap(find.text('Ver todos los productos'));
      await tester.pumpAndSettle();
      expect(find.text('Polo Crema'), findsOneWidget);
    });
  });

  group('DH03 buyer detail and contact', () {
    tearDown(() {
      marketplaceUrlLauncher = (uri) async => false;
    });

    testWidgets('public detail contacts the seller through WhatsApp', (tester) async {
      Uri? launched;
      marketplaceUrlLauncher = (uri) async {
        launched = uri;
        return true;
      };
      final wire = _Wire()..listings[_id] = _listing();
      await _pump(tester, wire, initial: '/marketplace/listings/polo-crema');
      expect(find.text('Polo Crema'), findsOneWidget);
      expect(find.text('Talla M, nuevo'), findsOneWidget);
      expect(find.text('Tienda Crema'), findsOneWidget);
      await tester.tap(find.text('Contactar por WhatsApp'));
      await tester.pumpAndSettle();
      expect(wire.lines, contains('POST /marketplace/listings/polo-crema/contact'));
      expect(launched?.host, 'wa.me');
    });

    testWidgets('contact rejected by the backend is explained in Spanish', (tester) async {
      final wire = _Wire()
        ..listings[_id] = _listing()
        ..contactRejected = true;
      await _pump(tester, wire, initial: '/marketplace/listings/polo-crema');
      await tester.tap(find.text('Contactar por WhatsApp'));
      await tester.pumpAndSettle();
      expect(find.text('Esta publicaci\u00f3n ya no est\u00e1 disponible.'), findsOneWidget);
    });

    testWidgets('owner preview of a non-public listing hides buyer CTAs', (tester) async {
      final wire = _Wire()
        ..viewerIsOwner = true
        ..listings[_id] = {..._listing(status: 'PENDING_REVIEW'), 'sellerUserId': 'u1'};
      await _pump(tester, wire, initial: '/marketplace/listings/polo-crema');
      expect(find.byKey(const Key('listing-not-public-note')), findsOneWidget);
      expect(find.textContaining('En revisi\u00f3n'), findsOneWidget);
      expect(find.text('Contactar por WhatsApp'), findsNothing);
      expect(find.byType(ConsultarPorChatButton), findsNothing);
    });

    testWidgets('a deactivated listing is unavailable, with a way back', (tester) async {
      final wire = _Wire()..listings[_id] = _listing(status: 'ARCHIVED');
      await _pump(tester, wire, initial: '/marketplace/listings/polo-crema');
      expect(find.byKey(const Key('listing-unavailable')), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      await tester.tap(find.text('Ver Marketplace'));
      await tester.pumpAndSettle();
      expect(find.byType(MarketplacePage), findsOneWidget);
    });
  });

  group('DH03 seller create', () {
    testWidgets('first use -> CTA -> validated form -> submit -> back with status', (tester) async {
      final wire = _Wire();
      await _pump(tester, wire, initial: '/marketplace/seller/stores/s1');
      expect(find.text('A\u00fan no has publicado productos'), findsOneWidget);
      expect(find.text('Publica algo que quieras vender a la comunidad.'), findsOneWidget);
      await tester.tap(find.text('Publicar mi primer producto'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva publicaci\u00f3n'), findsOneWidget);
      expect(find.text('Negocio: Tienda Crema'), findsOneWidget);

      await _fillForm(tester);
      await _tapKey(tester, 'listing-submit');

      expect(wire.writes, [
        'POST $_me/stores/s1/listings',
        'POST $_me/listings/$_id/submit',
      ]);
      final body = wire.last('POST', '$_me/stores/s1/listings').data as Map;
      expect(body['title'], 'Polo Crema');
      expect(body['priceAmount'], 80);
      expect(body['categorySlug'], 'ropa-accesorios');
      expect(body['images'], isEmpty);
      expect(find.byType(SellerStorePage), findsOneWidget);
      expect(find.textContaining('enviada a revisi\u00f3n'), findsOneWidget);
      expect(find.byKey(const Key('listing-status-$_id')), findsOneWidget);
      expect(find.text('En revisi\u00f3n'), findsOneWidget);
    });

    testWidgets('validation: required, lengths, price and category', (tester) async {
      final wire = _Wire();
      await _pump(tester, wire, initial: '/marketplace/seller/stores/s1/listings/new');
      await _tapKey(tester, 'listing-submit');
      expect(find.text('Ingresa un t\u00edtulo'), findsOneWidget);
      expect(find.text('Ingresa una descripci\u00f3n'), findsOneWidget);
      expect(find.text('Ingresa un precio o marca consultar'), findsOneWidget);

      await _fillForm(tester, title: 'x' * 161, price: '-5', pickCategory: false);
      await _tapKey(tester, 'listing-submit');
      expect(find.text('M\u00e1ximo 160 caracteres'), findsOneWidget);
      expect(find.text('Precio inv\u00e1lido'), findsOneWidget);

      await _fillForm(tester, price: '0', pickCategory: false);
      await _tapKey(tester, 'listing-submit');
      expect(find.text('Ingresa un precio mayor a 0 o marca consultar'), findsOneWidget);

      await _fillForm(tester, price: '12.555', pickCategory: false);
      await _tapKey(tester, 'listing-submit');
      expect(find.text('Precio inv\u00e1lido'), findsOneWidget);

      await _fillForm(tester, price: '49.90', pickCategory: false);
      await _tapKey(tester, 'listing-submit');
      expect(find.text('Selecciona una categor\u00eda.'), findsOneWidget);
      expect(wire.writes, isEmpty);
    });

    testWidgets('no double submit while the first request is in flight', (tester) async {
      final wire = _Wire();
      final gate = Completer<void>();
      wire.gates['POST $_me/stores/s1/listings'] = gate;
      await _pump(tester, wire, initial: '/marketplace/seller/stores/s1/listings/new');
      await _fillForm(tester);
      final submit = find.byKey(const Key('listing-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.tap(submit, warnIfMissed: false);
      await tester.tap(find.byKey(const Key('listing-save')), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        wire.writes.where((w) => w == 'POST $_me/stores/s1/listings'),
        hasLength(1),
      );
    });

    testWidgets('submit failure keeps a draft, explains why, retry never duplicates', (tester) async {
      final wire = _Wire()..submitFailures = 1;
      await _pump(tester, wire, initial: '/marketplace/seller/stores/s1/listings/new');
      await _fillForm(tester);
      await _tapKey(tester, 'listing-submit');
      expect(find.textContaining('Guardamos tu publicaci\u00f3n como borrador'), findsOneWidget);
      expect(find.textContaining('negocio a\u00fan no est\u00e1 aprobado'), findsOneWidget);
      expect(find.byType(SellerListingFormPage), findsOneWidget);
      expect(find.text('Estado: Borrador'), findsOneWidget);

      await _tapKey(tester, 'listing-submit');
      expect(wire.writes, [
        'POST $_me/stores/s1/listings',
        'POST $_me/listings/$_id/submit',
        'PATCH $_me/listings/$_id',
        'POST $_me/listings/$_id/submit',
      ]);
    });
  });

  group('DH03 seller edit / deactivate', () {
    testWidgets('edit persists photo removal through the ordered set, no attach duplicates', (tester) async {
      final wire = _Wire()
        ..viewerIsOwner = true
        ..listings[_id] = _listing(
          status: 'DRAFT',
          images: [
            {'id': 'i1', 'imageUrl': 'https://cdn.test/a.jpg', 'mediaAssetId': 'a1', 'sortOrder': 0},
            {'id': 'i2', 'imageUrl': 'https://cdn.test/b.jpg', 'mediaAssetId': 'a2', 'sortOrder': 1},
          ],
        );
      await _pump(tester, wire, initial: '/marketplace/seller/listings/polo-crema/edit');
      expect(find.text('Estado: Borrador'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      await _tapKey(tester, 'listing-save');
      expect(wire.writes, ['PATCH $_me/listings/$_id']);
      expect((wire.last('PATCH', '$_me/listings/$_id').data as Map)['images'], [
        {'mediaAssetId': 'a2', 'sortOrder': 0},
      ]);
      expect(wire.lines.where((l) => l.contains('/images')), isEmpty);
    });

    testWidgets('live listing: save changes only, no resubmit', (tester) async {
      final wire = _Wire()
        ..viewerIsOwner = true
        ..listings[_id] = _listing();
      await _pump(tester, wire, initial: '/marketplace/seller/listings/polo-crema/edit');
      expect(find.text('Estado: Publicada'), findsOneWidget);
      expect(find.byKey(const Key('listing-submit')), findsNothing);
      expect(find.byKey(const Key('listing-save')), findsOneWidget);
      expect(find.byKey(const Key('listing-archive')), findsOneWidget);
    });

    testWidgets('archived listing is read-only', (tester) async {
      final wire = _Wire()
        ..viewerIsOwner = true
        ..listings[_id] = _listing(status: 'ARCHIVED');
      await _pump(tester, wire, initial: '/marketplace/seller/listings/polo-crema/edit');
      expect(find.text('Estado: Desactivada'), findsOneWidget);
      expect(find.byKey(const Key('listing-save')), findsNothing);
      expect(find.byKey(const Key('listing-submit')), findsNothing);
      expect(find.byKey(const Key('listing-archive')), findsNothing);
    });

    testWidgets('edit load failure shows retry instead of an empty form', (tester) async {
      final wire = _Wire();
      await _pump(tester, wire, initial: '/marketplace/seller/listings/missing/edit');
      expect(find.text('No pudimos cargar tu publicaci\u00f3n'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('deactivate confirms, archives, and buyers no longer find it', (tester) async {
      final wire = _Wire()
        ..viewerIsOwner = true
        ..listings[_id] = _listing();
      final router = await _pump(tester, wire, initial: '/marketplace/seller/stores/s1');
      expect(find.text('Publicada'), findsOneWidget);
      await tester.tap(find.text('Polo Crema'));
      await tester.pumpAndSettle();

      await _tapKey(tester, 'listing-archive');
      expect(find.text('\u00bfDesactivar publicaci\u00f3n?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(wire.writes, isEmpty);

      await _tapKey(tester, 'listing-archive');
      await tester.tap(find.byKey(const Key('listing-archive-confirm')));
      await tester.pumpAndSettle();
      expect(wire.writes, ['POST $_me/listings/$_id/archive']);
      expect(find.byType(SellerStorePage), findsOneWidget);
      expect(find.textContaining('Publicaci\u00f3n desactivada'), findsOneWidget);
      expect(find.text('Desactivada'), findsOneWidget);

      wire.viewerIsOwner = false;
      router.go('/marketplace');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('marketplace-discovery-empty')), findsOneWidget);
      expect(find.text('Polo Crema'), findsNothing);

      router.go('/marketplace/listings/polo-crema');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('listing-unavailable')), findsOneWidget);
    });
  });

  group('DH03 360px', () {
    testWidgets('marketplace screens fit 360px at 1.3 text scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const narrow = Size(360, 740);

      final wire = _Wire()
        ..viewerIsOwner = true
        ..listings[_id] = _listing(title: 'Polo Crema edici\u00f3n hist\u00f3rica 2026 talla M')
        ..listings['l2'] = _listing(id: 'l2', slug: 'gorro', title: 'Gorro', status: 'PENDING_REVIEW');
      await _pump(tester, wire, initial: '/marketplace', size: narrow);
      expect(tester.takeException(), isNull);
      await _pump(tester, wire, initial: '/marketplace/listings/gorro', size: narrow);
      expect(find.byKey(const Key('listing-not-public-note')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _pump(tester, wire, initial: '/marketplace/seller/stores/s1', size: narrow);
      expect(tester.takeException(), isNull);
      await _pump(tester, wire, initial: '/marketplace/seller/listings/polo-crema/edit', size: narrow);
      await _scrollTo(tester, find.byKey(const Key('listing-archive')));
      expect(tester.takeException(), isNull);
      await _pump(tester, wire, initial: '/marketplace/seller/stores/s1/listings/new', size: narrow);
      await _scrollTo(tester, find.byKey(const Key('listing-review-note')));
      expect(tester.takeException(), isNull);
    });
  });
}
