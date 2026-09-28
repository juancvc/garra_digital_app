import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/design/garra_colors.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_reaction_picker.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_models.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_service.dart';
import 'package:garra_digital_app/features/marketplace/presentation/providers/marketplace_provider.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_onboarding_page.dart';
import 'package:garra_digital_app/features/retention/data/retention_models.dart';
import 'package:garra_digital_app/features/retention/data/retention_service.dart';
import 'package:garra_digital_app/features/retention/presentation/events_page.dart';
import 'package:garra_digital_app/features/solidarity/data/solidarity_service.dart';
import 'package:garra_digital_app/features/solidarity/presentation/solidaria_page.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

// ---------------------------------------------------------------- fakes

class _FakeMedia extends MediaUploadService {
  _FakeMedia() : super(dio: Dio());

  final List<String> picks = ['a.jpg', 'b.jpg', 'c.jpg', 'd.jpg'];
  final List<String> uploads = [];
  final List<MediaUploadPurpose> purposes = [];

  @override
  Future<XFile?> pickImage({double maxSide = 1920}) async =>
      XFile('/garra_test/${picks.removeAt(0)}');

  @override
  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
  }) async {
    final name = file.path.split('/').last;
    uploads.add(name);
    purposes.add(purpose);
    return MediaDraft(
      localId: name,
      assetId: 'asset-$name',
      mediaUrl: 'https://cdn.garra/$name',
      state: MediaUploadState.ready,
    );
  }
}

class _FakeSolidarity extends SolidarityService {
  _FakeSolidarity() : super(dio: Dio());

  final List<Map<String, dynamic>> created = [];

  @override
  Future<List<SolidarityCampaign>> listPublic({String? type}) async => [
    SolidarityCampaign(
      id: 'c1',
      title: 'Donemos sangre',
      description: 'Hospital',
      type: 'BLOOD',
      city: 'Lima',
      evidenceImageUrl: 'https://cdn.garra/c1.jpg',
      status: 'ACTIVE',
      verificationStatus: 'VERIFIED',
    ),
    SolidarityCampaign(
      id: 'c2',
      title: 'Sin foto',
      description: 'x',
      type: 'FOOD',
      city: 'Lima',
      status: 'ACTIVE',
      verificationStatus: 'VERIFIED',
    ),
  ];

  @override
  Future<SolidarityCampaign> create(Map<String, dynamic> body) async {
    created.add(body);
    return SolidarityCampaign(
      id: 'new',
      title: body['title']?.toString() ?? '',
      description: '',
      type: 'OTHER',
      city: '',
      status: 'DRAFT',
      verificationStatus: 'PENDING',
    );
  }

  @override
  Future<SolidarityCampaign> submit(String id) async => create({'id': id});
}

GarraEventModel _event({String? imageUrl}) => GarraEventModel(
  id: 'e1',
  title: 'Previa crema',
  type: 'COMMUNITY_MEETUP',
  city: 'Lima',
  status: 'PUBLISHED',
  verificationStatus: 'VERIFIED',
  verifiedByGarra: true,
  checkedIn: false,
  imageUrl: imageUrl,
);

class _FakeRetention extends RetentionService {
  _FakeRetention({this.imageUrl}) : super(dio: Dio());

  final String? imageUrl;
  final List<Map<String, dynamic>> created = [];

  @override
  Future<List<GarraEventModel>> discoverEvents({String filter = 'WEEK'}) async =>
      [_event(imageUrl: imageUrl)];

  @override
  Future<GarraEventModel> createEvent(Map<String, dynamic> body) async {
    created.add(body);
    return _event();
  }
}

class _FakeMarketplace extends MarketplaceService {
  _FakeMarketplace() : super(dio: Dio());

  SellerOnboardingRequest? lastRequest;

  @override
  Future<SellerProfile?> getSellerMe() async => null;

  @override
  Future<SellerProfile> submitSeller(SellerOnboardingRequest request) async {
    lastRequest = request;
    return const SellerProfile(status: 'PENDING');
  }
}

// ---------------------------------------------------------------- helpers

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Color _textColor(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  return paragraph.text.style!.color!;
}

Color _scaffoldBg(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor!;

Future<void> _pumpRouted(
  WidgetTester tester, {
  required ThemeData theme,
  required String child,
  required Widget page,
  Widget? parent,
  MarketplaceService? marketplace,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/root/$child',
    routes: [
      GoRoute(
        path: '/root',
        builder: (_, _) => parent ?? const Scaffold(body: Text('ROOT')),
        routes: [GoRoute(path: child, builder: (_, _) => page)],
      ),
      GoRoute(
        path: '/marketplace/seller/dashboard',
        builder: (_, _) => const Scaffold(body: Text('DASHBOARD')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (marketplace != null)
          marketplaceServiceProvider.overrideWithValue(marketplace),
      ],
      child: MaterialApp.router(theme: theme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _add => find.byKey(const ValueKey('single_photo_add'));
Finder get _preview => find.byKey(const ValueKey('single_photo_preview'));
Finder get _change => find.byKey(const ValueKey('single_photo_change'));
Finder get _remove => find.byKey(const ValueKey('single_photo_remove'));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Select, change, remove and re-select: always at most ONE photo.
Future<void> _exerciseSinglePhoto(WidgetTester tester) async {
  expect(_add, findsOneWidget);
  expect(_preview, findsNothing);

  await _tap(tester, _add);
  expect(_preview, findsOneWidget);
  expect(_add, findsNothing, reason: 'no second photo can be added');
  expect(_change, findsOneWidget);
  expect(_remove, findsOneWidget);

  await _tap(tester, _change);
  expect(_preview, findsOneWidget);

  await _tap(tester, _remove);
  expect(_preview, findsNothing);
  expect(_add, findsOneWidget);

  await _tap(tester, _add);
  expect(_preview, findsOneWidget);
}

void main() {
  group('UX_08 one photo', () {
    testWidgets('9. Garra Solidaria: pick/change/remove, sends one asset', (
      tester,
    ) async {
      final media = _FakeMedia();
      final service = _FakeSolidarity();
      await _pumpRouted(
        tester,
        theme: AppTheme.lightTheme,
        child: 'nueva',
        page: SolidariaCreatePage(service: service, media: media),
      );

      await _exerciseSinglePhoto(tester);
      await _tap(tester, find.text('Enviar a revisi\u00f3n'));

      // a.jpg -> b.jpg (change) -> removed -> c.jpg: only c.jpg uploads.
      expect(media.uploads, ['c.jpg']);
      expect(media.purposes, [MediaUploadPurpose.solidarity]);
      expect(service.created.first['evidenceMediaAssetId'], 'asset-c.jpg');
      expect(find.text('ROOT'), findsOneWidget);
    });

    testWidgets('9b. Solidaria without photo stays compatible', (tester) async {
      final media = _FakeMedia();
      final service = _FakeSolidarity();
      await _pumpRouted(
        tester,
        theme: AppTheme.lightTheme,
        child: 'nueva',
        page: SolidariaCreatePage(service: service, media: media),
      );
      await _tap(tester, find.text('Enviar a revisi\u00f3n'));
      expect(media.uploads, isEmpty);
      expect(service.created.first.containsKey('evidenceMediaAssetId'), isFalse);
    });

    testWidgets('9c. Solidaria list shows the photo only when present', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SolidariaPage(service: _FakeSolidarity()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('solidarity_photo_c1')), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_photo_c2')), findsNothing);
    });

    testWidgets('10. Evento: one photo sent as mediaAssetId', (tester) async {
      final media = _FakeMedia();
      final service = _FakeRetention();
      await _pumpRouted(
        tester,
        theme: AppTheme.lightTheme,
        child: 'nuevo',
        page: CreateEventPage(service: service, media: media),
      );

      await tester.enterText(find.byType(TextField).first, 'Previa crema');
      await _exerciseSinglePhoto(tester);
      await _tap(tester, find.text('Enviar a revisi\u00f3n'));

      expect(media.uploads, ['c.jpg']);
      expect(media.purposes, [MediaUploadPurpose.communityPost]);
      expect(service.created.single['mediaAssetId'], 'asset-c.jpg');
    });

    testWidgets('10b. Evento list shows the published photo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EventsPage(
            service: _FakeRetention(imageUrl: 'https://cdn.garra/e1.jpg'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('event_photo_e1')), findsOneWidget);
    });

    testWidgets('11. Emprendimiento: one representative photo as store logo', (
      tester,
    ) async {
      final media = _FakeMedia();
      final service = _FakeMarketplace();
      await _pumpRouted(
        tester,
        theme: AppTheme.lightTheme,
        child: 'seller',
        page: SellerOnboardingPage(media: media),
        marketplace: service,
      );

      expect(find.text('Compra crema, apoya crema.'), findsOneWidget);
      expect(find.textContaining('no procesa pagos'), findsOneWidget);
      expect(find.textContaining('tiendas oficiales del club'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).at(0), '51999999999');
      await tester.enterText(find.byType(EditableText).at(1), 'Tienda Sur');
      await _exerciseSinglePhoto(tester);
      await _tap(tester, find.byType(CheckboxListTile));
      await _tap(tester, find.text('Enviar solicitud'));

      expect(media.uploads, ['c.jpg']);
      expect(media.purposes, [MediaUploadPurpose.storeLogo]);
      expect(service.lastRequest?.logoMediaAssetId, 'asset-c.jpg');
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    test('11b. submitSeller binds the logo through store/media before submit', () async {
      final calls = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add('${options.method} ${options.path}');
            dynamic data = {'success': true, 'data': <String, dynamic>{}};
            if (options.method == 'GET') {
              data = {'success': true, 'data': null};
            } else if (options.path == '/marketplace/seller/me') {
              data = {
                'success': true,
                'data': {'status': 'DRAFT'},
              };
            } else if (options.path.endsWith('/submit')) {
              data = {
                'success': true,
                'data': {'status': 'PENDING'},
              };
            } else if (options.path.endsWith('/store/media')) {
              expect(
                (options.data as Map)['logoMediaAssetId'],
                'asset-logo',
              );
            }
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: data),
            );
          },
        ),
      );

      final profile = await MarketplaceService(dio: dio).submitSeller(
        const SellerOnboardingRequest(
          whatsapp: '51999999999',
          storeName: 'Tienda Sur',
          ipAcknowledged: true,
          logoMediaAssetId: 'asset-logo',
        ),
      );

      expect(profile.isPending, isTrue);
      expect(calls, [
        'GET /marketplace/seller/me',
        'POST /marketplace/seller/me',
        'GET /marketplace/seller/me/store',
        'POST /marketplace/seller/me/store',
        'PUT /marketplace/seller/me/store/media',
        'POST /marketplace/seller/me/submit',
      ]);
    });
  });

  group('UX_08 Crema contrast', () {
    testWidgets('7. Crema: event screens use light surfaces + dark text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EventsPage(service: _FakeRetention()),
        ),
      );
      await tester.pumpAndSettle();
      const crema = GarraSemanticColors.crema;
      expect(_scaffoldBg(tester), crema.background);
      final title = _textColor(tester, find.text('Previa crema'));
      expect(_contrast(title, crema.surface), greaterThanOrEqualTo(4.5));
      final badge = _textColor(tester, find.text('Verificado por Garra'));
      expect(_contrast(badge, crema.surface), greaterThanOrEqualTo(4.5));
    });

    testWidgets('7b. Crema: reaction picker + photo field are readable', (
      tester,
    ) async {
      const crema = GarraSemanticColors.crema;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: GarraReactionPicker(currentReaction: 'GARRA'),
          ),
        ),
      );
      final label = _textColor(tester, find.text('Me encanta'));
      expect(label, crema.textPrimary);
      expect(_contrast(label, crema.surfaceRaised), greaterThanOrEqualTo(4.5));
      expect(
        find.text('Toca tu reacci\u00f3n otra vez para quitarla'),
        findsOneWidget,
      );

      await _pumpRouted(
        tester,
        theme: AppTheme.lightTheme,
        child: 'nueva',
        page: SolidariaCreatePage(
          service: _FakeSolidarity(),
          media: _FakeMedia(),
        ),
      );
      final photoLabel = _textColor(tester, find.text('Foto (opcional)'));
      expect(_contrast(photoLabel, crema.background), greaterThanOrEqualTo(4.5));
    });

    testWidgets('8. Noche: same screens keep the historical Noche colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: EventsPage(service: _FakeRetention()),
        ),
      );
      await tester.pumpAndSettle();
      // Values identical to the former hardcoded constants.
      expect(_scaffoldBg(tester), const Color(GarraColors.charcoal));
      expect(
        _textColor(tester, find.text('Verificado por Garra')),
        const Color(GarraColors.gold),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: GarraReactionPicker()),
        ),
      );
      final label = _textColor(tester, find.text('Me encanta'));
      expect(label, GarraSemanticColors.noche.textPrimary);
      expect(
        _contrast(label, const Color(GarraColors.surfaceRaised)),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}