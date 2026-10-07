import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/router/app_router.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_form.dart';
import 'package:garra_digital_app/features/solidarity/data/solidarity_service.dart';
import 'package:garra_digital_app/features/solidarity/presentation/solidaria_mine_page.dart';
import 'package:garra_digital_app/features/solidarity/presentation/solidaria_page.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// DEMO_HARDENING_04: Garra Solidaria demo lifecycle against the real wire
/// contract (Dio interceptor + real SolidarityService):
/// first use -> create (validation, one draft, submit) -> owner state
/// (borrador / en revisi\u00f3n / publicada / no aprobada + motivo) -> admin
/// verify/reject (server side) -> public discovery/detail/contact.

const _a = '00000000-0000-4000-8000-0000000000a1';
const _b = '00000000-0000-4000-8000-0000000000b2';
const _c = '00000000-0000-4000-8000-0000000000c3';
const _d = '00000000-0000-4000-8000-0000000000d4';

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

/// In-memory mirror of SolidarityCampaignService / entity guards.
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
  final Map<String, Map<String, dynamic>> campaigns = {};
  bool viewerIsOwner = true;
  int listFailures = 0;
  int detailFailures = 0;
  int mineFailures = 0;
  int submitFailures = 0;
  int _seq = 0;

  List<String> get writes =>
      calls.where((c) => c.method != 'GET').map((c) => c.toString()).toList();
  _Call last(String method, String path) =>
      calls.lastWhere((c) => c.method == method && c.path == path);

  static bool _public(Map<String, dynamic> c) =>
      c['status'] == 'ACTIVE' && c['verificationStatus'] == 'VERIFIED';

  static bool _pending(Map<String, dynamic> c) =>
      c['verificationStatus'] == 'PENDING' && c['submittedAt'] != null;

  /// Admin step (Garra Admin / in-app /admin/solidaria): verify publishes.
  void verify(String id) => campaigns[id]!
    ..['verificationStatus'] = 'VERIFIED'
    ..['status'] = 'ACTIVE'
    ..['rejectionReason'] = null;

  /// Admin step: reject returns it to the owner with a reason.
  void reject(String id, String reason) => campaigns[id]!
    ..['verificationStatus'] = 'REJECTED'
    ..['status'] = 'DRAFT'
    ..['rejectionReason'] = reason
    ..['submittedAt'] = null;

  Object? _respond(RequestOptions o) {
    final p = o.path;
    final m = o.method;
    const base = '/solidarity/campaigns';
    if (p == base && m == 'GET') {
      if (listFailures > 0) {
        listFailures--;
        return const _Fail(500, 'Internal Server Error');
      }
      final type = o.queryParameters['type'];
      return campaigns.values
          .where(_public)
          .where((c) => type == null || c['type'] == type)
          .toList()
          .reversed
          .toList();
    }
    if (p == '$base/me' && m == 'GET') {
      if (mineFailures > 0) {
        mineFailures--;
        return const _Fail(500, 'Internal Server Error');
      }
      return campaigns.values.toList().reversed.toList();
    }
    if (p == base && m == 'POST') {
      final body = Map<String, dynamic>.from(o.data as Map);
      for (final f in ['title', 'description', 'type', 'city', 'contactName']) {
        if ((body[f]?.toString() ?? '').trim().isEmpty) {
          return const _Fail(400, 'Validation failed');
        }
      }
      final id = '00000000-0000-4000-8000-00000000000${++_seq}';
      campaigns[id] = {
        ...body,
        'id': id,
        'createdByUsername': 'hincha',
        'evidenceImageUrl': body['evidenceMediaAssetId'] == null
            ? null
            : 'https://cdn.garra/${body['evidenceMediaAssetId']}.jpg',
        'status': 'DRAFT',
        'verificationStatus': 'PENDING',
        'rejectionReason': null,
        'submittedAt': null,
      };
      return campaigns[id];
    }
    final submit = RegExp('^$base/([^/]+)/submit\$').firstMatch(p);
    if (submit != null && m == 'POST') {
      final c = campaigns[submit.group(1)];
      if (c == null) return const _Fail(404, 'Not found');
      if (submitFailures > 0) {
        submitFailures--;
        return const _Fail(503, 'Service Unavailable');
      }
      if (c['verificationStatus'] == 'VERIFIED') {
        return const _Fail(400, 'Already verified');
      }
      if (_pending(c)) return const _Fail(400, 'Already pending review');
      c
        ..['submittedAt'] = '2026-10-07T10:00:00Z'
        ..['verificationStatus'] = 'PENDING'
        ..['rejectionReason'] = null
        ..['status'] = 'DRAFT';
      return c;
    }
    final one = RegExp('^$base/([^/]+)\$').firstMatch(p);
    if (one != null) {
      final c = campaigns[one.group(1)];
      if (m == 'GET') {
        if (detailFailures > 0) {
          detailFailures--;
          return const _Fail(500, 'Internal Server Error');
        }
        if (c == null || (!_public(c) && !viewerIsOwner)) {
          return const _Fail(404, 'Solidarity campaign not found');
        }
        return c;
      }
      if (m == 'PUT') {
        if (c == null) return const _Fail(404, 'Not found');
        if (_pending(c)) return const _Fail(400, 'Campaign pending review');
        if (c['verificationStatus'] == 'VERIFIED') {
          return const _Fail(400, 'Campaign verified');
        }
        final body = Map<String, dynamic>.from(o.data as Map);
        final evidence = body.remove('evidenceMediaAssetId');
        c.addAll(body);
        if (evidence != null) {
          c['evidenceImageUrl'] = 'https://cdn.garra/$evidence.jpg';
        }
        return c;
      }
    }
    return const _Fail(404, 'Not found');
  }
}

Map<String, dynamic> _campaign(
  String id, {
  String title = 'Colecta de v\u00edveres',
  String type = 'FOOD',
  String status = 'ACTIVE',
  String verification = 'VERIFIED',
  String? submittedAt = '2026-10-06T10:00:00Z',
  String? reason,
  String? whatsapp = '+51 999 000 111',
  String? phone = '014445555',
  String? image,
}) => {
  'id': id,
  'title': title,
  'description': 'Ayuda para familias de la barra.',
  'type': type,
  'city': 'Lima',
  'district': 'Ate',
  'contactName': 'Ana',
  'contactWhatsapp': whatsapp,
  'contactPhone': phone,
  'createdByUsername': 'hincha',
  'evidenceImageUrl': image,
  'status': status,
  'verificationStatus': verification,
  'rejectionReason': reason,
  'submittedAt': submittedAt,
};

class _Media extends MediaUploadService {
  _Media({this.fail = false}) : super(dio: Dio());
  bool fail;
  final List<String> uploads = [];

  @override
  Future<XFile?> pickImage({double maxSide = 1920}) async =>
      XFile('/garra_test/evidencia.jpg');

  @override
  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
    bool Function()? canStartRemote,
    CancelToken? cancelToken,
  }) async {
    uploads.add(purpose.apiValue);
    if (fail) {
      return MediaDraft(
        localId: 'x',
        state: MediaUploadState.failed,
        error: 'No pudimos subir la foto. Int\u00e9ntalo de nuevo.',
      );
    }
    return MediaDraft(
      localId: 'x',
      assetId: 'asset-1',
      mediaUrl: 'https://cdn.garra/asset-1.jpg',
      state: MediaUploadState.ready,
    );
  }
}

class _Launcher {
  bool ok = true;
  final List<Uri> uris = [];
  Future<bool> call(Uri uri) async {
    uris.add(uri);
    return ok;
  }
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _Wire wire, {
  required String initial,
  _Media? media,
  _Launcher? launcher,
  Size size = const Size(900, 2400),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final service = SolidarityService(dio: wire.dio);
  final launch = launcher ?? _Launcher();
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/solidaria/nueva',
        builder: (_, _) =>
            SolidariaCreatePage(service: service, media: media ?? _Media()),
      ),
      GoRoute(
        path: '/solidaria/:id/editar',
        builder: (_, s) => SolidariaCreatePage(
          service: service,
          media: media ?? _Media(),
          campaignId: s.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/solidaria',
        builder: (_, _) => SolidariaPage(service: service),
        routes: [
          GoRoute(
            path: 'mias',
            builder: (_, _) => SolidariaMinePage(service: service),
          ),
          GoRoute(
            path: ':id',
            builder: (_, s) => SolidariaDetailPage(
              campaignId: s.pathParameters['id']!,
              service: service,
              launcher: launch.call,
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Lets requests started by a freshly built route finish (no pending timers).
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton).last);
  await tester.pumpAndSettle();
}

Finder get _description => find.descendant(
  of: find.byKey(const ValueKey('solidarity_description')),
  matching: find.byType(TextField),
);

Future<void> _fill(
  WidgetTester tester, {
  String title = 'Donemos sangre',
  String whatsapp = '51987654321',
}) async {
  Future<void> enter(Finder f, String v) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, v);
  }

  await enter(find.byKey(const ValueKey('solidarity_title')), title);
  await enter(_description, 'Se necesita sangre O+ para un hincha.');
  await enter(find.byKey(const ValueKey('solidarity_city')), 'Lima');
  await enter(find.byKey(const ValueKey('solidarity_district')), 'Ate');
  await enter(find.byKey(const ValueKey('solidarity_contact')), 'Ana');
  await enter(find.byKey(const ValueKey('solidarity_whatsapp')), whatsapp);
  await tester.pumpAndSettle();
}

Finder get _submitButton => find.descendant(
  of: find.byType(GarraFormActionBar),
  matching: find.byType(FilledButton),
);

void main() {
  group('DH04 navigation audit', () {
    test('literal Solidaria routes win over :id; ids are UUIDs', () {
      final router = createAppRouter(redirect: (_, _) => null);
      addTearDown(router.dispose);
      RouteMatchList match(String uri) =>
          router.configuration.findMatch(Uri.parse(uri));
      expect(match('/solidaria').last.route.name, 'solidaria');
      expect(match('/solidaria/nueva').last.route.name, 'solidaria-nueva');
      expect(match('/solidaria/mias').last.route.name, 'solidaria-mine');
      final detail = match('/solidaria/$_a');
      expect(detail.last.route.name, 'solidaria-detail');
      expect(detail.pathParameters['id'], _a);
      final edit = match('/solidaria/$_a/editar');
      expect(edit.last.route.name, 'solidaria-editar');
      expect(edit.pathParameters['id'], _a);
    });
  });

  group('DH04 model', () {
    test('owner state derives from the real contract', () {
      SolidarityOwnerState s(Map<String, dynamic> j) =>
          SolidarityCampaign.fromJson(j).ownerState;
      expect(
        s(_campaign(_a, status: 'DRAFT', verification: 'PENDING', submittedAt: null)),
        SolidarityOwnerState.draft,
      );
      expect(
        s(_campaign(_a, status: 'DRAFT', verification: 'PENDING')),
        SolidarityOwnerState.inReview,
      );
      expect(s(_campaign(_a)), SolidarityOwnerState.published);
      expect(
        s(_campaign(_a, status: 'DRAFT', verification: 'REJECTED', submittedAt: null)),
        SolidarityOwnerState.rejected,
      );
      expect(
        s(_campaign(_a, status: 'CLOSED')),
        SolidarityOwnerState.closed,
      );
      final rejected = SolidarityCampaign.fromJson(
        _campaign(_a, status: 'DRAFT', verification: 'REJECTED', reason: 'Falta detalle'),
      );
      expect(rejected.canEdit, isTrue);
      expect(rejected.isPublic, isFalse);
      expect(rejected.rejectionReason, 'Falta detalle');
      final pending = SolidarityCampaign.fromJson(
        _campaign(_a, status: 'DRAFT', verification: 'PENDING'),
      );
      expect(pending.canEdit, isFalse);
    });

    test('backend business errors become Spanish copy', () {
      DioException e(int status, String message) => DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: status,
          data: {'message': message},
        ),
      );
      expect(
        solidarityActionErrorMessage(e(400, 'Not campaign owner')),
        contains('Solo quien cre\u00f3'),
      );
      expect(
        solidarityActionErrorMessage(e(400, 'Campaign pending review')),
        contains('ya est\u00e1 en revisi\u00f3n'),
      );
      expect(
        solidarityActionErrorMessage(e(400, 'Validation failed')),
        contains('Revisa los datos'),
      );
      expect(
        solidarityActionErrorMessage(e(500, 'Internal Server Error')),
        isNot(contains('Internal')),
      );
    });
  });

  group('DH04 first use and discovery', () {
    testWidgets('empty Solidaria explains itself and how it works', (tester) async {
      final wire = _Wire();
      await _pump(tester, wire, initial: '/solidaria');
      expect(find.text('A\u00fan no hay iniciativas publicadas'), findsOneWidget);
      expect(find.textContaining('conecta a la comunidad'), findsOneWidget);
      expect(find.textContaining('Garra la revisa'), findsOneWidget);
      expect(find.text('No procesamos dinero, donaciones ni pagos.'), findsOneWidget);
      expect(find.text('Proponer iniciativa'), findsWidgets);

      await _tap(tester, find.byKey(const ValueKey('solidaria_how_it_works_link')));
      expect(find.byKey(const ValueKey('solidaria_how_it_works')), findsOneWidget);
      expect(find.text('Garra la revisa'), findsOneWidget);
      expect(find.text('Si no se aprueba'), findsOneWidget);
      expect(find.textContaining('no es p\u00fablica hasta'), findsOneWidget);
      await _tap(tester, find.text('Entendido'));
      expect(find.byKey(const ValueKey('solidaria_how_it_works')), findsNothing);
    });

    testWidgets('load error shows error + retry (never empty, never stuck)', (
      tester,
    ) async {
      final wire = _Wire()
        ..listFailures = 1
        ..campaigns[_a] = _campaign(_a);
      await _pump(tester, wire, initial: '/solidaria');
      expect(find.text('No pudimos cargar las iniciativas'), findsOneWidget);
      expect(find.text('A\u00fan no hay iniciativas publicadas'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await _tap(tester, find.text('Reintentar'));
      expect(find.text('Colecta de v\u00edveres'), findsOneWidget);
    });

    testWidgets('only public campaigns are listed; filter empty resets', (
      tester,
    ) async {
      final wire = _Wire()
        ..campaigns[_a] = _campaign(_a, title: 'Publicada')
        ..campaigns[_b] = _campaign(
          _b,
          title: 'En revisi\u00f3n secreta',
          status: 'DRAFT',
          verification: 'PENDING',
        )
        ..campaigns[_c] = _campaign(
          _c,
          title: 'Rechazada secreta',
          status: 'DRAFT',
          verification: 'REJECTED',
          submittedAt: null,
        );
      await _pump(tester, wire, initial: '/solidaria');
      expect(find.text('Publicada'), findsOneWidget);
      expect(find.text('En revisi\u00f3n secreta'), findsNothing);
      expect(find.text('Rechazada secreta'), findsNothing);
      expect(find.byKey(const ValueKey('solidarity_verified_chip')), findsOneWidget);

      await _tap(tester, find.widgetWithText(ChoiceChip, 'Sangre'));
      expect(wire.last('GET', '/solidarity/campaigns').query['type'], 'BLOOD');
      expect(find.text('No hay iniciativas de este tipo'), findsOneWidget);
      await _tap(tester, find.text('Ver todas'));
      expect(find.text('Publicada'), findsOneWidget);
    });

    testWidgets('card -> detail -> back; public detail shows how to help', (
      tester,
    ) async {
      final launcher = _Launcher();
      final wire = _Wire()
        ..viewerIsOwner = false
        ..campaigns[_a] = _campaign(_a, image: 'https://cdn.garra/broken.jpg');
      await _pump(tester, wire, initial: '/solidaria', launcher: launcher);
      await _tap(tester, find.text('Colecta de v\u00edveres'));
      expect(find.text('Iniciativa'), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_verified_chip')), findsOneWidget);
      expect(find.text('Ayuda para familias de la barra.'), findsOneWidget);
      expect(find.text('Alimentos'), findsOneWidget);
      expect(find.textContaining('Lima \u00b7 Ate'), findsOneWidget);
      expect(find.text('Publicada por @hincha'), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_detail_photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_how_to_help')), findsOneWidget);
      expect(find.text('Coordina directamente con Ana.'), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_owner_panel')), findsNothing);
      expect(tester.takeException(), isNull);

      await _tap(tester, find.text('Contactar por WhatsApp'));
      expect(launcher.uris.single.toString(), 'https://wa.me/51999000111');
      await _tap(tester, find.text('Llamar'));
      expect(launcher.uris.last.toString(), 'tel:014445555');

      launcher.ok = false;
      await _tap(tester, find.text('Contactar por WhatsApp'));
      expect(find.textContaining('No pudimos abrir WhatsApp'), findsOneWidget);

      await _back(tester);
      expect(find.text('Garra Solidaria'), findsOneWidget);
    });

    testWidgets('hidden campaign is "no disponible"; failures retry', (
      tester,
    ) async {
      final wire = _Wire()
        ..viewerIsOwner = false
        ..campaigns[_b] = _campaign(_b, status: 'DRAFT', verification: 'PENDING');
      final router = await _pump(tester, wire, initial: '/solidaria');
      router.push('/solidaria/$_b');
      await tester.pumpAndSettle();
      expect(find.text('Esta iniciativa no est\u00e1 disponible'), findsOneWidget);
      expect(find.text('Contactar por WhatsApp'), findsNothing);
      await _tap(tester, find.text('Ver Garra Solidaria'));
      expect(find.text('Garra Solidaria'), findsOneWidget);

      wire
        ..campaigns[_a] = _campaign(_a)
        ..detailFailures = 1;
      router.push('/solidaria/$_a');
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar la iniciativa'), findsOneWidget);
      await _tap(tester, find.text('Reintentar'));
      expect(find.text('Colecta de v\u00edveres'), findsOneWidget);
    });
  });

  group('DH04 create', () {
    testWidgets('validation blocks the request with Spanish messages', (
      tester,
    ) async {
      final wire = _Wire();
      await _pump(tester, wire, initial: '/solidaria/nueva');
      expect(find.byKey(const ValueKey('solidarity_create_review_note')), findsOneWidget);
      await _tap(tester, _submitButton);
      expect(wire.writes, isEmpty);
      expect(find.text('Completa el t\u00edtulo.'), findsOneWidget);
      expect(find.text('Completa la descripci\u00f3n.'), findsOneWidget);
      expect(find.text('Completa la ciudad.'), findsOneWidget);
      expect(find.text('Completa el nombre de contacto.'), findsOneWidget);
      expect(
        find.text('Agrega un WhatsApp o un tel\u00e9fono para que puedan ayudarte.'),
        findsOneWidget,
      );
      expect(find.text('Revisa los campos marcados.'), findsOneWidget);

      await _fill(tester, whatsapp: '12');
      await _tap(tester, _submitButton);
      expect(wire.writes, isEmpty);
      expect(find.textContaining('c\u00f3digo de pa\u00eds (ej.'), findsOneWidget);
    });

    testWidgets('list -> create -> submit -> back; stays private until approved', (
      tester,
    ) async {
      final wire = _Wire();
      final media = _Media();
      await _pump(tester, wire, initial: '/solidaria', media: media);
      await _tap(tester, find.byKey(const ValueKey('solidaria_propose_fab')));
      expect(find.text('Nueva iniciativa'), findsOneWidget);
      await _fill(tester);
      await _tap(tester, find.byKey(const ValueKey('single_photo_add')));
      await _tap(tester, _submitButton);

      expect(media.uploads, ['SOLIDARITY_EVIDENCE']);
      final id = wire.campaigns.keys.single;
      expect(wire.writes, [
        'POST /solidarity/campaigns',
        'POST /solidarity/campaigns/$id/submit',
      ]);
      final body = wire.last('POST', '/solidarity/campaigns').data as Map;
      expect(body['title'], 'Donemos sangre');
      expect(body['district'], 'Ate');
      expect(body['contactName'], 'Ana');
      expect(body['contactWhatsapp'], '51987654321');
      expect(body['contactPhone'], isNull);
      expect(body['evidenceMediaAssetId'], 'asset-1');

      expect(find.text('Garra Solidaria'), findsOneWidget);
      expect(
        find.text('Enviada a revisi\u00f3n. Garra la revisar\u00e1 antes de publicarla.'),
        findsOneWidget,
      );
      expect(find.text('Donemos sangre'), findsNothing, reason: 'pending is private');
      expect(find.text('A\u00fan no hay iniciativas publicadas'), findsOneWidget);

      // Admin approves -> it becomes public on refresh.
      wire.verify(id);
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Todas'));
      expect(find.text('Donemos sangre'), findsOneWidget);
    });

    testWidgets('double tap sends once', (tester) async {
      final wire = _Wire();
      wire.gates['POST /solidarity/campaigns'] = Completer<void>();
      await _pump(tester, wire, initial: '/solidaria/nueva');
      await _fill(tester);
      await tester.ensureVisible(_submitButton);
      await tester.pumpAndSettle();
      await tester.tap(_submitButton);
      await tester.pump();
      await tester.tap(_submitButton, warnIfMissed: false);
      await tester.pump();
      wire.gates['POST /solidarity/campaigns']!.complete();
      await _settle(tester);
      expect(
        wire.writes.where((w) => w == 'POST /solidarity/campaigns').length,
        1,
      );
    });

    testWidgets('submit failure keeps data; retry reuses the draft (no duplicate)', (
      tester,
    ) async {
      final wire = _Wire()..submitFailures = 1;
      await _pump(tester, wire, initial: '/solidaria/nueva');
      await _fill(tester);
      await _tap(tester, _submitButton);
      expect(find.byKey(const ValueKey('solidarity_form_error')), findsOneWidget);
      expect(find.textContaining('Tus datos siguen aqu\u00ed'), findsOneWidget);
      expect(find.text('Donemos sangre'), findsOneWidget);

      await _tap(tester, _submitButton);
      final id = wire.campaigns.keys.single;
      expect(wire.writes, [
        'POST /solidarity/campaigns',
        'POST /solidarity/campaigns/$id/submit',
        'PUT /solidarity/campaigns/$id',
        'POST /solidarity/campaigns/$id/submit',
      ]);
      expect(wire.campaigns[id]!['submittedAt'], isNotNull);
      // Opened directly: success lands on "Mis iniciativas" showing the state.
      await _settle(tester);
      expect(find.widgetWithText(AppBar, 'Mis iniciativas'), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_state_inReview')), findsOneWidget);
    });

    testWidgets('failed photo upload never creates the campaign', (tester) async {
      final wire = _Wire();
      final media = _Media(fail: true);
      await _pump(tester, wire, initial: '/solidaria/nueva', media: media);
      await _fill(tester);
      await _tap(tester, find.byKey(const ValueKey('single_photo_add')));
      await _tap(tester, _submitButton);
      expect(wire.writes, isEmpty);
      expect(find.textContaining('No pudimos subir la foto'), findsOneWidget);
    });
  });

  group('DH04 owner state and moderation', () {
    testWidgets('Mis iniciativas shows every state and the rejection reason', (
      tester,
    ) async {
      final wire = _Wire()
        ..campaigns[_a] = _campaign(_a, title: 'Publicada')
        ..campaigns[_b] = _campaign(
          _b,
          title: 'Esperando',
          status: 'DRAFT',
          verification: 'PENDING',
        )
        ..campaigns[_c] = _campaign(
          _c,
          title: 'Corregir',
          status: 'DRAFT',
          verification: 'REJECTED',
          submittedAt: null,
          reason: 'Agrega una fecha l\u00edmite',
        )
        ..campaigns[_d] = _campaign(
          _d,
          title: 'Sin enviar',
          status: 'DRAFT',
          verification: 'PENDING',
          submittedAt: null,
        );
      await _pump(tester, wire, initial: '/solidaria');
      await _tap(tester, find.byKey(const ValueKey('solidaria_mine_link')));
      expect(find.widgetWithText(AppBar, 'Mis iniciativas'), findsOneWidget);
      expect(find.text('Publicada'), findsWidgets);
      expect(find.byKey(const ValueKey('solidarity_state_published')), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_state_inReview')), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_state_rejected')), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_state_draft')), findsOneWidget);
      expect(find.text('Motivo: Agrega una fecha l\u00edmite'), findsOneWidget);

      // owner -> pending detail: state, no contact, no edit; back.
      await _tap(tester, find.text('Esperando'));
      expect(find.byKey(const ValueKey('solidarity_state_inReview')), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_owner_panel')), findsOneWidget);
      expect(find.text('Contactar por WhatsApp'), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Corregir y reenviar'), findsNothing);
      await _back(tester);
      expect(find.widgetWithText(AppBar, 'Mis iniciativas'), findsOneWidget);
    });

    testWidgets('rejected -> correct -> resubmit -> en revisi\u00f3n', (tester) async {
      final wire = _Wire()
        ..campaigns[_c] = _campaign(
          _c,
          title: 'Corregir',
          status: 'DRAFT',
          verification: 'REJECTED',
          submittedAt: null,
          reason: 'Agrega una fecha l\u00edmite',
        );
      await _pump(tester, wire, initial: '/solidaria/mias');
      await _tap(tester, find.text('Corregir'));
      expect(find.text('No aprobada'), findsOneWidget);
      expect(
        find.text('Motivo de Garra: Agrega una fecha l\u00edmite'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Corregir y reenviar'));
      expect(find.text('Corregir iniciativa'), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_edit_rejection_reason')), findsOneWidget);
      expect(find.text('Corregir'), findsOneWidget, reason: 'prefilled title');
      await tester.enterText(
        find.byKey(const ValueKey('solidarity_title')),
        'Corregida hasta el s\u00e1bado',
      );
      await _tap(tester, find.text('Reenviar a revisi\u00f3n'));
      expect(wire.writes, [
        'PUT /solidarity/campaigns/$_c',
        'POST /solidarity/campaigns/$_c/submit',
      ]);
      // Back on the detail, reloaded: in review, no more edit.
      expect(find.byKey(const ValueKey('solidarity_state_inReview')), findsOneWidget);
      expect(find.text('Corregida hasta el s\u00e1bado'), findsOneWidget);
      expect(find.text('Corregir y reenviar'), findsNothing);
      await _back(tester);
      expect(find.widgetWithText(AppBar, 'Mis iniciativas'), findsOneWidget);
      expect(find.byKey(const ValueKey('solidarity_state_inReview')), findsOneWidget);
    });

    testWidgets('unsent draft can be sent from its detail', (tester) async {
      final wire = _Wire()
        ..campaigns[_d] = _campaign(
          _d,
          title: 'Sin enviar',
          status: 'DRAFT',
          verification: 'PENDING',
          submittedAt: null,
        );
      final router = await _pump(tester, wire, initial: '/solidaria');
      router.push('/solidaria/$_d');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('solidarity_state_draft')), findsOneWidget);
      await _tap(tester, find.text('Enviar a revisi\u00f3n'));
      expect(wire.writes, ['POST /solidarity/campaigns/$_d/submit']);
      expect(find.byKey(const ValueKey('solidarity_state_inReview')), findsOneWidget);
    });

    testWidgets('approved campaign cannot be edited from a deep link', (
      tester,
    ) async {
      final wire = _Wire()..campaigns[_a] = _campaign(_a);
      await _pump(tester, wire, initial: '/solidaria/$_a/editar');
      expect(find.text('Esta iniciativa ya no se puede editar'), findsOneWidget);
      expect(wire.writes, isEmpty);
    });

    testWidgets('mine: empty and error + retry', (tester) async {
      final wire = _Wire()..mineFailures = 1;
      await _pump(tester, wire, initial: '/solidaria/mias');
      expect(find.text('No pudimos cargar tus iniciativas'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await _tap(tester, find.text('Reintentar'));
      expect(find.text('A\u00fan no propusiste iniciativas'), findsOneWidget);
      expect(find.text('Proponer iniciativa'), findsOneWidget);
    });
  });

  group('DH04 360px', () {
    testWidgets('Solidaria screens fit 360px at 1.3 text scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const narrow = Size(360, 740);
      final wire = _Wire()
        ..campaigns[_a] = _campaign(
          _a,
          title: 'Colecta de v\u00edveres para familias de la barra de Ate 2026',
          image: 'https://cdn.garra/a.jpg',
        )
        ..campaigns[_c] = _campaign(
          _c,
          title: 'Iniciativa corregible con t\u00edtulo largo para pantalla chica',
          status: 'DRAFT',
          verification: 'REJECTED',
          submittedAt: null,
          reason: 'Agrega una fecha l\u00edmite y un punto de entrega claro.',
        );

      await _pump(tester, wire, initial: '/solidaria', size: narrow);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byKey(const ValueKey('solidaria_how_it_works_link')));
      await tester.scrollUntilVisible(
        find.text('Entendido'),
        120,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('solidaria_how_it_works')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(tester.takeException(), isNull);

      await _pump(tester, _Wire(), initial: '/solidaria', size: narrow);
      expect(tester.takeException(), isNull);
      await _pump(tester, wire, initial: '/solidaria/$_a', size: narrow);
      await tester.scrollUntilVisible(
        find.text('Llamar'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await _pump(tester, wire, initial: '/solidaria/$_c', size: narrow);
      expect(tester.takeException(), isNull);
      await _pump(tester, wire, initial: '/solidaria/mias', size: narrow);
      expect(tester.takeException(), isNull);
      await _pump(tester, wire, initial: '/solidaria/$_c/editar', size: narrow);
      await tester.scrollUntilVisible(
        find.text('Reenviar a revisi\u00f3n'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await _pump(tester, wire, initial: '/solidaria/nueva', size: narrow);
      await tester.scrollUntilVisible(
        find.text('Enviar a revisi\u00f3n'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Enviar a revisi\u00f3n'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
