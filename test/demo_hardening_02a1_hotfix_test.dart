import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/router/app_router.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/community_feed_item.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/discovery_models.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_tribuna_offer_card.dart';
import 'package:garra_digital_app/features/home/presentation/home_page.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_engagement_service.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_offer_models.dart';
import 'package:garra_digital_app/features/locations/data/crema_point_model.dart';
import 'package:garra_digital_app/features/locations/data/location_service.dart';
import 'package:garra_digital_app/features/locations/presentation/negocios_cremas_page.dart';
import 'package:go_router/go_router.dart';

import 'home_screen_test.dart' show sampleHome;

CremaBusinessOffer _offer({
  String id = 'offer-1',
  String pointId = 'point-1',
  String pointName = 'restobar jvc',
  String title = '2x1 en chilcanos',
  String description = 'Promo para la hinchada crema',
}) =>
    CremaBusinessOffer(
      id: id,
      cremaPointId: pointId,
      cremaPointName: pointName,
      title: title,
      description: description,
      status: CremaBusinessOfferStatus.active,
      startsAt: DateTime.utc(2026, 10, 1, 18),
      endsAt: DateTime.utc(2026, 10, 31, 23, 59),
    );

CremaPointModel _point({String id = 'point-1', String? description}) =>
    CremaPointModel(
      id: id,
      name: 'restobar jvc',
      description: description ?? 'Previas cremas',
      type: 'BUSINESS',
      address: 'San Miguel',
      latitude: -12.08,
      longitude: -77.09,
      verified: true,
      sponsor: false,
      status: 'ACTIVE',
      createdAt: '2026-10-01T00:00:00Z',
      updatedAt: '2026-10-01T00:00:00Z',
    );

class _Loc extends LocationService {
  _Loc(this.points) : super(dio: Dio());
  final List<CremaPointModel> points;
  @override
  Future<List<CremaPointModel>> getActivePoints() async => points;
}

class _Eng extends CremaBusinessEngagementService {
  _Eng(this.offers) : super(dio: Dio());
  final List<CremaBusinessOffer> offers;
  final requested = <String>[];
  @override
  Future<List<CremaBusinessOffer>> listPointOffers(String pointId) async {
    requested.add(pointId);
    return [for (final o in offers) if (o.cremaPointId == pointId) o];
  }
}

class _Fan extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

Map<String, dynamic> _postJson(int i) => {
      'id': 'post-$i',
      'username': 'hincha$i',
      'fullName': 'Hincha $i',
      'content': 'Publicacion $i',
      'locationTag': 'GLOBAL',
      'status': 'ACTIVE',
      'reportCount': 0,
      'createdAt': '2026-10-06T10:00:00Z',
      'contextType': 'GLOBAL',
      'reactionSummary': <String, dynamic>{},
      'media': <dynamic>[],
    };

Map<String, dynamic> _offerJson(String id) => {
      'id': id,
      'cremaPointId': 'point-1',
      'cremaPointName': 'restobar jvc',
      'title': 'Oferta $id',
      'description': '2x1',
      'startsAt': null,
      'endsAt': '2026-10-30T23:00:00Z',
      'status': 'ACTIVE',
      'imageUrl': null,
      'publishedAt': '2026-10-05T10:00:00Z',
      'createdAt': '2026-10-05T10:00:00Z',
      'following': false,
    };

/// Real backend CommunityFeedItemResponse page (1 BUSINESS_OFFER per 5 posts).
class _FeedPageAdapter implements HttpClientAdapter {
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.path);
    Object body = {'success': true, 'data': <dynamic>[]};
    if (options.path.contains('/community/feed/page')) {
      final items = <Map<String, dynamic>>[];
      for (var i = 0; i < 10; i++) {
        items.add({'itemType': 'COMMUNITY_POST', 'post': _postJson(i), 'businessOffer': null});
        if ((i + 1) % 5 == 0) {
          items.add({'itemType': 'BUSINESS_OFFER', 'post': null, 'businessOffer': _offerJson('offer-$i')});
        }
      }
      // Malformed item from a newer/broken backend must be skipped.
      items.add({'itemType': 'BUSINESS_OFFER', 'post': null, 'businessOffer': null});
      body = {
        'success': true,
        'data': {
          'items': items,
          'page': {'size': 20, 'hasNext': false},
        },
      };
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingFeed extends CommunityService {
  _ThrowingFeed() : super(dio: Dio());
  @override
  Future<DiscoveryBundle> getDiscovery() async => const DiscoveryBundle();
  @override
  Future<FeedPage> getFeedPage({required String mode, String? cursor, int size = 20}) async =>
      throw DioException(requestOptions: RequestOptions(path: '/community/feed/page'));
}

class _HangingFeed extends CommunityService {
  _HangingFeed() : super(dio: Dio());
  @override
  Future<DiscoveryBundle> getDiscovery() async => const DiscoveryBundle();
  @override
  Future<FeedPage> getFeedPage({required String mode, String? cursor, int size = 20}) =>
      Completer<FeedPage>().future;
}

Widget _home(CommunityService service) => ProviderScope(
      overrides: [
        homeProvider.overrideWith((ref) async => sampleHome(matchdayState: 'MATCHDAY')),
        communityServiceProvider.overrideWithValue(service),
        currentFanProvider.overrideWith(_Fan.new),
      ],
      child: const MaterialApp(home: HomePage()),
    );

/// Feed surface + the public business page wired like app_router
/// (`/negocios/:id?oferta=<offerId>`), with stub services.
GoRouter _feedRouter(_Eng engagement) => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ListView(children: [GarraTribunaOfferCard(offer: _offer())]),
          ),
        ),
        GoRoute(
          path: '/negocios',
          builder: (_, _) => const Scaffold(body: Text('NEGOCIOS')),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => NegocioCremaDetailPage(
                idOrSlug: state.pathParameters['id'] ?? '',
                focusOfferId: state.uri.queryParameters['oferta'],
                locationService: _Loc([_point()]),
                engagement: engagement,
              ),
            ),
          ],
        ),
      ],
    );

void main() {
  group('BUG 1 - offer navigation ids', () {
    test('1. Ver oferta targets the real business page by cremaPointId + offerId', () {
      final offer = _offer(id: 'offer-9', pointId: 'point-7');
      expect(garraOfferDestination(offer), '/negocios/point-7?oferta=offer-9');
      expect(garraOfferBusinessDestination(offer), '/negocios/point-7');

      final router = createAppRouter(redirect: (_, _) => null);
      addTearDown(router.dispose);
      final match = router.configuration.findMatch(Uri.parse(garraOfferDestination(offer)));
      final route = match.last.route;
      expect(route.name, 'negocio-crema-detail');
      expect(match.pathParameters['id'], 'point-7');
      expect(match.uri.queryParameters['oferta'], 'offer-9');
    });

    test('2. Ver oferta never resolves a non-point id (root cause /negocios/ofertas)', () {
      final router = createAppRouter(redirect: (_, _) => null);
      addTearDown(router.dispose);
      // Root cause: the old literal was captured by /negocios/:id with id="ofertas".
      final legacy = router.configuration.findMatch(Uri.parse('/negocios/ofertas'));
      expect(legacy.pathParameters['id'], 'ofertas');

      final offer = _offer(id: 'offer-1', pointId: 'point-1');
      final target = Uri.parse(garraOfferDestination(offer));
      expect(target.pathSegments, ['negocios', 'point-1']);
      expect(target.pathSegments, isNot(contains('ofertas')));
      expect(target.pathSegments.last, offer.cremaPointId);
      expect(target.pathSegments.last, isNot(offer.id));
    });

    testWidgets('1b. Ver oferta lands on the business (never "No encontramos") focused on the offer',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final eng = _Eng([
        _offer(id: 'offer-0', title: 'Primera oferta'),
        _offer(),
      ]);
      final router = _feedRouter(eng);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.byKey(const ValueKey('tribuna_offer_cta_offer-1')));
      await tester.pumpAndSettle();
      expect(find.text('No encontramos este negocio'), findsNothing);
      expect(eng.requested, ['point-1']);
      final page = tester.widget<NegocioCremaDetailPage>(find.byType(NegocioCremaDetailPage));
      expect(page.idOrSlug, 'point-1');
      expect(page.focusOfferId, 'offer-1');
      final focused = find.byKey(const ValueKey('public_business_offer_offer-1'));
      expect(focused, findsOneWidget);
      final rect = tester.getRect(focused);
      expect(rect.top, lessThan(640));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
    });
  });

  group('BUG 2 - card context', () {
    testWidgets('3. feed context shows Ver oferta and Ver negocio', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GarraTribunaOfferCard(offer: _offer()))));
      expect(find.text('Ver oferta'), findsOneWidget);
      expect(find.text('Ver negocio'), findsOneWidget);
    });

    testWidgets('4. business context hides Ver negocio (and the self-loop Ver oferta)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GarraTribunaOfferCard(offer: _offer(), cardContext: GarraOfferCardContext.business),
        ),
      ));
      expect(find.text('Ver negocio'), findsNothing);
      expect(find.text('Ver oferta'), findsNothing);
      expect(find.text('2x1 en chilcanos'), findsOneWidget);
      expect(find.textContaining('Vigencia'), findsOneWidget);
    });

    testWidgets('4b. public business page renders offers in business context', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NegocioCremaDetailPage(
          idOrSlug: 'point-1',
          locationService: _Loc([_point()]),
          engagement: _Eng([_offer()]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('public_business_offers_header')), findsOneWidget);
      expect(find.text('Ver negocio'), findsNothing);
      expect(find.text('Ver oferta'), findsNothing);
    });

    testWidgets('5. back returns to the feed without loops or duplicated routes', (tester) async {
      final router = _feedRouter(_Eng([_offer()]));
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      for (final key in ['tribuna_offer_cta_offer-1', 'tribuna_offer_negocio_offer-1']) {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(find.byType(NegocioCremaDetailPage), findsOneWidget);
        // Business surface offers no CTA that could push itself again.
        expect(find.text('Ver negocio'), findsNothing);
        expect(find.text('Ver oferta'), findsNothing);
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.uri.path, '/');
        expect(router.canPop(), isFalse);
        expect(find.byType(NegocioCremaDetailPage), findsNothing);
        expect(find.byKey(const ValueKey('tribuna_offer_cta_offer-1')), findsOneWidget);
      }
    });

    testWidgets('9. offer card has no overflow at 360px (feed and business)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final long = _offer(
        pointName: 'Restobar JVC La Previa Crema del Estadio Monumental de Ate',
        title: 'Combo cremoso 2x1 en chilcanos y alitas para toda la hinchada',
        description: 'Valido presentando la app. ' * 12,
      );
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: ListView(children: [
              GarraTribunaOfferCard(offer: long),
              GarraTribunaOfferCard(offer: long, cardContext: GarraOfferCardContext.business),
            ]),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('BUG 3 - Home feed consumers', () {
    test('parser skips malformed/unknown wrapped items instead of faking posts', () {
      expect(parseCommunityFeedItem({'itemType': 'BUSINESS_OFFER', 'businessOffer': null}), isNull);
      expect(parseCommunityFeedItem({'itemType': 'BUSINESS_OFFER', 'businessOffer': {'id': 'o1'}}), isNull);
      expect(parseCommunityFeedItem({'itemType': 'FUTURE_KIND', 'post': null}), isNull);
      expect(parseCommunityFeedItem(_postJson(1)), isA<CommunityPostFeedItem>());
    });

    test('6. getFeedPage parses CommunityFeedItemResponse and tolerates a bad item', () async {
      final adapter = _FeedPageAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter;
      final page = await CommunityService(dio: dio).getFeedPage(mode: 'FOR_YOU');
      expect(page.posts.length, 10);
      expect(page.items.whereType<BusinessOfferFeedItem>().length, 2);
      expect(page.items[5], isA<BusinessOfferFeedItem>());
    });

    testWidgets('6b/7. Home FOR_YOU renders the new contract with BUSINESS_OFFER (no skeleton)',
        (tester) async {
      final adapter = _FeedPageAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter;
      await tester.pumpWidget(_home(CommunityService(dio: dio)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(adapter.requests, contains('/community/feed/page'));
      expect(find.byType(GarraSkeleton), findsNothing);
      expect(find.text('Hincha 0'), findsWidgets);
      final feedList = find.descendant(
        of: find.byType(SocialFeedTab),
        matching: find.byType(Scrollable),
      ).first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('tribuna_offer_offer-4')),
        400,
        scrollable: feedList,
      );
      expect(find.text('Oferta offer-4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8a. feed error ends in error + Reintentar, not skeleton', (tester) async {
      await tester.pumpWidget(_home(_ThrowingFeed()));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(GarraSkeleton), findsNothing);
      expect(find.text('No pudimos cargar el feed'), findsOneWidget);
      expect(find.text('Para ti'), findsOneWidget);
    });

    testWidgets('8b. a feed request that never settles stops the skeleton at the bound',
        (tester) async {
      await tester.pumpWidget(_home(_HangingFeed()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(GarraSkeleton), findsWidgets);
      await tester.pump(SocialFeedTab.loadTimeout + const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(GarraSkeleton), findsNothing);
      expect(find.text('No pudimos cargar el feed'), findsOneWidget);
      expect(find.text('Para ti'), findsOneWidget);
    });
  });
}