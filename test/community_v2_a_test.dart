import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/design/garra_colors.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/core/widgets/garra_avatar.dart';
import 'package:garra_digital_app/core/widgets/garra_ui.dart';
import 'package:garra_digital_app/features/clans/data/clan_models.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_detail_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_manage_page.dart';
import 'package:garra_digital_app/features/clans/presentation/create_community_page.dart';
import 'package:garra_digital_app/features/clans/presentation/providers/clans_provider.dart';
import 'package:garra_digital_app/features/clans/presentation/widgets/garra_clan_card.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'clans_foundation_test.dart' show FakeClanService, sampleClan;

// COMMUNITY_V2_A: identity, creation, owner media editing and Crema theme.

class _FakeMedia extends MediaUploadService {
  _FakeMedia() : super(dio: Dio());

  final List<String> picks = ['a.jpg', 'b.jpg', 'c.jpg', 'd.jpg', 'e.jpg'];
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
    bool Function()? canStartRemote,
    CancelToken? cancelToken,
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

class _V2ClanService extends FakeClanService {
  _V2ClanService({super.detail});

  CreateClanRequest? lastCreate;
  UpdateClanRequest? lastUpdate;

  @override
  Future<ClanModel> createClan(CreateClanRequest request) async {
    lastCreate = request;
    // The backend is the slug authority.
    return sampleClan(slug: 'hinchas-de-ate', name: request.name);
  }

  @override
  Future<ClanModel> updateClan(String slug, UpdateClanRequest request) async {
    lastUpdate = request;
    return detail ?? sampleClan(slug: slug);
  }
}

const _owner = ClanMembershipSummary(role: 'OWNER', status: 'ACTIVE');
const _admin = ClanMembershipSummary(role: 'ADMIN', status: 'ACTIVE');
const _member = ClanMembershipSummary(role: 'MEMBER', status: 'ACTIVE');

Future<void> _pumpRouted(
  WidgetTester tester, {
  required String initialLocation,
  required FakeClanService service,
  ThemeData? theme,
  MediaUploadService? media,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/clans/create',
        builder: (context, state) => CreateCommunityPage(media: media),
      ),
      GoRoute(
        path: '/clans/:slug',
        builder: (context, state) =>
            state.pathParameters['slug'] == 'hinchas-de-ate'
            ? const Scaffold(body: Text('DETAIL:hinchas-de-ate'))
            : ClanDetailPage(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/clans/:slug/manage',
        builder: (context, state) => ClanManagePage(
          slug: state.pathParameters['slug'] ?? '',
          media: media,
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [clanServiceProvider.overrideWithValue(service)],
      child: MaterialApp.router(
        theme: theme ?? AppTheme.darkTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inField(String fieldKey, String childKey) => find.descendant(
  of: find.byKey(ValueKey(fieldKey)),
  matching: find.byKey(ValueKey(childKey)),
);

Color? _textColor(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).text.style?.color;

void main() {
  group('create form', () {
    testWidgets('CREATE_FORM_HAS_NO_IDENTIFICADOR_AND_HONEST_COPY', (
      tester,
    ) async {
      await _pumpRouted(
        tester,
        initialLocation: '/clans/create',
        service: _V2ClanService(),
        media: _FakeMedia(),
      );
      expect(find.text('Identificador'), findsNothing);
      expect(find.textContaining('min\u00fasculas'), findsNothing);
      expect(find.text('Nombre'), findsWidgets);
      expect(find.text('Descripci\u00f3n'), findsWidgets);
      expect(find.text('Ciudad'), findsWidgets);
      expect(find.text('Pa\u00eds'), findsWidgets);
      expect(find.text('Privacidad'), findsOneWidget);
      expect(find.text('Ingreso'), findsOneWidget);
      // Join policy copy mirrors backend enforcement.
      expect(find.text('Abierto'), findsOneWidget);
      expect(
        find.text('Los hinchas pueden unirse directamente.'),
        findsOneWidget,
      );
      expect(find.text('Con aprobaci\u00f3n'), findsOneWidget);
      expect(
        find.text(
          'El l\u00edder o los administradores aprueban las solicitudes.',
        ),
        findsOneWidget,
      );
      expect(find.text('Solo invitaci\u00f3n'), findsOneWidget);
      expect(
        find.text('Solo se puede ingresar mediante una invitaci\u00f3n.'),
        findsOneWidget,
      );
      // Privacy copy: PRIVATE is the only one hidden from discovery, posts
      // are always members-only.
      expect(
        find.text(
          'No aparece en Descubrir ni en b\u00fasquedas. Solo miembros e invitados pueden verla.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Aparece en Descubrir, pero solo los miembros ven la lista de miembros.',
        ),
        findsOneWidget,
      );
      expect(find.text(communityPostsPrivacyNote), findsOneWidget);
    });

    testWidgets('CREATE_AVATAR_AND_COVER_ADD_CHANGE_REMOVE', (tester) async {
      final media = _FakeMedia();
      await _pumpRouted(
        tester,
        initialLocation: '/clans/create',
        service: _V2ClanService(),
        media: media,
      );
      for (final field in ['community_avatar_field', 'community_cover_field']) {
        expect(_inField(field, 'single_photo_add'), findsOneWidget);
        expect(_inField(field, 'single_photo_preview'), findsNothing);
        await tester.tap(_inField(field, 'single_photo_add'));
        await tester.pumpAndSettle();
        expect(_inField(field, 'single_photo_preview'), findsOneWidget);
        await tester.tap(_inField(field, 'single_photo_change'));
        await tester.pumpAndSettle();
        expect(_inField(field, 'single_photo_preview'), findsOneWidget);
        await tester.tap(_inField(field, 'single_photo_remove'));
        await tester.pumpAndSettle();
        expect(_inField(field, 'single_photo_preview'), findsNothing);
        expect(_inField(field, 'single_photo_add'), findsOneWidget);
      }
      expect(find.text('Agregar avatar'), findsOneWidget);
      expect(find.text('Agregar portada'), findsOneWidget);
      // Nothing is uploaded until the form is submitted.
      expect(media.uploads, isEmpty);
    });

    testWidgets('CREATE_SENDS_NO_SLUG_AND_MEDIA_IDS_THEN_USES_RESPONSE_SLUG', (
      tester,
    ) async {
      final media = _FakeMedia();
      final service = _V2ClanService();
      await _pumpRouted(
        tester,
        initialLocation: '/clans/create',
        service: service,
        media: media,
      );
      await tester.enterText(
        find.byKey(const ValueKey('community_name_field')),
        'Hinchas de Ate',
      );
      await tester.tap(_inField('community_avatar_field', 'single_photo_add'));
      await tester.pumpAndSettle();
      await tester.tap(_inField('community_cover_field', 'single_photo_add'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community_join_REQUEST')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(GarraPrimaryButton, 'Crear comunidad'),
      );
      await tester.pumpAndSettle();

      final request = service.lastCreate!;
      expect(request.slug, isNull);
      final json = request.toJson();
      expect(json.containsKey('slug'), isFalse);
      expect(json['name'], 'Hinchas de Ate');
      expect(json['countryCode'], 'PE');
      expect(json['joinPolicy'], 'REQUEST');
      expect(json['logoMediaAssetId'], 'asset-a.jpg');
      expect(json['bannerMediaAssetId'], 'asset-b.jpg');
      expect(media.purposes, everyElement(MediaUploadPurpose.communityPost));
      expect(find.text('DETAIL:hinchas-de-ate'), findsOneWidget);
    });

    testWidgets('CREATE_WITHOUT_IMAGES_SENDS_NO_MEDIA_IDS', (tester) async {
      final service = _V2ClanService();
      await _pumpRouted(
        tester,
        initialLocation: '/clans/create',
        service: service,
        media: _FakeMedia(),
      );
      await tester.enterText(
        find.byKey(const ValueKey('community_name_field')),
        'Hinchas de Ate',
      );
      await tester.tap(
        find.widgetWithText(GarraPrimaryButton, 'Crear comunidad'),
      );
      await tester.pumpAndSettle();
      final json = service.lastCreate!.toJson();
      expect(json.containsKey('slug'), isFalse);
      expect(json.containsKey('logoMediaAssetId'), isFalse);
      expect(json.containsKey('bannerMediaAssetId'), isFalse);
    });
  });

  group('cards and detail', () {
    testWidgets('CARD_USES_AVATAR_AND_SHOWS_PRIVACY', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: GarraClanCard(
              clan: sampleClan(
                logoUrl: 'https://cdn.garra/logo.jpg',
                visibility: 'PRIVATE',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final avatar = tester.widget<GarraAvatar>(
        find.byKey(const ValueKey('clan_card_avatar')),
      );
      expect(avatar.avatarUrl, 'https://cdn.garra/logo.jpg');
      expect(find.text('Garra Surco'), findsOneWidget);
      expect(find.textContaining('Lima'), findsOneWidget);
      expect(find.text('1.284 miembros'), findsOneWidget);
      expect(find.text('Privada'), findsOneWidget);
    });

    testWidgets('CARD_FALLBACK_WITHOUT_LOGO_SHOWS_INITIALS', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: GarraClanCard(clan: sampleClan())),
        ),
      );
      final avatar = tester.widget<GarraAvatar>(
        find.byKey(const ValueKey('clan_card_avatar')),
      );
      expect(avatar.avatarUrl, isNull);
      expect(find.text('GS'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      // Public communities do not need a privacy pill.
      expect(find.text('P\u00fablica'), findsNothing);
    });

    testWidgets('DETAIL_SHOWS_COVER_AND_AVATAR', (tester) async {
      await _pumpRouted(
        tester,
        initialLocation: '/clans/garra-surco',
        service: _V2ClanService(
          detail: sampleClan(
            logoUrl: 'https://cdn.garra/logo.jpg',
            bannerUrl: 'https://cdn.garra/cover.jpg',
            visibility: 'MEMBERS_ONLY',
          ),
        ),
      );
      expect(find.byKey(const ValueKey('clan_detail_cover')), findsOneWidget);
      final avatar = tester.widget<GarraAvatar>(
        find.byKey(const ValueKey('clan_detail_avatar')),
      );
      expect(avatar.avatarUrl, 'https://cdn.garra/logo.jpg');
      expect(find.textContaining('1.284 miembros'), findsOneWidget);
      expect(find.textContaining('Lima'), findsWidgets);
      expect(find.textContaining('Solo miembros'), findsWidgets);
    });

    testWidgets('DETAIL_FALLBACK_WITHOUT_IMAGES', (tester) async {
      await _pumpRouted(
        tester,
        initialLocation: '/clans/garra-surco',
        service: _V2ClanService(detail: sampleClan()),
      );
      expect(find.byKey(const ValueKey('clan_detail_cover')), findsNothing);
      expect(
        find.byKey(const ValueKey('clan_detail_cover_fallback')),
        findsOneWidget,
      );
      final avatar = tester.widget<GarraAvatar>(
        find.byKey(const ValueKey('clan_detail_avatar')),
      );
      expect(avatar.avatarUrl, isNull);
      expect(find.byType(Image), findsNothing);
      // Existing CTA behaviour is unchanged.
      expect(find.text('Unirme'), findsOneWidget);
    });

    testWidgets('EDITOR_SEES_ADMINISTRAR_COMUNIDAD', (tester) async {
      for (final role in [_owner, _admin]) {
        await _pumpRouted(
          tester,
          initialLocation: '/clans/garra-surco',
          service: _V2ClanService(detail: sampleClan(myMembership: role)),
        );
        expect(
          find.text('Administrar comunidad'),
          findsOneWidget,
          reason: role.role,
        );
      }
    });

    testWidgets('MEMBER_DOES_NOT_SEE_ADMINISTRAR', (tester) async {
      await _pumpRouted(
        tester,
        initialLocation: '/clans/garra-surco',
        service: _V2ClanService(detail: sampleClan(myMembership: _member)),
      );
      expect(find.text('Administrar comunidad'), findsNothing);
      expect(find.byKey(const ValueKey('clan_manage_entry')), findsNothing);
      expect(find.byTooltip('Invitar'), findsNothing);
    });
  });

  group('owner settings', () {
    testWidgets('OWNER_CHANGES_COVER_AND_REMOVES_AVATAR', (tester) async {
      final media = _FakeMedia();
      final service = _V2ClanService(
        detail: sampleClan(
          myMembership: _owner,
          logoUrl: 'https://cdn.garra/logo.jpg',
          bannerUrl: 'https://cdn.garra/cover.jpg',
        ),
      );
      await _pumpRouted(
        tester,
        initialLocation: '/clans/garra-surco/manage',
        service: service,
        media: media,
      );
      expect(find.text('Administrar comunidad'), findsOneWidget);
      // Saved images are previewed with change / remove.
      expect(
        _inField('manage_avatar_field', 'single_photo_preview'),
        findsOneWidget,
      );
      expect(
        _inField('manage_cover_field', 'single_photo_preview'),
        findsOneWidget,
      );

      await tester.tap(_inField('manage_avatar_field', 'single_photo_remove'));
      await tester.pumpAndSettle();
      expect(
        _inField('manage_avatar_field', 'single_photo_add'),
        findsOneWidget,
      );
      await tester.tap(_inField('manage_cover_field', 'single_photo_change'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage_visibility_PRIVATE')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final json = service.lastUpdate!.toJson();
      expect(json['clearLogo'], isTrue);
      expect(json.containsKey('logoMediaAssetId'), isFalse);
      expect(json['bannerMediaAssetId'], 'asset-a.jpg');
      expect(json.containsKey('clearBanner'), isFalse);
      expect(json['visibility'], 'PRIVATE');
      expect(json.containsKey('slug'), isFalse);
      expect(media.purposes, [MediaUploadPurpose.communityPost]);
    });

    testWidgets('OWNER_ADDS_AVATAR_WITHOUT_TOUCHING_COVER', (tester) async {
      final media = _FakeMedia();
      final service = _V2ClanService(detail: sampleClan(myMembership: _owner));
      await _pumpRouted(
        tester,
        initialLocation: '/clans/garra-surco/manage',
        service: service,
        media: media,
      );
      await tester.tap(_inField('manage_avatar_field', 'single_photo_add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final json = service.lastUpdate!.toJson();
      expect(json['logoMediaAssetId'], 'asset-a.jpg');
      expect(json.containsKey('bannerMediaAssetId'), isFalse);
      expect(json.containsKey('clearLogo'), isFalse);
      expect(json.containsKey('clearBanner'), isFalse);
    });
  });

  group('theme', () {
    testWidgets('CREMA_CARD_FORM_DETAIL_READABLE', (tester) async {
      const crema = GarraSemanticColors.crema;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: GarraClanCard(
              clan: sampleClan(visibility: 'PRIVATE'),
              roleLabel: 'Propietario',
            ),
          ),
        ),
      );
      expect(_textColor(tester, find.text('Garra Surco')), crema.textPrimary);
      expect(_textColor(tester, find.text('Privada')), crema.textSecondary);
      expect(_textColor(tester, find.text('Propietario')), crema.textPrimary);

      await _pumpRouted(
        tester,
        initialLocation: '/clans/create',
        service: _V2ClanService(),
        media: _FakeMedia(),
        theme: AppTheme.lightTheme,
      );
      expect(_textColor(tester, find.text('Abierto')), crema.textPrimary);
      expect(
        _textColor(
          tester,
          find.text('Los hinchas pueden unirse directamente.'),
        ),
        crema.textSecondary,
      );
      final selectedTile = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const ValueKey('community_join_OPEN')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(selectedTile.color, crema.surfaceRaised);
      expect(selectedTile.color, isNot(const Color(GarraColors.garnetDeep)));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, crema.background);

      await _pumpRouted(
        tester,
        initialLocation: '/clans/garra-surco',
        service: _V2ClanService(detail: sampleClan(myMembership: _owner)),
        theme: AppTheme.lightTheme,
      );
      final detailScaffold = tester.widget<Scaffold>(
        find.byType(Scaffold).first,
      );
      expect(detailScaffold.backgroundColor, crema.background);
      expect(
        _textColor(tester, find.text('Garra Surco').last),
        isNot(const Color(GarraColors.cream)),
      );
      expect(
        _textColor(tester, find.text('Administrar comunidad')),
        crema.textPrimary,
      );
    });

    testWidgets('NOCHE_KEEPS_DARK_SURFACES', (tester) async {
      await _pumpRouted(
        tester,
        initialLocation: '/clans/create',
        service: _V2ClanService(),
        media: _FakeMedia(),
      );
      final selectedTile = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const ValueKey('community_visibility_PUBLIC')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(selectedTile.color, const Color(GarraColors.garnetDeep));
      final idleTile = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const ValueKey('community_visibility_PRIVATE')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(idleTile.color, const Color(GarraColors.surface));
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        const Color(GarraColors.charcoal),
      );

      await _pumpRouted(
        tester,
        initialLocation: '/clans/garra-surco',
        service: _V2ClanService(detail: sampleClan(myMembership: _owner)),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        const Color(GarraColors.charcoal),
      );
      final title = _textColor(tester, find.text('Administrar comunidad'));
      expect(title!.computeLuminance(), greaterThan(0.7));
    });
  });
}
