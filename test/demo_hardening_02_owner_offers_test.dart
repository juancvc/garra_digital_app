import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_application_service.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_engagement_service.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_offer_models.dart';
import 'package:garra_digital_app/features/locations/presentation/business_offers_page.dart';
import 'package:garra_digital_app/features/locations/presentation/create_business_offer_page.dart';
import 'package:garra_digital_app/features/locations/presentation/mi_negocio_activo_page.dart';
import 'package:garra_digital_app/features/locations/presentation/mi_negocio_crema_page.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

const _pointId = 'point-offers-1';

CremaBusinessApplication _app({
  required String id,
  required String name,
  required CremaBusinessApplicationStatus status,
  String? pointId,
  bool? active,
}) =>
    CremaBusinessApplication(
      id: id,
      businessName: name,
      category: 'Comida',
      address: 'San Miguel',
      latitude: -12.08,
      longitude: -77.09,
      status: status,
      description: 'Previas crema',
      phone: '999111222',
      cremaPointId: pointId,
      pointActive: active,
    );

final _verified = _app(
  id: 'app-verified',
  name: 'Restobar Crema',
  status: CremaBusinessApplicationStatus.verified,
  pointId: _pointId,
  active: true,
);

CremaBusinessOffer _offer({
  required String id,
  required CremaBusinessOfferStatus status,
  String title = '2x1 sanguche',
  String? imageUrl,
  DateTime? startsAt,
  DateTime? endsAt,
}) =>
    CremaBusinessOffer(
      id: id,
      cremaPointId: _pointId,
      cremaPointName: 'Restobar Crema',
      title: title,
      description: 'Promo para la hinchada',
      status: status,
      imageUrl: imageUrl,
      startsAt: startsAt,
      endsAt: endsAt,
      createdAt: DateTime.utc(2026, 10, 1),
    );

class _Apps extends CremaBusinessApplicationService {
  _Apps(this.items) : super(dio: Dio());
  final List<CremaBusinessApplication> items;

  @override
  Future<List<CremaBusinessApplication>> listMine() async => items;
}

class _Engagement extends CremaBusinessEngagementService {
  _Engagement({
    List<CremaBusinessOffer>? owned,
    List<CremaBusinessOffer>? publicOffers,
  })  : owned = List.of(owned ?? const []),
        publicOffers = List.of(publicOffers ?? const []),
        super(dio: Dio());

  List<CremaBusinessOffer> owned;
  List<CremaBusinessOffer> publicOffers;
  int createCalls = 0;
  int publishCalls = 0;
  int cancelCalls = 0;

  @override
  Future<List<CremaBusinessOffer>> listOwnedOffers(String pointId) async =>
      List.of(owned);

  @override
  Future<List<CremaBusinessOffer>> listOffers({
    double? lat,
    double? lng,
    double? radiusKm,
  }) async =>
      List.of(publicOffers);

  @override
  Future<CremaBusinessOffer> createOffer({
    required String pointId,
    required String title,
    required String description,
    DateTime? startsAt,
    DateTime? endsAt,
    String? mediaAssetId,
  }) async {
    createCalls++;
    if (startsAt != null && endsAt != null && endsAt.isBefore(startsAt)) {
      throw DioException(requestOptions: RequestOptions(path: '/offers'));
    }
    final offer = _offer(
      id: 'offer-$createCalls',
      status: CremaBusinessOfferStatus.draft,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
      imageUrl: mediaAssetId == null ? null : 'https://cdn.test/o.jpg',
    );
    owned = [offer, ...owned];
    return offer;
  }

  @override
  Future<CremaBusinessOffer> publishOffer(String offerId) async {
    publishCalls++;
    final current = owned.firstWhere((o) => o.id == offerId);
    final published = _offer(
      id: offerId,
      status: CremaBusinessOfferStatus.active,
      title: current.title,
      imageUrl: current.imageUrl,
      startsAt: current.startsAt,
      endsAt: current.endsAt,
    );
    owned = owned.map((o) => o.id == offerId ? published : o).toList();
    publicOffers = [
      published,
      ...publicOffers.where((o) => o.id != offerId),
    ];
    return published;
  }

  @override
  Future<CremaBusinessOffer> cancelOffer(String offerId) async {
    cancelCalls++;
    final current = owned.firstWhere((o) => o.id == offerId);
    final cancelled = _offer(
      id: offerId,
      status: CremaBusinessOfferStatus.cancelled,
      title: current.title,
    );
    owned = owned.map((o) => o.id == offerId ? cancelled : o).toList();
    publicOffers = publicOffers.where((o) => o.id != offerId).toList();
    return cancelled;
  }

  @override
  Future<CremaBusinessOffer> updateDraftOffer({
    required String offerId,
    required String title,
    required String description,
    DateTime? startsAt,
    DateTime? endsAt,
    String? mediaAssetId,
  }) async {
    final current = owned.firstWhere((o) => o.id == offerId);
    final updated = _offer(
      id: offerId,
      status: CremaBusinessOfferStatus.draft,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
      imageUrl: mediaAssetId == null ? current.imageUrl : 'https://cdn.test/o.jpg',
    );
    owned = owned.map((o) => o.id == offerId ? updated : o).toList();
    return updated;
  }
}

class _Media extends MediaUploadService {
  _Media({this.fail = false}) : super(dio: Dio());
  final bool fail;
  int uploads = 0;

  @override
  Future<XFile?> pickImage({double maxSide = 1920}) async => XFile('offer.jpg');

  @override
  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
    bool Function()? canStartRemote,
    CancelToken? cancelToken,
  }) async {
    uploads++;
    if (fail) {
      return MediaDraft(
        localId: 'l',
        state: MediaUploadState.failed,
        error: 'No pudimos subir la imagen',
      );
    }
    return MediaDraft(
      localId: 'l',
      assetId: 'asset-offer-1',
      state: MediaUploadState.ready,
    );
  }
}


Future<void> _tapSubmit(WidgetTester tester) async {
  final submit = find.text('Publicar oferta');
  await tester.scrollUntilVisible(submit, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pump();
}

void main() {
  test('offer model maps statuses and derived vigencia chip', () {
    final activePast = _offer(
      id: '1',
      status: CremaBusinessOfferStatus.active,
      endsAt: DateTime.utc(2020, 1, 1),
    );
    expect(activePast.statusChipLabel, 'Vigencia terminada');
    expect(CremaBusinessOfferStatus.fromApi('DRAFT').label, 'Borrador');
    expect(CremaBusinessOfferStatus.fromApi('CANCELLED').label, 'Cancelada');
  });

  testWidgets('eligible owner sees OFERTAS section and empty first-use CTA',
      (tester) async {
    final engagement = _Engagement(owned: const []);
    await tester.pumpWidget(
      MaterialApp(
        home: MiNegocioActivoPage(
          applicationId: _verified.id,
          initial: _verified,
          service: _Apps([_verified]),
          engagement: engagement,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('owner_offers_section')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('owner_offers_section')), findsOneWidget);
    expect(find.text('Aún no tienes ofertas'), findsOneWidget);
    expect(find.textContaining('¿Cómo funciona?'), findsOneWidget);
    expect(find.text('Crear mi primera oferta'), findsOneWidget);
  });

  testWidgets('empty CTA opens create form; validation blocks empty submit',
      (tester) async {
    final engagement = _Engagement();
    await tester.pumpWidget(
      MaterialApp(
        home: MiNegocioActivoPage(
          applicationId: _verified.id,
          initial: _verified,
          service: _Apps([_verified]),
          engagement: engagement,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('owner_offers_section')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear mi primera oferta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear mi primera oferta'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateBusinessOfferPage), findsOneWidget);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(engagement.createCalls, 0);
    expect(find.text('Completa este campo'), findsWidgets);
  });

  testWidgets('successful create+publish and no double submit', (tester) async {
    final engagement = _Engagement();
    await tester.pumpWidget(
      MaterialApp(
        home: CreateBusinessOfferPage(
          pointId: _pointId,
          businessName: 'Restobar Crema',
          engagement: engagement,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '2x1 sanguche');
    await tester.enterText(find.byType(TextFormField).at(1), 'Solo previa');
    await tester.pump();
    await _tapSubmit(tester);
    // Second tap while submitting: button is loading (no label) / disabled.
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(engagement.createCalls, 1);
    expect(engagement.publishCalls, 1);
  });

  testWidgets('media failure aborts create before saving offer',
      (tester) async {
    final engagement = _Engagement();
    final media = _Media(fail: true);
    await tester.pumpWidget(
      MaterialApp(
        home: CreateBusinessOfferPage(
          pointId: _pointId,
          businessName: 'Restobar Crema',
          engagement: engagement,
          media: media,
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Con foto');
    await tester.enterText(find.byType(TextFormField).at(1), 'Beneficio');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('single_photo_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('single_photo_add')));
    await tester.pumpAndSettle();
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(media.uploads, 1);
    expect(engagement.createCalls, 0);
    expect(find.textContaining('subir la imagen'), findsOneWidget);
  });

  testWidgets('owner list shows draft/active/cancelled; fan sees only ACTIVE',
      (tester) async {
    final draft = _offer(id: 'd1', status: CremaBusinessOfferStatus.draft);
    final active = _offer(id: 'a1', status: CremaBusinessOfferStatus.active);
    final cancelled =
        _offer(id: 'c1', status: CremaBusinessOfferStatus.cancelled);
    final engagement = _Engagement(
      owned: [draft, active, cancelled],
      publicOffers: [active],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MiNegocioActivoPage(
          applicationId: _verified.id,
          initial: _verified,
          service: _Apps([_verified]),
          engagement: engagement,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('owner_offers_section')));
    await tester.pumpAndSettle();
    expect(find.text('Borrador'), findsOneWidget);
    expect(find.text('Activa'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('Publicar'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: BusinessOffersPage(service: engagement)),
    );
    await tester.pumpAndSettle();
    expect(find.text('2x1 sanguche'), findsOneWidget);
    expect(find.text('Borrador'), findsNothing);
    expect(find.text('Cancelada'), findsNothing);
  });

  testWidgets('publish from owner card then cancel', (tester) async {
    final draft = _offer(id: 'd1', status: CremaBusinessOfferStatus.draft);
    final engagement = _Engagement(owned: [draft]);
    await tester.pumpWidget(
      MaterialApp(
        home: MiNegocioActivoPage(
          applicationId: _verified.id,
          initial: _verified,
          service: _Apps([_verified]),
          engagement: engagement,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('owner_offers_section')));
    await tester.pumpAndSettle();
    expect(find.text('Publicar'), findsOneWidget);
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(engagement.publishCalls, 1);
    expect(find.text('Activa'), findsOneWidget);
    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar oferta'));
    await tester.pumpAndSettle();
    expect(engagement.cancelCalls, 1);
    expect(find.text('Cancelada'), findsOneWidget);
  });

  testWidgets('Mis negocios without business shows register CTA', (tester) async {
    final apps = _Apps(const []);
    final router = GoRouter(
      initialLocation: '/negocios/mi-negocio',
      routes: [
        GoRoute(
          path: '/negocios/mi-negocio',
          builder: (_, __) => MiNegocioCremaPage(service: apps),
        ),
        GoRoute(
          path: '/negocios/mi-negocio/nuevo',
          builder: (_, __) => const Scaffold(body: Text('flujo registro')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('¿Tienes un negocio?'), findsOneWidget);
    expect(find.text('Registrar mi negocio'), findsOneWidget);
    await tester.tap(find.text('Registrar mi negocio'));
    await tester.pumpAndSettle();
    expect(find.text('flujo registro'), findsOneWidget);
  });

  testWidgets('owner offers section no overflow at 360 width', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final engagement = _Engagement(owned: [
      _offer(id: 'a1', status: CremaBusinessOfferStatus.active),
      _offer(
        id: 'd1',
        status: CremaBusinessOfferStatus.draft,
        title: 'Nombre muy largo de promoción crema para overflow check',
      ),
    ]);
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(360, 800)),
        child: SizedBox.shrink(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 800)),
          child: MiNegocioActivoPage(
            applicationId: _verified.id,
            initial: _verified,
            service: _Apps([_verified]),
            engagement: engagement,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
