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
import 'package:garra_digital_app/features/marketplace/presentation/seller_store_page.dart';

/// MARKETPLACE_V2_A0: every seller call is observed on the wire (method +
/// path + body) through a Dio interceptor and compared with the backend
/// MarketplaceSellerController contract (base URL .../api/v1).

const _listingId = '3f2b8c1e-0000-4000-8000-00000000abcd';

class _Call {
  _Call(this.method, this.path, this.data);

  final String method;
  final String path;
  final dynamic data;

  @override
  String toString() => '$method $path';
}

typedef _Responder =
    dynamic Function(RequestOptions options); // null = 200 {data: {}}

class _Wire {
  _Wire({this.responder, Set<String> notFound = const {}})
    : _notFound = notFound {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add(_Call(options.method, options.path, options.data));
          final key = '${options.method} ${options.path}';
          if (_notFound.contains(key)) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                  data: {'success': false, 'message': 'Not found'},
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          final data = responder?.call(options) ?? <String, dynamic>{};
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': data},
            ),
          );
        },
      ),
    );
  }

  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
  final _Responder? responder;
  final Set<String> _notFound;
  final List<_Call> calls = [];

  List<String> get lines => [for (final c in calls) c.toString()];

  _Call last(String method, String path) =>
      calls.lastWhere((c) => c.method == method && c.path == path);
}

Map<String, dynamic> _sellerListingJson({
  String id = _listingId,
  String slug = 'camiseta-retro',
  String status = 'DRAFT',
}) {
  return {
    'id': id,
    'slug': slug,
    'title': 'Camiseta retro',
    'description': 'Talla M',
    'type': 'PRODUCT',
    'status': status,
    'priceAmount': 80,
    'currencyCode': 'PEN',
    'priceOnRequest': false,
    'favoriteCount': 0,
    'contactCount': 0,
    'category': {'id': 'c1', 'slug': 'ropa-accesorios', 'name': 'Ropa'},
    'images': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _storeJson({String status = 'DRAFT'}) => {
  'id': 'store-1',
  'slug': 'tienda-sur',
  'name': 'Tienda Sur',
  'status': status,
};

const _request = SellerListingRequest(
  title: 'Camiseta retro',
  description: 'Talla M',
  categorySlug: 'ropa-accesorios',
  price: 80,
);

void main() {
  group('A0 store contract', () {
    test(
      'onboarding without a store creates it at POST /seller/me/store',
      () async {
        final wire = _Wire(
          notFound: {
            'GET /marketplace/seller/me',
            'GET /marketplace/seller/me/store',
          },
          responder: (o) => o.path.endsWith('/submit')
              ? {'status': 'PENDING_REVIEW'}
              : {'status': 'DRAFT'},
        );
        final profile = await MarketplaceService(dio: wire.dio).submitSeller(
          const SellerOnboardingRequest(
            whatsapp: '51999999999',
            storeName: 'Tienda Sur',
            city: 'Lima',
            ipAcknowledged: true,
          ),
        );

        expect(profile.isPending, isTrue);
        expect(wire.lines, [
          'GET /marketplace/seller/me',
          'POST /marketplace/seller/me',
          'GET /marketplace/seller/me/store',
          'POST /marketplace/seller/me/store',
          'POST /marketplace/seller/me/submit',
        ]);
        final body =
            wire.last('POST', '/marketplace/seller/me/store').data as Map;
        expect(body['slug'], 'tienda-sur');
        expect(body['name'], 'Tienda Sur');
        expect(body['countryCode'], 'PE');
        expect(wire.lines, isNot(contains('POST /marketplace/seller/store')));
      },
    );

    test('re-onboarding a REJECTED seller with a store PATCHes it', () async {
      final wire = _Wire(
        responder: (o) {
          if (o.path == '/marketplace/seller/me' && o.method == 'GET') {
            return {'status': 'REJECTED'};
          }
          if (o.path == '/marketplace/seller/me/store') return _storeJson();
          if (o.path.endsWith('/submit')) return {'status': 'PENDING_REVIEW'};
          return {'status': 'REJECTED'};
        },
      );
      await MarketplaceService(dio: wire.dio).submitSeller(
        const SellerOnboardingRequest(
          whatsapp: '51999999999',
          storeName: 'Tienda Sur',
          ipAcknowledged: true,
        ),
      );

      expect(wire.lines, [
        'GET /marketplace/seller/me',
        'PATCH /marketplace/seller/me',
        'GET /marketplace/seller/me/store',
        'PATCH /marketplace/seller/me/store',
        'POST /marketplace/seller/me/submit',
      ]);
    });

    test(
      'an ACTIVE seller is approved and onboarding writes nothing',
      () async {
        final wire = _Wire(
          responder: (o) => {'status': 'ACTIVE', 'businessWhatsApp': '+51999'},
        );
        final service = MarketplaceService(dio: wire.dio);
        final me = await service.getSellerMe();
        expect(me!.isApproved, isTrue);
        expect(me.whatsapp, '+51999');

        await expectLater(
          service.submitSeller(
            const SellerOnboardingRequest(
              whatsapp: '51999999999',
              storeName: 'Tienda Sur',
              ipAcknowledged: true,
            ),
          ),
          throwsA(isA<MarketplaceServiceException>()),
        );
        expect(wire.calls.where((c) => c.method != 'GET'), isEmpty);
      },
    );

    test('get my store: GET /seller/me/store', () async {
      final wire = _Wire(responder: (_) => _storeJson(status: 'ACTIVE'));
      final store = await MarketplaceService(dio: wire.dio).getSellerStore();
      expect(wire.lines, ['GET /marketplace/seller/me/store']);
      expect(store.slug, 'tienda-sur');
      expect(store.status, 'ACTIVE');
    });

    test('update store: PATCH /seller/me/store', () async {
      final wire = _Wire(responder: (_) => _storeJson());
      await MarketplaceService(
        dio: wire.dio,
      ).updateSellerStore({'name': 'Tienda Sur 2'});
      expect(wire.lines, ['PATCH /marketplace/seller/me/store']);
      expect((wire.calls.single.data as Map)['name'], 'Tienda Sur 2');
    });

    test(
      'submit store: POST /seller/me/store/submit with ipAcknowledged',
      () async {
        final wire = _Wire(
          responder: (_) => _storeJson(status: 'PENDING_REVIEW'),
        );
        final store = await MarketplaceService(
          dio: wire.dio,
        ).submitSellerStore();
        expect(wire.lines, ['POST /marketplace/seller/me/store/submit']);
        expect(wire.calls.single.data, {'ipAcknowledged': true});
        expect(store.status, 'PENDING_REVIEW');
      },
    );

    test('store media stays PUT /seller/me/store/media', () async {
      final wire = _Wire();
      await MarketplaceMediaService(
        dio: wire.dio,
      ).updateStoreMedia(logoMediaAssetId: 'asset-1');
      expect(wire.lines, ['PUT /marketplace/seller/me/store/media']);
    });
  });

  group('A0 seller summary', () {
    test(
      'GET /seller/me/summary parses the real SellerSummaryResponse',
      () async {
        final wire = _Wire(
          responder: (_) => {
            'sellerId': 's1',
            'sellerStatus': 'ACTIVE',
            'storeId': 'store-1',
            'storeSlug': 'tienda-sur',
            'storeStatus': 'DRAFT',
            'activeListings': 3,
            'pendingReviewListings': 1,
            'favoritesReceived': 7,
            'contactLeads': 4,
          },
        );
        final summary = await MarketplaceService(
          dio: wire.dio,
        ).getSellerSummary();

        expect(wire.lines, ['GET /marketplace/seller/me/summary']);
        expect(summary.status, 'ACTIVE');
        expect(summary.listingsCount, 3);
        expect(summary.favoritesCount, 7);
        expect(summary.contactsCount, 4);
        expect(summary.storeSlug, 'tienda-sur');
        expect(summary.storeStatus, 'DRAFT');
        expect(summary.canSubmitStore, isTrue);
      },
    );

    test(
      'store submit is only offered for an ACTIVE seller with a DRAFT store',
      () {
        SellerSummary s(String seller, String? store) => SellerSummary.fromJson(
          {'sellerStatus': seller, 'storeStatus': store},
        );
        expect(s('ACTIVE', 'DRAFT').canSubmitStore, isTrue);
        expect(s('PENDING_REVIEW', 'DRAFT').canSubmitStore, isFalse);
        expect(s('ACTIVE', 'PENDING_REVIEW').canSubmitStore, isFalse);
        expect(s('ACTIVE', 'ACTIVE').canSubmitStore, isFalse);
        expect(s('ACTIVE', null).canSubmitStore, isFalse);
      },
    );
  });

  group('A0 listings contract', () {
    test(
      'my listings: GET /seller/me/listings (plain list with ids)',
      () async {
        final wire = _Wire(
          responder: (_) => [
            _sellerListingJson(),
            _sellerListingJson(id: 'l2', slug: 'gorro', status: 'ACTIVE'),
          ],
        );
        final listings = await MarketplaceService(
          dio: wire.dio,
        ).getSellerListings();

        expect(wire.lines, ['GET /marketplace/seller/me/listings']);
        expect(listings.map((l) => l.id), [_listingId, 'l2']);
        expect(listings.first.price, 80);
        expect(listings.first.categorySlug, 'ropa-accesorios');
      },
    );

    test(
      'create: POST /seller/me/listings with slug and priceAmount',
      () async {
        final wire = _Wire(responder: (_) => _sellerListingJson());
        final listing = await MarketplaceService(
          dio: wire.dio,
        ).createSellerListing(_request);

        expect(wire.lines, ['POST /marketplace/seller/me/listings']);
        final body = wire.calls.single.data as Map;
        expect(body['title'], 'Camiseta retro');
        expect(body['categorySlug'], 'ropa-accesorios');
        expect(body['type'], 'PRODUCT');
        expect(body['priceAmount'], 80);
        expect(body.containsKey('price'), isFalse);
        expect(body['slug'], matches(RegExp(r'^camiseta-retro-[a-z0-9]+$')));
        expect(listing.id, _listingId);
      },
    );

    test(
      'update: PATCH /seller/me/listings/{listingId}, never the slug',
      () async {
        final wire = _Wire(responder: (_) => _sellerListingJson());
        await MarketplaceService(
          dio: wire.dio,
        ).updateSellerListing(_listingId, _request);

        expect(wire.lines, [
          'PATCH /marketplace/seller/me/listings/$_listingId',
        ]);
        final body = wire.calls.single.data as Map;
        expect(body['priceAmount'], 80);
        expect(body.containsKey('slug'), isFalse);
      },
    );

    test(
      'submit: POST /seller/me/listings/{listingId}/submit + IP ack',
      () async {
        final wire = _Wire(
          responder: (_) => _sellerListingJson(status: 'PENDING_REVIEW'),
        );
        final listing = await MarketplaceService(
          dio: wire.dio,
        ).submitSellerListing(_listingId);

        expect(wire.lines, [
          'POST /marketplace/seller/me/listings/$_listingId/submit',
        ]);
        expect(wire.calls.single.data, {'ipAcknowledged': true});
        expect(listing.isPending, isTrue);
      },
    );

    test(
      'archive: POST /seller/me/listings/{listingId}/archive, no DELETE',
      () async {
        final wire = _Wire(
          responder: (_) => _sellerListingJson(status: 'ARCHIVED'),
        );
        final listing = await MarketplaceService(
          dio: wire.dio,
        ).archiveSellerListing(_listingId);

        expect(wire.lines, [
          'POST /marketplace/seller/me/listings/$_listingId/archive',
        ]);
        expect(wire.calls.where((c) => c.method == 'DELETE'), isEmpty);
        expect(listing.status, 'ARCHIVED');
      },
    );

    test(
      'images keep the real endpoints (POST / PUT order / DELETE)',
      () async {
        final wire = _Wire();
        final media = MarketplaceMediaService(dio: wire.dio);
        await media.attachListingImage(
          listingId: _listingId,
          mediaAssetId: 'asset-1',
          sortOrder: 0,
        );
        await media.reorderListingImages(
          listingId: _listingId,
          imageIds: ['i2', 'i1'],
        );
        await media.removeListingImage(listingId: _listingId, imageId: 'i1');

        expect(wire.lines, [
          'POST /marketplace/seller/me/listings/$_listingId/images',
          'PUT /marketplace/seller/me/listings/$_listingId/images/order',
          'DELETE /marketplace/seller/me/listings/$_listingId/images/i1',
        ]);
        expect((wire.calls.first.data as Map)['mediaAssetId'], 'asset-1');
        expect((wire.calls[1].data as Map)['imageIds'], ['i2', 'i1']);
      },
    );

    test('listing slugs match the backend pattern', () {
      final now = DateTime.utc(2026, 9, 28, 12);
      final suffix = now.millisecondsSinceEpoch.toRadixString(36);
      final pattern = RegExp(r'^[a-z0-9-]{3,80}$');

      expect(
        marketplaceListingSlug(
          'Camiseta Cr\u00e9ma \u00d1and\u00fa!',
          now: now,
        ),
        'camiseta-crema-\u00f1andu-$suffix'.replaceAll('\u00f1', 'n'),
      );
      expect(
        marketplaceListingSlug('  ***  ', now: now),
        'publicacion-$suffix',
      );
      final long = marketplaceListingSlug('a' * 120, now: now);
      expect(long.length, lessThanOrEqualTo(80));
      for (final slug in [
        long,
        marketplaceListingSlug('Gorro', now: now),
        marketplaceListingSlug('\u00c1', now: now),
      ]) {
        expect(pattern.hasMatch(slug), isTrue, reason: slug);
      }
    });
  });

  group('A0 screens use the real contract', () {
    testWidgets('editing a listing PATCHes and submits by id', (tester) async {
      final wire = _Wire(
        responder: (o) {
          if (o.path == '/marketplace/categories') {
            return [
              {'id': 'c1', 'slug': 'ropa-accesorios', 'name': 'Ropa'},
            ];
          }
          if (o.path == '/marketplace/listings/camiseta-retro') {
            return _sellerListingJson();
          }
          if (o.path.endsWith('/submit')) {
            return _sellerListingJson(status: 'PENDING_REVIEW');
          }
          return _sellerListingJson();
        },
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
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SellerListingFormPage(slug: 'camiseta-retro'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submit = find.text('Enviar a revisi\u00f3n');
      await tester.scrollUntilVisible(
        submit,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // DEMO_HARDENING_03: more actions follow the submit CTA now.
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(
        wire.lines,
        containsAllInOrder([
          'PATCH /marketplace/seller/me/listings/$_listingId',
          'POST /marketplace/seller/me/listings/$_listingId/submit',
        ]),
      );
      expect(wire.lines.where((l) => l.contains('camiseta-retro/')), isEmpty);
      expect(wire.lines.where((l) => l.startsWith('PUT ')), isEmpty);
    });

    Future<_Wire> pumpDashboard(
      WidgetTester tester,
      String storeStatus, {
      Widget home = const SellerDashboardPage(),
    }) async {
      final wire = _Wire(
        responder: (o) {
          switch (o.path) {
            case '/marketplace/seller/me/summary':
              return {
                'sellerStatus': 'ACTIVE',
                'storeStatus': storeStatus,
                'storeSlug': 'tienda-sur',
                'activeListings': 1,
                'favoritesReceived': 2,
                'contactLeads': 3,
              };
            case '/marketplace/seller/me/stores':
              return [_storeJson(status: storeStatus)];
            case '/marketplace/seller/me/stores/store-1':
              return _storeJson(status: storeStatus);
            case '/marketplace/seller/me/stores/store-1/listings':
              return [_sellerListingJson()];
            case '/marketplace/seller/me/plan':
              return <String, dynamic>{};
            case '/marketplace/seller/me/stores/store-1/submit':
              return _storeJson(status: 'PENDING_REVIEW');
          }
          return <String, dynamic>{};
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketplaceServiceProvider.overrideWithValue(
              MarketplaceService(dio: wire.dio),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: home,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return wire;
    }

    // MARKETPLACE_V2_A1: the dashboard lists businesses (GET /me/stores) and
    // listings live inside each business; no legacy singular store calls.
    testWidgets('dashboard loads summary + businesses from /seller/me', (
      tester,
    ) async {
      final wire = await pumpDashboard(tester, 'ACTIVE');

      expect(wire.lines, contains('GET /marketplace/seller/me/summary'));
      expect(wire.lines, contains('GET /marketplace/seller/me/stores'));
      expect(wire.lines, contains('GET /marketplace/seller/me/plan'));
      expect(wire.lines, isNot(contains('GET /marketplace/seller/me/listings')));
      expect(wire.lines.where((l) => l.contains('/me/store/')), isEmpty);
      expect(find.text('Estado: Aprobado'), findsOneWidget);
      expect(find.byKey(const Key('seller-store-card-store-1')), findsOneWidget);
      expect(find.byKey(const Key('seller-store-submit')), findsNothing);
    });

    testWidgets('a DRAFT store of an ACTIVE seller is submitted by id', (
      tester,
    ) async {
      final wire = await pumpDashboard(
        tester,
        'DRAFT',
        home: const SellerStorePage(storeId: 'store-1'),
      );

      final button = find.byKey(const Key('seller-store-submit'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();

      final submit = wire.last(
        'POST',
        '/marketplace/seller/me/stores/store-1/submit',
      );
      expect(submit.data, {'ipAcknowledged': true});
      expect(find.text('Negocio enviado a revisi\u00f3n.'), findsOneWidget);
      expect(wire.lines, isNot(contains('POST /marketplace/seller/me/store/submit')));
      expect(
        wire.lines.where((l) => l == 'GET /marketplace/seller/me/summary'),
        hasLength(2),
      );
    });
  });
}
