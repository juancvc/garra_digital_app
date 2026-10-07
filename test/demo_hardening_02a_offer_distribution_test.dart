import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/community/data/community_feed_item.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_tribuna_offer_card.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_engagement_service.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_offer_models.dart';
import 'package:garra_digital_app/features/locations/data/crema_point_model.dart';
import 'package:garra_digital_app/features/locations/data/location_service.dart';
import 'package:garra_digital_app/features/locations/presentation/create_business_offer_page.dart';
import 'package:garra_digital_app/features/locations/presentation/negocios_cremas_page.dart';
import 'package:go_router/go_router.dart';

CremaBusinessOffer _offer({
  required String id,
  String title = '2x1 sanguche',
  String? imageUrl,
  String pointName = 'Restobar Crema',
}) =>
    CremaBusinessOffer(
      id: id,
      cremaPointId: 'point-1',
      cremaPointName: pointName,
      title: title,
      description: 'Promo para la hinchada',
      status: CremaBusinessOfferStatus.active,
      imageUrl: imageUrl,
      startsAt: DateTime.utc(2026, 10, 1, 18),
      endsAt: DateTime.utc(2026, 10, 31, 23, 59),
      createdAt: DateTime.utc(2026, 10, 1),
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
  @override
  Future<List<CremaBusinessOffer>> listPointOffers(String pointId) async =>
      List.of(offers);
}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  test('parseCommunityFeedItem supports BUSINESS_OFFER and COMMUNITY_POST', () {
    final offerItem = parseCommunityFeedItem({
      'itemType': 'BUSINESS_OFFER',
      'businessOffer': {
        'id': 'o1',
        'cremaPointId': 'p1',
        'cremaPointName': 'Restobar',
        'title': 'Promo',
        'description': '2x1',
        'status': 'ACTIVE',
      },
    });
    expect(offerItem, isA<BusinessOfferFeedItem>());
    expect((offerItem as BusinessOfferFeedItem).offer.title, 'Promo');

    final postItem = parseCommunityFeedItem({
      'itemType': 'COMMUNITY_POST',
      'post': {
        'id': 'post-1',
        'username': 'u',
        'fullName': 'Fan',
        'content': 'hola',
        'createdAt': '2026-10-01T00:00:00Z',
      },
    });
    expect(postItem, isA<CommunityPostFeedItem>());
    expect((postItem as CommunityPostFeedItem).post.id, 'post-1');
  });

  testWidgets('Tribuna offer card shows OFERTA label negocio title benefit vigencia CTAs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: GarraTribunaOfferCard(offer: _offer(id: 'o1')),
          ),
        ),
        GoRoute(
          path: '/negocios/:id',
          builder: (_, __) => const SizedBox(),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    );
    expect(find.textContaining('OFERTA'), findsOneWidget);
    expect(find.textContaining('Restobar Crema'), findsWidgets);
    expect(find.text('2x1 sanguche'), findsOneWidget);
    expect(find.textContaining('Promo para la hinchada'), findsOneWidget);
    expect(find.textContaining('Vigencia'), findsOneWidget);
    expect(find.text('Ver oferta'), findsOneWidget);
    expect(find.text('Ver negocio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public business shows offers section when active offers exist',
      (tester) async {
    final point = CremaPointModel(
      id: 'point-1',
      name: 'Restobar Crema',
      description: 'Previas',
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
    await tester.pumpWidget(
      _app(
        NegocioCremaDetailPage(
          idOrSlug: 'point-1',
          locationService: _Loc([point]),
          engagement: _Eng([_offer(id: 'o1')]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('public_business_offers_header')), findsOneWidget);
    expect(find.text('2x1 sanguche'), findsOneWidget);
  });

  testWidgets('public business hides offers section when none', (tester) async {
    final point = CremaPointModel(
      id: 'point-1',
      name: 'Restobar Crema',
      description: 'Previas',
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
    await tester.pumpWidget(
      _app(
        NegocioCremaDetailPage(
          key: const ValueKey('detail_no_offers'),
          idOrSlug: 'point-1',
          locationService: _Loc([point]),
          engagement: _Eng(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('public_business_offers_header')), findsNothing);
  });

  testWidgets('create offer media copy matches abort-on-upload-failure behavior',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const CreateBusinessOfferPage(
          pointId: 'point-1',
          businessName: 'Restobar Crema',
        ),
      ),
    );
    expect(
      find.textContaining('debe terminar de cargar antes de guardar'),
      findsOneWidget,
    );
    expect(find.textContaining('se guarda sin imagen'), findsNothing);
  });

  testWidgets('date and time pickers expose Spanish help text and digital time mode',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const CreateBusinessOfferPage(
          pointId: 'point-1',
          businessName: 'Restobar Crema',
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('offer_starts_at')));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionar fecha'), findsOneWidget);
    expect(find.text('Cancelar'), findsWidgets);
    expect(find.text('Aceptar'), findsOneWidget);
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionar hora'), findsOneWidget);
    // Input mode avoids the huge analog clock.
    expect(find.byType(EditableText), findsWidgets);
  });
}