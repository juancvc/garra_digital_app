import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/home/data/home_matchday_poll_service.dart';
import 'package:garra_digital_app/features/home/presentation/home_matchday_poll_card.dart';

const first = HomeMatchdayPollOption(
    id: 'a', label: 'Iré al estadio', voteCount: 0, percentage: 0);
const second = HomeMatchdayPollOption(
    id: 'b', label: 'Lo veré en casa', voteCount: 0, percentage: 0);
const third = HomeMatchdayPollOption(
    id: 'c', label: 'Con mis causas', voteCount: 0, percentage: 0);
const fourth = HomeMatchdayPollOption(
    id: 'd', label: 'Desde donde esté', voteCount: 0, percentage: 0);

HomeMatchdayPoll poll({String status = 'OPEN', String? selected,
    int total = 0, List<HomeMatchdayPollOption>? options}) =>
    HomeMatchdayPoll(id: 'poll-1', question: '¿Dónde alentarás a la U?',
        status: status, totalVotes: total, selectedOptionId: selected,
        options: options ?? const [first, second, third, fourth]);

class FakePollService extends HomeMatchdayPollService {
  FakePollService(this.current) : super(dio: Dio());
  HomeMatchdayPoll? current;
  bool failGet = false;
  int gets = 0;
  int votes = 0;
  int? lastFixtureId;

  @override
  Future<HomeMatchdayPoll?> get(int fixtureId, String competition) async {
    gets++;
    lastFixtureId = fixtureId;
    if (failGet) throw DioException(requestOptions: RequestOptions(path: 'test'));
    return current;
  }

  @override
  Future<HomeMatchdayPoll> vote(int fixtureId, String competition, String optionId) async {
    votes++;
    current = poll(selected: optionId, total: 1, options: [
      HomeMatchdayPollOption(id: 'a', label: first.label,
          voteCount: optionId == 'a' ? 1 : 0, percentage: optionId == 'a' ? 100 : 0),
      HomeMatchdayPollOption(id: 'b', label: second.label,
          voteCount: optionId == 'b' ? 1 : 0, percentage: optionId == 'b' ? 100 : 0),
      third, fourth,
    ]);
    return current!;
  }
}

final featured = AsyncValue.data(FootballFeaturedResult(
  featured: FootballFeatured(next: FootballMatch(
    id: 123, competitionId: 'LIGA_1', competition: 'Liga 1',
    home: 'Universitario', away: 'Melgar', status: 'SCHEDULED',
  )),
));

Future<void> show(WidgetTester tester, FakePollService service,
    {double width = 390}) async {
  await tester.binding.setSurfaceSize(Size(width, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [homeMatchdayPollServiceProvider.overrideWithValue(service)],
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: Column(children: [
        HomeMatchdayPollCard(featured: featured),
        const Text('Feed social'),
      ]),
    ))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('model handles real zero-vote percentages and selected option', () {
    final parsed = HomeMatchdayPoll.fromJson({
      'id': 'poll-1', 'question': '¿Dónde alentarás a la U?',
      'status': 'OPEN', 'totalVotes': 0, 'selectedOptionId': null,
      'options': [
        {'id': 'a', 'label': 'Iré al estadio', 'voteCount': 0, 'percentage': 0},
      ],
    });
    expect(parsed.totalVotes, 0);
    expect(parsed.options.single.percentage, 0);
    expect(parsed.selectedOptionId, isNull);
  });

  test('service hides poll when backend endpoint is not deployed yet', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 404),
      ));
    }));
    final service = HomeMatchdayPollService(dio: dio);
    expect(await service.get(123, 'LIGA_1'), isNull);
  });

  testWidgets('poll requests featured next even when live is another fixture', (tester) async {
    final service = FakePollService(poll());
    final featured = AsyncValue.data(FootballFeaturedResult(
      featured: FootballFeatured(
        live: FootballMatch(
          id: 100, competitionId: 'LIGA_1', competition: 'Liga 1',
          home: 'Universitario', away: 'Cienciano', status: 'FIRST_HALF',
        ),
        next: FootballMatch(
          id: 123, competitionId: 'LIGA_1', competition: 'Liga 1',
          home: 'Universitario', away: 'Melgar', status: 'SCHEDULED',
        ),
      ),
    ));
    await tester.pumpWidget(ProviderScope(
      overrides: [homeMatchdayPollServiceProvider.overrideWithValue(service)],
      child: MaterialApp(home: Scaffold(body: HomeMatchdayPollCard(featured: featured))),
    ));
    await tester.pumpAndSettle();
    expect(service.lastFixtureId, 123);
  });

  testWidgets('visible poll votes and changes with one GET', (tester) async {
    final service = FakePollService(poll());
    await show(tester, service);
    expect(find.text('¿Dónde alentarás a la U?'), findsOneWidget);
    expect(find.text('0 hinchas'), findsOneWidget);
    await tester.tap(find.text('Iré al estadio'));
    await tester.pumpAndSettle();
    expect(service.votes, 1);
    expect(find.textContaining('100 %'), findsOneWidget);
    await tester.tap(find.text('Cambiar voto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lo veré en casa'));
    await tester.pumpAndSettle();
    expect(service.votes, 2);
    expect(service.gets, 1);
    expect(find.text('1 hincha'), findsOneWidget);
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    expect(service.gets, 2);
  });

  testWidgets('closed poll shows results and no vote action', (tester) async {
    final service = FakePollService(poll(status: 'CLOSED'));
    await show(tester, service);
    expect(find.text('Votación cerrada'), findsOneWidget);
    expect(find.textContaining('0 %'), findsNWidgets(4));
    expect(find.text('Cambiar voto'), findsNothing);
    expect(find.text('Feed social'), findsOneWidget);
  });

  testWidgets('error and absent endpoint leave feed usable', (tester) async {
    final service = FakePollService(null)..failGet = true;
    await show(tester, service);
    expect(find.text('No se pudo cargar la encuesta.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Feed social'), findsOneWidget);
  });

  testWidgets('narrow display with scaled text does not overflow', (tester) async {
    final service = FakePollService(poll());
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [homeMatchdayPollServiceProvider.overrideWithValue(service)],
      child: MaterialApp(home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: Scaffold(body: SingleChildScrollView(
          child: HomeMatchdayPollCard(featured: featured),
        )),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('¿Dónde alentarás a la U?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
