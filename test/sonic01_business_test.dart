import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/widgets/garra_cached_network_image.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_application_service.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_engagement_service.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_offer_models.dart';
import 'package:garra_digital_app/features/locations/data/crema_point_model.dart';
import 'package:garra_digital_app/features/locations/data/location_service.dart';
import 'package:garra_digital_app/features/locations/presentation/mi_negocio_activo_page.dart';
import 'package:garra_digital_app/features/locations/presentation/mi_negocio_crema_page.dart';
import 'package:garra_digital_app/features/locations/presentation/negocios_cremas_page.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

const _pointId = 'point-111';

CremaBusinessApplication _app({
  required String id,
  required String name,
  required CremaBusinessApplicationStatus status,
  String? pointId,
  String? cover,
  bool? active,
  String? reason,
}) => CremaBusinessApplication(
  id: id,
  businessName: name,
  category: 'Comida',
  address: 'San Miguel',
  latitude: -12.08,
  longitude: -77.09,
  status: status,
  description: 'Anticuchos de la previa',
  phone: '999111222',
  instagram: 'https://www.instagram.com/crema',
  cremaPointId: pointId,
  coverImageUrl: cover,
  pointActive: active,
  rejectionReason: reason,
);

final _verified = _app(id: 'app-verified', name: 'Restobar Crema',
    status: CremaBusinessApplicationStatus.verified, pointId: _pointId, active: true);

class _Apps extends CremaBusinessApplicationService {
  _Apps(this.items, {this.fail = false}) : super(dio: Dio());
  List<CremaBusinessApplication> items;
  bool fail;
  int listCalls = 0;
  final List<String> coverCalls = [];

  @override
  Future<List<CremaBusinessApplication>> listMine() async {
    listCalls++;
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/x'));
    return items;
  }

  @override
  Future<CremaBusinessApplication> updateCover(String id, String mediaAssetId) async {
    coverCalls.add('PUT $id $mediaAssetId');
    final updated = _app(id: id, name: 'Restobar Crema',
        status: CremaBusinessApplicationStatus.verified, pointId: _pointId,
        active: true, cover: 'https://pub.r2.dev/business-offers/u/cover.jpg');
    items = [updated];
    return updated;
  }

  @override
  Future<CremaBusinessApplication> removeCover(String id) async {
    coverCalls.add('DELETE $id');
    return _verified;
  }
}

class _Media extends MediaUploadService {
  _Media() : super(dio: Dio());
  final List<MediaUploadPurpose> purposes = [];

  @override
  Future<XFile?> pickImage({double maxSide = 1920}) async => XFile('cover.jpg');

  @override
  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
    bool Function()? canStartRemote,
    CancelToken? cancelToken,
  }) async {
    purposes.add(purpose);
    return MediaDraft(localId: 'l', assetId: 'asset-1', state: MediaUploadState.ready);
  }
}

class _Points extends LocationService {
  _Points(this.point);
  final CremaPointModel point;
  @override
  Future<List<CremaPointModel>> getActivePoints() async => [point];
}

GoRouter _router(_Apps apps, {_Media? media, List<String>? visited}) => GoRouter(
  initialLocation: '/negocios/mi-negocio',
  routes: [
    GoRoute(path: '/negocios/mi-negocio',
        builder: (_, _) => MiNegocioCremaPage(service: apps)),
    GoRoute(path: '/negocios/mi-negocio/nuevo',
        builder: (_, _) => const Scaffold(body: Text('FORMULARIO'))),
    GoRoute(path: '/negocios/mi-negocio/activo/:id', builder: (_, state) =>
        MiNegocioActivoPage(applicationId: state.pathParameters['id']!,
            initial: state.extra as CremaBusinessApplication?,
            service: apps, media: media)),
    GoRoute(path: '/negocios/mapa', builder: (_, state) {
      visited?.add('mapa:${state.uri.queryParameters['pointId']}');
      return const Scaffold(body: Text('MAPA'));
    }),
    GoRoute(path: '/negocios/:id', builder: (_, state) {
      visited?.add('ficha:${state.pathParameters['id']}');
      return const Scaffold(body: Text('FICHA PÚBLICA'));
    }),
  ],
);

final _rawCodes = RegExp(r'\b(DRAFT|PENDING|VERIFIED|REJECTED|ACTIVE|INACTIVE|BUSINESS)\b');

void _expectNoRawCodesOrIds(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '').join('\n');
  expect(_rawCodes.hasMatch(texts), isFalse, reason: texts);
  expect(texts.contains(_pointId), isFalse);
  expect(texts.contains('app-verified'), isFalse);
}

class _NoOffers extends CremaBusinessEngagementService {
  _NoOffers() : super(dio: Dio());
  @override
  Future<List<CremaBusinessOffer>> listPointOffers(String pointId) async => [];
}

void main() {
  test('application JSON exposes cover, visibility and approved-business state', () {
    final parsed = CremaBusinessApplication.fromJson({
      'id': 'a1', 'businessName': 'Bar', 'category': 'Bar', 'address': 'Lima',
      'latitude': -12.0, 'longitude': -77.0, 'status': 'VERIFIED',
      'cremaPointId': _pointId, 'coverImageUrl': 'https://x.r2.dev/c.jpg',
      'pointActive': true,
    });
    expect(parsed.isApprovedBusiness, isTrue);
    expect(parsed.isPubliclyVisible, isTrue);
    expect(parsed.coverImageUrl, 'https://x.r2.dev/c.jpg');
    final legacy = CremaBusinessApplication.fromJson({
      'id': 'a2', 'businessName': 'Bar', 'category': 'Bar', 'address': 'Lima',
      'latitude': -12.0, 'longitude': -77.0, 'status': 'PENDING', 'coverImageUrl': ' ',
    });
    expect(legacy.isApprovedBusiness, isFalse);
    expect(legacy.coverImageUrl, isNull);
    expect(legacy.pointActive, isNull);
    final point = CremaPointModel.fromJson({'id': 'p', 'name': 'Sin foto'});
    expect(point.coverImageUrl, isNull);
    expect(MediaUploadPurpose.businessMedia.apiValue, 'BUSINESS_OFFER');
  });

  testWidgets('Mis negocios separates active businesses from requests with human states',
      (tester) async {
    final apps = _Apps([
      _app(id: 'p1', name: 'Café Pendiente', status: CremaBusinessApplicationStatus.pending),
      _verified,
      _app(id: 'r1', name: 'Bar Rechazado', status: CremaBusinessApplicationStatus.rejected,
          reason: 'Falta dirección precisa'),
      _app(id: 'd1', name: 'Borrador Crema', status: CremaBusinessApplicationStatus.draft),
    ]);
    final router = _router(apps);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Mis negocios'), findsOneWidget);
    expect(find.text('NEGOCIOS ACTIVOS'), findsOneWidget);
    expect(find.text('SOLICITUDES'), findsOneWidget);
    expect(find.text('Activo · Verificado por Garra'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Rechazada'), findsOneWidget);
    expect(find.text('Borrador'), findsOneWidget);
    expect(find.text('Motivo: Falta dirección precisa'), findsOneWidget);
    expect(find.text('Corregir y reenviar'), findsOneWidget);
    expect(find.text('Completar y enviar'), findsOneWidget);
    // The approved business is listed above the requests, not among them.
    expect(tester.getTopLeft(find.text('Restobar Crema')).dy,
        lessThan(tester.getTopLeft(find.text('SOLICITUDES')).dy));
    _expectNoRawCodesOrIds(tester);
  });

  testWidgets('approved business opens the owner page with public presence and map',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final apps = _Apps([_verified]);
    final visited = <String>[];
    final router = _router(apps, visited: visited);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restobar Crema'));
    await tester.pumpAndSettle();

    expect(find.byType(MiNegocioActivoPage), findsOneWidget);
    expect(find.text('Activo · Verificado por Garra'), findsOneWidget);
    expect(find.text('Anticuchos de la previa'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.byKey(const ValueKey('business_cover_fallback')), findsOneWidget);
    expect(find.text('Tu negocio aún no tiene foto'), findsOneWidget);
    _expectNoRawCodesOrIds(tester);

    await tester.tap(find.text('Ver ficha pública'));
    await tester.pumpAndSettle();
    expect(visited, ['ficha:$_pointId']);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver en el mapa'));
    await tester.pumpAndSettle();
    expect(visited.last, 'mapa:$_pointId');
  });

  testWidgets('owner uploads a cover through the media pipeline and the page shows it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final apps = _Apps([_verified]);
    final media = _Media();
    final router = _router(apps, media: media);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/negocios/mi-negocio/activo/app-verified');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('single_photo_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('business_cover_save')));
    await tester.pumpAndSettle();

    expect(media.purposes, [MediaUploadPurpose.businessMedia]);
    expect(apps.coverCalls, ['PUT app-verified asset-1']);
    expect(find.text('Foto del negocio actualizada'), findsOneWidget);
    expect(find.byKey(const ValueKey('business_cover_fallback')), findsNothing);
    expect(find.byType(GarraCachedNetworkImage), findsWidgets);
  });

  testWidgets('hidden point is shown honestly without public links', (tester) async {
    final hidden = _app(id: 'app-verified', name: 'Restobar Crema',
        status: CremaBusinessApplicationStatus.verified, pointId: _pointId, active: false);
    final apps = _Apps([hidden]);
    final router = _router(apps);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Verificado · no visible por ahora'), findsOneWidget);
    await tester.tap(find.text('Restobar Crema'));
    await tester.pumpAndSettle();
    expect(find.text('Ver ficha pública'), findsNothing);
    expect(find.textContaining('pausó temporalmente'), findsOneWidget);
  });

  testWidgets('Mis negocios loading error offers retry and empty state invites to register',
      (tester) async {
    final apps = _Apps(const [], fail: true);
    final router = _router(apps);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar tus negocios'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
    apps.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(apps.listCalls, 2);
    expect(find.text('¿Tienes un negocio?'), findsOneWidget);
    await tester.tap(find.text('Registrar mi negocio'));
    await tester.pumpAndSettle();
    expect(find.text('FORMULARIO'), findsOneWidget);
  });

  testWidgets('owner page for a non-approved or foreign id never shows another business',
      (tester) async {
    final apps = _Apps([_app(id: 'p1', name: 'Café Pendiente',
        status: CremaBusinessApplicationStatus.pending)]);
    await tester.pumpWidget(MaterialApp(home: MiNegocioActivoPage(
        applicationId: 'someone-else', service: apps)));
    await tester.pumpAndSettle();
    expect(find.text('Negocio no disponible'), findsOneWidget);
    expect(find.text('Café Pendiente'), findsNothing);
  });

  testWidgets('public business page shows the cover photo when present', (tester) async {
    const point = CremaPointModel(id: _pointId, name: 'Restobar Crema',
        description: null, type: 'BUSINESS', address: 'San Miguel',
        latitude: -12.08, longitude: -77.09, verified: true, sponsor: false,
        status: 'ACTIVE', createdAt: '', updatedAt: '',
        coverImageUrl: 'https://pub.r2.dev/business-offers/u/cover.jpg');
    await tester.pumpWidget(MaterialApp(home: NegocioCremaDetailPage(
        idOrSlug: _pointId, locationService: _Points(point), engagement: _NoOffers())));
    await tester.pumpAndSettle();
    expect(find.byType(GarraCachedNetworkImage), findsOneWidget);
    expect(find.text('Verificado por Garra'), findsOneWidget);
  });

  testWidgets('public business page without photo keeps the previous layout', (tester) async {
    const point = CremaPointModel(id: _pointId, name: 'Restobar JVC',
        description: null, type: 'BUSINESS', address: 'San Miguel',
        latitude: -12.08, longitude: -77.09, verified: true, sponsor: false,
        status: 'ACTIVE', createdAt: '', updatedAt: '');
    await tester.pumpWidget(MaterialApp(home: NegocioCremaDetailPage(
        idOrSlug: _pointId, locationService: _Points(point), engagement: _NoOffers())));
    await tester.pumpAndSettle();
    expect(find.byType(GarraCachedNetworkImage), findsNothing);
    expect(find.text('Ver ubicación del negocio'), findsOneWidget);
  });
}
