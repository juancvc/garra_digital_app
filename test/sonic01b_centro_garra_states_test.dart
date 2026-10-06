import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/football/data/football_diagnostics.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/data/garra_football_service.dart';
import 'package:garra_digital_app/features/football/presentation/centro_garra_page.dart';

/// SONIC_01B: Centro Garra separates "nothing to show" from "service down",
/// names the failing layer in diagnostics and never shows backend codes.

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Object Function(RequestOptions options) respond = (_) => {'data': {}};
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(respond(options)), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
}

class _Network extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

class _Football extends GarraFootballService {
  _Football() : super(dio: Dio());
  FootballPage<FootballMatch> Function(FootballView view) page =
      (_) => const FootballPage(items: [], stale: false, unavailable: false, partial: false);
  FootballPage<Map<String, dynamic>> table =
      const FootballPage(items: [], stale: false, unavailable: false, partial: false);
  Object? error;
  int calls = 0;

  @override
  Future<List<FootballCompetition>> competitions() async => const [
    FootballCompetition(id: 'LIGA_1', name: 'Liga 1 Perú', available: true, region: 'PERU'),
  ];

  @override
  Future<FootballFeatured?> featured() async => null;

  @override
  Future<FootballPage<FootballMatch>> matches(FootballView view, {String? competition}) async {
    calls++;
    if (error != null) throw error!;
    return page(view);
  }

  @override
  Future<FootballPage<Map<String, dynamic>>> standings(String competition) async {
    calls++;
    if (error != null) throw error!;
    return table;
  }
}

Future<void> _pump(WidgetTester tester, _Football service) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    garraFootballServiceProvider.overrideWithValue(service),
    connectivityStatusProvider.overrideWith(_Network.new),
  ], child: const MaterialApp(home: CentroGarraPage())));
  await _settle(tester);
}

/// SONIC_04: Navigation V4 text tabs (no chips); pumpAndSettle avoided (skeleton animates).
Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

const _sectionKeys = {'Hoy': 'today', 'En vivo': 'live', 'Próximos': 'upcoming',
  'Resultados': 'results', 'Tabla': 'standings'};

Future<void> _open(WidgetTester tester, String section) async {
  await tester.tap(find.byKey(ValueKey('section_${_sectionKeys[section]}')));
  await _settle(tester);
}

void _expectNoCodes(WidgetTester tester) {
  final text = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ');
  for (final code in ['UNKNOWN_PROVIDER_ERROR', 'PROVIDER_COOLDOWN', 'BUDGET', 'CACHE', 'PROVIDER',
    'DioException', 'receiveTimeout']) {
    expect(text.contains(code), isFalse, reason: code);
  }
}

DioException _dio(DioExceptionType type, {int? status}) => DioException(
  requestOptions: RequestOptions(path: '/football/matches'), type: type,
  response: status == null ? null
      : Response(requestOptions: RequestOptions(path: '/football/matches'), statusCode: status));

void main() {
  test('repository sends the Lima day and parses the backend reason', () async {
    final adapter = _Adapter()
      ..respond = (o) => o.path.contains('standings')
          ? {'data': {'items': [], 'stale': false, 'unavailable': false, 'partial': false}}
          : {'data': {'items': [], 'stale': false, 'unavailable': true, 'partial': false,
              'reason': 'PROVIDER_COOLDOWN'}};
    final service = GarraFootballService(dio: Dio()..httpClientAdapter = adapter);
    final page = await service.matches(FootballView.today, competition: 'LIGA_1');
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/football/matches');
    expect(request.queryParameters['view'], 'TODAY');
    expect(request.queryParameters['offsetMinutes'], -300);
    expect(request.queryParameters['competition'], 'LIGA_1');
    expect(request.queryParameters['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(page.unavailable, isTrue);
    expect(page.reason, 'PROVIDER_COOLDOWN');
    final table = await service.standings('LIGA_1');
    expect(adapter.requests.last.path, '/football/competitions/LIGA_1/standings');
    expect(table.unavailable, isFalse);
    expect(table.reason, isNull);
  });

  test('failure layer separates network, auth, backend and contract', () {
    expect(footballFailureLayer(_dio(DioExceptionType.receiveTimeout)), FootballFailureLayer.appNetwork);
    expect(footballFailureLayer(_dio(DioExceptionType.connectionError)), FootballFailureLayer.appNetwork);
    expect(footballFailureLayer(_dio(DioExceptionType.badResponse, status: 401)), FootballFailureLayer.auth);
    expect(footballFailureLayer(_dio(DioExceptionType.badResponse, status: 503)), FootballFailureLayer.backend);
    expect(footballFailureLayer(_dio(DioExceptionType.badResponse, status: 400)), FootballFailureLayer.backendContract);
    expect(footballFailureLayer(const FormatException('x')), FootballFailureLayer.backendContract);
    expect(FootballFailureLayer.appNetwork.code, 'APP_NETWORK');
  });

  testWidgets('valid empty sections have their own copy and no outage or retry', (tester) async {
    final service = _Football();
    await _pump(tester, service);
    expect(find.text('Sin partidos hoy'), findsOneWidget);
    expect(find.text('Fútbol temporalmente no disponible'), findsNothing);
    expect(find.text('Reintentar'), findsNothing);
    await _open(tester, 'En vivo');
    expect(find.text('Ningún partido en vivo ahora'), findsOneWidget);
    await _open(tester, 'Próximos');
    expect(find.text('Sin partidos próximos'), findsOneWidget);
    await _open(tester, 'Resultados');
    expect(find.text('Sin resultados recientes'), findsOneWidget);
    await _open(tester, 'Tabla');
    expect(find.text('Tabla aún no disponible'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    _expectNoCodes(tester);
  });

  testWidgets('real outage is friendly, retryable and hides backend reason codes', (tester) async {
    final service = _Football()
      ..page = ((_) => const FootballPage(items: [], stale: false, unavailable: true, partial: false,
          reason: 'PROVIDER'))
      ..table = const FootballPage(items: [], stale: false, unavailable: true, partial: false,
          reason: 'BUDGET');
    await _pump(tester, service);
    expect(find.text('Fútbol temporalmente no disponible'), findsOneWidget);
    expect(find.text('Sin partidos hoy'), findsNothing);
    final before = service.calls;
    await tester.tap(find.text('Reintentar'));
    await _settle(tester);
    expect(service.calls, before + 1);
    await _open(tester, 'Tabla');
    expect(find.text('Tabla temporalmente no disponible'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    _expectNoCodes(tester);
  });

  testWidgets('partial empty day stays an empty day with a soft note', (tester) async {
    final service = _Football()
      ..page = ((_) => const FootballPage(items: [], stale: false, unavailable: false, partial: true,
          reason: 'PROVIDER'));
    await _pump(tester, service);
    expect(find.text('Sin partidos hoy'), findsOneWidget);
    expect(find.text('Algunas competiciones no están disponibles'), findsOneWidget);
    expect(find.text('Fútbol temporalmente no disponible'), findsNothing);
    _expectNoCodes(tester);
  });

  testWidgets('network timeout and server error are told apart without raw errors', (tester) async {
    final service = _Football()..error = _dio(DioExceptionType.receiveTimeout);
    await _pump(tester, service);
    expect(find.text('No pudimos conectar con Garra'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    service.error = _dio(DioExceptionType.badResponse, status: 500);
    await tester.tap(find.text('Reintentar'));
    await _settle(tester);
    expect(find.text('No pudimos cargar el fútbol'), findsOneWidget);
    service.error = null;
    service.page = (_) => FootballPage(items: [FootballMatch(id: 7, competitionId: 'LIGA_1',
        competition: 'Liga 1 Perú', home: 'Universitario', away: 'Rival', status: 'SCHEDULED',
        kickoff: DateTime(2026, 10, 6, 20))], stale: false, unavailable: false, partial: false);
    await tester.tap(find.text('Reintentar'));
    await _settle(tester);
    expect(find.text('Universitario'), findsOneWidget);
    _expectNoCodes(tester);
  });
}
