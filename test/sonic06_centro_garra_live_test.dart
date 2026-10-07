import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/network/connectivity_status.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/data/wall_status_model.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/football/data/football_chat_service.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/football/data/garra_football_service.dart';
import 'package:garra_digital_app/features/football/presentation/centro_garra_page.dart';
import 'package:garra_digital_app/features/football/presentation/chat_futbolero_page.dart';
import 'package:garra_digital_app/features/football/presentation/football_team_center.dart';
import 'package:go_router/go_router.dart';

/// SONIC_06 — live football chat rooms, Momentos clave, Team Center V2 and navigation retention.
/// Synthetic data only (generic clubs and ids), no provider, no network.

class _Net extends ConnectivityStatusController {
  @override
  NetworkConnectivity build() => NetworkConnectivity.online;
}

class _Community extends CommunityService {
  _Community() : super(dio: Dio());
  @override
  Future<WallStatusModel?> getCurrentWallStatus() async => null;
  @override
  Future<List<WallPostModel>> getPosts({required String matchId, String? locationTag}) async => const [];
}

DioException _http(int status) {
  final options = RequestOptions(path: '/football/chat/messages');
  return DioException(requestOptions: options, type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: status));
}

FootballChatMessage _msg(String id, String body, int minute, {String author = 'Hincha Uno'}) => FootballChatMessage(
    id: id, authorId: 'a-$id', authorName: author, authorUsername: 'u$id', body: body,
    createdAt: DateTime.utc(2026, 10, 6, 20, minute));

class _Chat extends FootballChatService {
  _Chat() : super(dio: Dio());
  final List<String> calls = [];
  final List<String> sends = [];
  int failPages = 0;
  bool failSend = false;
  Completer<FootballChatMessage>? sendGate;
  FootballChatPage Function(FootballChatContext context)? pages;

  @override
  Future<FootballChatPage> page(FootballChatContext context, {DateTime? before, int size = 30}) async {
    calls.add(context.key);
    if (failPages > 0) {
      failPages--;
      throw _http(500);
    }
    return pages?.call(context) ?? const FootballChatPage(items: [], hasMore: false);
  }

  @override
  Future<FootballChatMessage> send(String body,
      {FootballChatContext context = const FootballChatContext.general()}) async {
    sends.add('${context.key}:$body');
    if (sendGate != null) return sendGate!.future;
    if (failSend) throw _http(503);
    return FootballChatMessage(id: 'srv-${sends.length}', authorId: 'me', authorName: 'Yo Hincha',
        authorUsername: 'yo', body: body, createdAt: DateTime.utc(2026, 10, 6, 21, 0),
        contextType: context.isMatch ? 'MATCH' : 'GENERAL', contextId: context.matchId?.toString());
  }
}

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _pumpChat(WidgetTester tester, _Chat chat, {int? matchId, FootballMatch? match, String? topic,
    Size size = const Size(360, 800)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(overrides: [
    footballChatServiceProvider.overrideWithValue(chat),
    connectivityStatusProvider.overrideWith(_Net.new),
  ], child: MaterialApp(home: ChatFutboleroPage(matchId: matchId, match: match, topic: topic))));
  await _settle(tester);
}

/// Disposes the page (cancels its poller) so no timer outlives the test.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

FootballMatch _m(int id, {String comp = 'LIGA_1', String status = 'SCHEDULED', String home = 'Local FC',
    String away = 'Visita FC', int? homeId, int? awayId, int? hs, int? as, DateTime? kickoff, int round = 11,
    bool? confirmed, int? elapsed}) => FootballMatch(
  id: id, competitionId: comp, competition: comp == 'LIGA_1' ? 'Liga 1 Perú' : 'Liga 2 Perú',
  home: home, away: away, status: status, kickoff: kickoff ?? DateTime(2030, 10, 18, 15, 30),
  homeScore: hs, awayScore: as, round: 'Regular Season - $round', homeId: homeId, awayId: awayId,
  kickoffConfirmed: confirmed, elapsed: elapsed);

void main() {
  // ---------------------------------------------------------------- chat
  group('Chat Futbolero V2', () {
    testWidgets('GENERAL: initial success shows avatar, name, Lima time, text and the arenga hint', (tester) async {
      final chat = _Chat()..pages = (_) => FootballChatPage(items: [_msg('1', 'Vamos todos', 10)], hasMore: false);
      await _pumpChat(tester, chat);
      expect(chat.calls, ['GENERAL']);
      expect(find.text('Chat Futbolero'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_back_general')), findsNothing);
      expect(find.text('Vamos todos'), findsOneWidget);
      expect(find.text('Hincha Uno'), findsOneWidget);
      expect(find.text('15:10'), findsOneWidget); // 20:10 UTC in Lima
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('Escribe tu arenga...'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('initial failure keeps error + Reintentar, composer disabled with a reason, no poller', (tester) async {
      final chat = _Chat()
        ..failPages = 1
        ..pages = (_) => FootballChatPage(items: [_msg('1', 'Ya cargó', 10)], hasMore: false);
      await _pumpChat(tester, chat);
      expect(find.text('No pudimos cargar el chat'), findsOneWidget);
      expect(find.text('El chat no respondió. Inténtalo en unos segundos.'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_retry')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_composer_disabled')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('chat_input'))).enabled, isFalse);
      await tester.pump(const Duration(seconds: 30));
      expect(chat.calls.length, 1, reason: 'a room that never loaded is not polled');
      await tester.tap(find.byKey(const ValueKey('chat_retry')));
      await _settle(tester);
      expect(find.text('Ya cargó'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_composer_disabled')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('chat_input'))).enabled, isTrue);
      await _close(tester);
    });

    testWidgets('a valid empty room is not a failure: GENERAL and MATCH copies', (tester) async {
      await _pumpChat(tester, _Chat());
      expect(find.text('Empieza la conversación crema'), findsOneWidget);
      expect(find.text('No pudimos cargar el chat'), findsNothing);
      await _close(tester);
      await _pumpChat(tester, _Chat(), matchId: 9);
      expect(find.text('Abre la previa con la hinchada'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('MATCH header from data, back to the general chat, rooms never mixed', (tester) async {
      final chat = _Chat()..pages = (c) => c.isMatch
          ? FootballChatPage(items: [_msg('m1', 'Solo del partido', 12)], hasMore: false, contextType: 'MATCH',
              contextId: '9', match: _m(9, status: 'SECOND_HALF', hs: 1, as: 0, elapsed: 60))
          : FootballChatPage(items: [_msg('g1', 'Solo general', 11)], hasMore: false);
      await _pumpChat(tester, chat, matchId: 9, topic: 'Texto viejo');
      expect(find.text('Local FC vs Visita FC'), findsOneWidget);
      expect(find.text('Liga 1 Perú · Fecha 11'), findsOneWidget);
      expect(find.text('Solo del partido'), findsOneWidget);
      expect(find.text('Solo general'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('chat_back_general')));
      await _settle(tester);
      expect(chat.calls, ['MATCH:9', 'GENERAL']);
      expect(find.text('Chat Futbolero'), findsOneWidget);
      expect(find.text('Solo general'), findsOneWidget);
      expect(find.text('Solo del partido'), findsNothing);
      await _close(tester);
    });

    testWidgets('system goal and red card cards interleave with messages by minute', (tester) async {
      final chat = _Chat()..pages = (_) => FootballChatPage(
          items: [_msg('a', 'Previa caliente', 10), _msg('b', 'Golazo!', 30)], hasMore: false,
          contextType: 'MATCH', contextId: '9', match: _m(9, status: 'SECOND_HALF'),
          events: [
            FootballChatEvent(key: 'GOAL:23', kind: 'GOAL', minute: 23, player: 'A. Valera', team: 'Local FC',
                side: 'HOME', approxAt: DateTime.utc(2026, 10, 6, 20, 23)),
            FootballChatEvent(key: 'RED:58', kind: 'RED_CARD', minute: 58, player: 'J. Pérez', team: 'Visita FC',
                side: 'AWAY', approxAt: DateTime.utc(2026, 10, 6, 21, 13)),
          ]);
      await _pumpChat(tester, chat, matchId: 9, size: const Size(360, 1000));
      final goal = find.text('⚽ Gol 23′ · A. Valera · Local FC');
      final red = find.text('🟥 Roja 58′ · J. Pérez · Visita FC');
      expect(goal, findsOneWidget);
      expect(red, findsOneWidget);
      double y(Finder f) => tester.getTopLeft(f).dy;
      expect(y(find.text('Previa caliente')), lessThan(y(goal)));
      expect(y(goal), lessThan(y(find.text('Golazo!'))));
      expect(y(find.text('Golazo!')), lessThan(y(red)));
      expect(tester.getTopLeft(red).dx, greaterThan(tester.getTopLeft(goal).dx), reason: 'away on the right');
      await _close(tester);
    });

    testWidgets('send failure marks only that message for retry; the chat stays', (tester) async {
      final chat = _Chat()
        ..failSend = true
        ..pages = (_) => FootballChatPage(items: [_msg('1', 'Mensaje viejo', 10)], hasMore: false);
      await _pumpChat(tester, chat);
      await tester.enterText(find.byKey(const ValueKey('chat_input')), 'Vamos crema');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await _settle(tester);
      expect(find.text('No se envió · Reintentar'), findsOneWidget);
      expect(find.text('Mensaje viejo'), findsOneWidget);
      expect(find.text('Vamos crema'), findsOneWidget);
      chat.failSend = false;
      await tester.tap(find.byKey(const ValueKey('chat_retry_local-0')));
      await _settle(tester);
      expect(find.text('No se envió · Reintentar'), findsNothing);
      expect(find.byKey(const ValueKey('chat_msg_srv-2')), findsOneWidget);
      expect(find.text('Vamos crema'), findsOneWidget);
      expect(chat.sends, ['GENERAL:Vamos crema', 'GENERAL:Vamos crema']);
      await _close(tester);
    });

    testWidgets('double submit is prevented while a send is in flight', (tester) async {
      final chat = _Chat()..sendGate = Completer<FootballChatMessage>();
      await _pumpChat(tester, chat, matchId: 9);
      await tester.enterText(find.byKey(const ValueKey('chat_input')), 'Uno');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await tester.enterText(find.byKey(const ValueKey('chat_input')), 'Dos');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(chat.sends, ['MATCH:9:Uno']);
      chat.sendGate!.complete(FootballChatMessage(id: 'srv-x', authorId: 'me', authorName: 'Yo', authorUsername: 'yo',
          body: 'Uno', createdAt: DateTime.utc(2026, 10, 6, 21), contextType: 'MATCH', contextId: '9'));
      await _settle(tester);
      expect(find.byKey(const ValueKey('chat_msg_srv-x')), findsOneWidget);
      expect(find.text('Enviando…'), findsNothing);
      await _close(tester);
    });

    testWidgets('one poller: ~12 s, switching room cancels it, background stops it, leaving ends it', (tester) async {
      final chat = _Chat();
      await _pumpChat(tester, chat, matchId: 9);
      expect(chat.calls, ['MATCH:9']);
      await tester.pump(const Duration(seconds: 12));
      expect(chat.calls, ['MATCH:9', 'MATCH:9']);
      await tester.tap(find.byKey(const ValueKey('chat_back_general')));
      await _settle(tester);
      chat.calls.clear();
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(seconds: 12));
      expect(chat.calls, ['GENERAL', 'GENERAL'], reason: 'never MATCH and GENERAL at the same time');
      chat.calls.clear();
      for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(seconds: 40));
      expect(chat.calls, isEmpty, reason: 'no work in background');
      for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(chat.calls, ['GENERAL']);
      await tester.pump(const Duration(seconds: 12));
      expect(chat.calls, ['GENERAL', 'GENERAL']);
      await tester.pumpWidget(const SizedBox());
      chat.calls.clear();
      await tester.pump(const Duration(seconds: 40));
      expect(chat.calls, isEmpty);
    });

    test('service contract: context wire, page envelope with match, events and stale flag', () {
      expect(const FootballChatContext.general().wire, isNull);
      expect(const FootballChatContext.match(77).wire, 'MATCH:77');
      expect(FootballChatContext.tryMatch(0), isNull);
      final e = FootballChatEvent.fromJson({'key': 'k', 'kind': 'SECOND_YELLOW', 'minute': 90, 'extra': 7,
        'player': 'P', 'side': 'HOME', 'approxAt': '2026-10-06T21:52:00Z'});
      expect(e.extra, 7);
      expect(e.approxAt, DateTime.utc(2026, 10, 6, 21, 52));
      final legacy = FootballChatMessage.fromJson({'id': '1', 'body': 'x', 'createdAt': '2026-10-06T20:00:00Z'});
      expect(legacy.contextType, 'GENERAL');
    });

    testWidgets('no overflow at 360 px with long names in a MATCH room', (tester) async {
      final chat = _Chat()..pages = (_) => FootballChatPage(items: [
            _msg('1', 'Texto ' * 40, 10, author: 'Nombre Larguísimo De Hincha Con Apellidos Compuestos')],
          hasMore: false, match: _m(9, home: 'Club Deportivo Con Nombre Muy Largo', away: 'Otro Club Con Nombre Larguísimo'),
          events: [FootballChatEvent(key: 'g', kind: 'VAR_GOAL_CANCELLED', minute: 90, extra: 7,
              player: 'Jugador Con Nombre Extremadamente Largo', team: 'Otro Club Con Nombre Larguísimo', side: 'AWAY')]);
      await _pumpChat(tester, chat, matchId: 9, size: const Size(360, 700));
      expect(tester.takeException(), isNull);
      await _close(tester);
    });
  });

  // ---------------------------------------------------------------- moments
  group('Momentos clave', () {
    final events = <Map<String, dynamic>>[
      {'elapsed': 10, 'type': 'GOAL', 'player': 'A. Valera', 'team': 'Local FC', 'detail': 'Normal Goal'},
      {'elapsed': 10, 'type': 'GOAL', 'player': 'A. Valera', 'team': 'Local FC', 'detail': 'Normal Goal'},
      {'elapsed': 20, 'type': 'YELLOW_CARD', 'player': 'Amarilla', 'team': 'Visita FC', 'detail': 'Yellow Card'},
      {'elapsed': 45, 'extra': 2, 'type': 'GOAL', 'player': 'F. Polo', 'team': 'Local FC', 'detail': 'Penalty'},
      {'elapsed': 50, 'type': 'GOAL', 'player': 'Fallo', 'team': 'Local FC', 'detail': 'Missed Penalty'},
      {'elapsed': 58, 'type': 'RED_CARD', 'player': 'J. Pérez', 'team': 'Visita FC', 'detail': 'Red Card'},
      {'elapsed': 70, 'type': 'YELLOW_CARD', 'player': 'Doble', 'team': 'Local FC', 'detail': 'Second Yellow card'},
      {'elapsed': 90, 'extra': 7, 'type': 'GOAL', 'player': 'B. Soto', 'team': 'Local FC', 'detail': 'Normal Goal'},
      {'elapsed': 90, 'extra': 7, 'type': 'RED_CARD', 'player': 'C. Rojas', 'team': 'Visita FC', 'detail': 'Red Card'},
      {'elapsed': 60, 'type': 'SUBSTITUTION', 'player': 'Entra', 'team': 'Local FC'},
    ];

    test('only decisive facts, minute order, exact duplicates dropped, same minute kept', () {
      final moments = footballKeyMoments(events, _m(1));
      expect(moments.map((m) => m.minuteLabel).toList(), ['10′', '45+2′', '58′', '70′', '90+7′', '90+7′']);
      expect(moments.map((m) => m.label).toList(),
          ['A. Valera', 'F. Polo (pen.)', 'J. Pérez', 'Doble (doble amarilla)', 'B. Soto', 'C. Rojas']);
      expect(moments[2].away, isTrue);
      expect(moments[0].away, isFalse);
    });

    test('score coherence never edits the score: missing goal, annulled goal, exact', () {
      FootballKeyMoment goal() => const FootballKeyMoment(kind: FootballEventKind.goal, minute: 5);
      const cancel = FootballKeyMoment(kind: FootballEventKind.videoReview, minute: 6, varDecision: 'GOAL_CANCELLED');
      expect(footballMomentsExplainScore(_m(1, hs: 2, as: 0), [goal()]), isFalse, reason: 'score ahead of events');
      expect(footballMomentsExplainScore(_m(1, hs: 1, as: 0), [goal(), goal(), cancel]), isTrue,
          reason: 'VAR annulled one of the known goals');
      expect(footballMomentsExplainScore(_m(1, hs: 1, as: 0), [goal(), goal()]), isFalse,
          reason: 'known goals ahead of the score without a VAR decision');
      expect(footballMomentsExplainScore(_m(1, hs: 1, as: 0), [goal()]), isTrue);
      expect(footballVarDecision('Card upgrade'), isNull);
    });

    test('detail contract: backend moments parse into the timeline shape', () {
      final detail = FootballDetail.fromEnvelope({'stale': false, 'item': {
        'match': {'id': 9, 'competitionId': 'LIGA_1', 'status': 'FINISHED', 'homeScore': 1, 'awayScore': 1,
          'home': {'name': 'Local FC'}, 'away': {'name': 'Visita FC'}},
        'events': [], 'lineups': [], 'statistics': [], 'partial': false,
        'moments': [
          {'kind': 'OWN_GOAL', 'minute': 33, 'player': 'E. Díaz', 'team': 'Visita FC', 'detail': 'Own Goal'},
          {'kind': 'SECOND_YELLOW', 'minute': 90, 'extra': 3, 'player': 'Z', 'team': 'Local FC'},
        ],
        'momentsStale': true, 'eventCount': 7}});
      expect(detail.eventCount, 7);
      expect(detail.momentsStale, isTrue);
      final moments = footballKeyMoments(detail.moments!, detail.match);
      expect(moments.map((m) => m.kind).toList(), [FootballEventKind.ownGoal, FootballEventKind.secondYellow]);
      expect(moments[1].minuteLabel, '90+3′');
      final none = FootballDetail.fromEnvelope({'item': {'match': {'id': 1}, 'partial': false}});
      expect(none.moments, isNull);
    });

    testWidgets('under the score: latest 3, "Ver todos los eventos (n)" opens Eventos; no extra request on open',
        (tester) async {
      final live = _m(9, status: 'SECOND_HALF', hs: 3, as: 1, elapsed: 92);
      final moments = [
        {'kind': 'GOAL', 'minute': 10, 'player': 'A. Valera', 'team': 'Local FC'},
        {'kind': 'PENALTY_GOAL', 'minute': 45, 'extra': 2, 'player': 'F. Polo', 'team': 'Local FC'},
        {'kind': 'RED_CARD', 'minute': 58, 'player': 'J. Pérez', 'team': 'Visita FC'},
        {'kind': 'GOAL', 'minute': 70, 'player': 'K. Mar', 'team': 'Visita FC'},
        {'kind': 'GOAL', 'minute': 90, 'extra': 7, 'player': 'B. Soto', 'team': 'Local FC'},
      ].map(footballMomentAsEvent).toList();
      final service = _Football()..onDetail = (match, section) => FootballDetail(match: live,
          events: section == 'EVENTS' ? events : const [], lineups: const [], statistics: const [],
          partial: false, stale: false, moments: moments, eventCount: 9);
      await _pumpDetail(tester, service, live);
      expect(service.calls, ['detail:BASE'], reason: 'opening the detail never requests the events section');
      expect(find.byKey(const ValueKey('key_moments')), findsOneWidget);
      expect(find.text('🟥 58′ J. Pérez'), findsOneWidget);
      expect(find.text('⚽ 70′ K. Mar'), findsOneWidget);
      expect(find.text('⚽ 90+7′ B. Soto'), findsOneWidget);
      expect(find.text('⚽ 10′ A. Valera'), findsNothing);
      expect(find.byKey(const ValueKey('events_updating')), findsNothing);
      expect(find.text('3'), findsOneWidget, reason: 'the score stays the fixture score');
      await tester.tap(find.byKey(const ValueKey('key_moments_all')));
      await _settle(tester, 14);
      expect(find.text('Ver todos los eventos (9)'), findsNothing);
      expect(service.calls, contains('detail:EVENTS'));
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabs.controller!.index, 1);
    });

    testWidgets('45+2 formatting and the discreet "Eventos actualizándose" when stale or behind the score',
        (tester) async {
      final played = _m(9, status: 'FINISHED', hs: 2, as: 0);
      final service = _Football()..onDetail = (match, section) => FootballDetail(match: played, events: const [],
          lineups: const [], statistics: const [], partial: false, stale: false,
          moments: [footballMomentAsEvent({'kind': 'PENALTY_GOAL', 'minute': 45, 'extra': 2, 'player': 'F. Polo',
            'team': 'Local FC'})], eventCount: 1);
      await _pumpDetail(tester, service, played);
      expect(find.text('⚽ 45+2′ F. Polo (pen.)'), findsOneWidget);
      expect(find.byKey(const ValueKey('events_updating')), findsOneWidget, reason: '2-0 with one known goal');
      expect(find.byKey(const ValueKey('key_moments_all')), findsNothing);
    });

    testWidgets('no events snapshot: no moments block and nothing invented', (tester) async {
      final played = _m(9, status: 'FINISHED', hs: 2, as: 0);
      await _pumpDetail(tester, _Football(), played);
      expect(find.byKey(const ValueKey('key_moments')), findsNothing);
      expect(find.byKey(const ValueKey('events_updating')), findsNothing);
    });

    testWidgets('"Hablar del partido" opens the MATCH room of that fixture', (tester) async {
      final visited = <String>[];
      await _pumpDetail(tester, _Football(), _m(321, status: 'SECOND_HALF', hs: 0, as: 0, elapsed: 50),
          visited: visited);
      await tester.tap(find.byKey(const ValueKey('talk_match_cta')));
      await _settle(tester, 12);
      expect(visited, ['321']);
    });
  });

  // ---------------------------------------------------------------- team center
  group('Team Center V2', () {
    const teamId = 911;
    FootballMatch mine(int id, {String status = 'SCHEDULED', required DateTime kickoff, bool home = true,
        bool? confirmed, int? hs, int? as}) => _m(id, status: status, kickoff: kickoff, round: id,
        home: home ? 'Club Generico' : 'Rival $id', away: home ? 'Rival $id' : 'Club Generico',
        homeId: home ? teamId : 100 + id, awayId: home ? 100 + id : teamId, confirmed: confirmed, hs: hs, as: as);
    final f11 = mine(11, status: 'POSTPONED', kickoff: DateTime(2026, 10, 1, 15), confirmed: false);
    final f12 = mine(12, kickoff: DateTime(2030, 10, 18, 15), home: false);
    final f13 = mine(13, kickoff: DateTime(2030, 10, 25, 15));
    final f14 = mine(14, kickoff: DateTime(2030, 11, 1, 15), confirmed: false);
    final f15 = mine(15, kickoff: DateTime(2030, 11, 8, 15), home: false);
    final f10 = mine(10, status: 'FINISHED', kickoff: DateTime(2020, 9, 27, 15), hs: 2, as: 0);
    final f9 = mine(9, status: 'FINISHED', kickoff: DateTime(2020, 9, 20, 15), home: false, hs: 1, as: 2);
    List<Map<String, dynamic>> table() => [
      for (var r = 1; r <= 10; r++)
        {'group': 'Clausura', 'rank': r, 'team': r == 6 ? 'Club Generico' : 'Equipo $r',
          'teamId': r == 6 ? teamId : 500 + r, 'points': 30 - r, 'played': 10, 'goalDifference': 6 - r},
    ];
    FootballTeamCenter center({bool split = true, bool withTable = true}) => FootballTeamCenter(
      teamId: teamId, name: 'Club Generico', competition: 'Liga 1 Perú', next: f11, last: f10,
      matches: [f9, f10, f11, f12, f13, f14, f15],
      upcoming: split ? [f11, f12, f13, f14, f15] : const [], results: split ? [f10, f9] : const [],
      standings: withTable ? FootballTeamStandings(rows: table(), competitionId: 'LIGA_1',
          competition: 'Liga 1 Perú', group: 'Clausura', rank: 6, total: 10) : null);

    Future<List<FootballMatch>> pumpSheet(WidgetTester tester, FootballTeamCenter c,
        {Size size = const Size(360, 1600)}) async {
      final opened = <FootballMatch>[];
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FootballTeamCenterSheet(teamId: teamId,
          name: 'Club Generico', load: () async => FootballTeamCenterResult(center: c), onOpenMatch: opened.add))));
      await _settle(tester);
      return opened;
    }

    double y(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;

    testWidgets('RESUMEN: postponed Fecha 11 is next and never hides 12-15; Ver calendario', (tester) async {
      await pumpSheet(tester, center());
      for (final t in ['resumen', 'partidos', 'tabla']) {
        expect(find.byKey(ValueKey('team_center_tab_$t')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('team_center_next')), findsOneWidget);
      expect(find.byKey(const ValueKey('team_center_last')), findsOneWidget);
      expect(find.byKey(const ValueKey('team_center_header_next')), findsOneWidget);
      expect(find.textContaining('Próximo: vs Rival 11 · postergado'), findsOneWidget);
      for (final id in [12, 13, 14]) {
        expect(find.byKey(ValueKey('team_center_soon_$id')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('team_center_soon_15')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('team_center_calendar')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('team_center_section_upcoming')), findsOneWidget);
    });

    testWidgets('PARTIDOS: 5 upcoming ascending, results newest first, postponed honest, month groups',
        (tester) async {
      final opened = await pumpSheet(tester, center());
      await tester.tap(find.byKey(const ValueKey('team_center_tab_partidos')));
      await _settle(tester);
      final order = ['team_center_match_11', 'team_center_match_12', 'team_center_match_13',
        'team_center_match_14', 'team_center_match_15', 'team_center_match_10', 'team_center_match_9'];
      for (var i = 0; i < order.length - 1; i++) {
        expect(y(tester, order[i]), lessThan(y(tester, order[i + 1])), reason: '${order[i]} before ${order[i + 1]}');
      }
      expect(y(tester, 'team_center_section_upcoming'), lessThan(y(tester, 'team_center_match_11')));
      expect(y(tester, 'team_center_match_15'), lessThan(y(tester, 'team_center_section_results')));
      expect(find.text('Postergado · nueva fecha por confirmar'), findsOneWidget);
      expect(find.text('Por reprogramar'), findsOneWidget);
      expect(find.text('Octubre 2030'), findsOneWidget);
      expect(find.text('Noviembre 2030'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('team_center_match_14_state'))).data, 'Hora por confirmar');
      expect(tester.widget<Text>(find.byKey(const ValueKey('team_center_match_11_state'))).data, 'POSTERGADO');
      expect(tester.widget<Text>(find.byKey(const ValueKey('team_center_match_10_state'))).data, 'FINAL 2-0');
      await tester.tap(find.byKey(const ValueKey('team_center_filter_upcoming')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('team_center_match_10')), findsNothing);
      for (final id in [11, 12, 13, 14, 15]) {
        expect(find.byKey(ValueKey('team_center_match_$id')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('team_center_filter_results')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('team_center_match_12')), findsNothing);
      expect(y(tester, 'team_center_match_10'), lessThan(y(tester, 'team_center_match_9')));
      await tester.tap(find.byKey(const ValueKey('team_center_match_9')));
      await tester.pump();
      expect(opened.map((m) => m.id).toList(), [9]);
    });

    testWidgets('older backend without split: derived on the device, same order rules', (tester) async {
      await pumpSheet(tester, center(split: false));
      await tester.tap(find.byKey(const ValueKey('team_center_tab_partidos')));
      await _settle(tester);
      expect(y(tester, 'team_center_match_12'), lessThan(y(tester, 'team_center_match_15')));
      expect(y(tester, 'team_center_match_15'), lessThan(y(tester, 'team_center_match_10')));
      expect(y(tester, 'team_center_match_10'), lessThan(y(tester, 'team_center_match_9')));
    });

    testWidgets('TABLA: ±2 window around the club, full table on demand, honest empty', (tester) async {
      await pumpSheet(tester, center());
      await tester.tap(find.byKey(const ValueKey('team_center_tab_tabla')));
      await _settle(tester);
      expect(find.text('Liga 1 Perú · Clausura'), findsOneWidget);
      for (final r in [4, 5, 7, 8]) {
        expect(find.byKey(ValueKey('team_center_table_row_${500 + r}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('team_center_table_row_$teamId')), findsOneWidget);
      expect(find.byKey(const ValueKey('team_center_table_row_501')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('team_center_table_toggle')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('team_center_table_row_501')), findsOneWidget);
      expect(find.byKey(const ValueKey('team_center_table_row_510')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpSheet(tester, center(withTable: false));
      await tester.tap(find.byKey(const ValueKey('team_center_tab_tabla')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('team_center_table_empty')), findsOneWidget);
    });

    testWidgets('no overflow at 360 px in any tab', (tester) async {
      await pumpSheet(tester, center(), size: const Size(360, 700));
      for (final t in ['partidos', 'tabla', 'resumen']) {
        await tester.tap(find.byKey(ValueKey('team_center_tab_$t')));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: t);
      }
    });

    test('contract: upcoming / results / standings parse; month labels', () {
      final c = FootballTeamCenter.fromJson({'teamId': 5, 'matches': [], 'upcoming': [
        {'id': 1, 'status': 'POSTPONED', 'kickoffConfirmed': false, 'kickoff': '2026-10-01T20:00:00Z'}],
        'results': [{'id': 2, 'status': 'FINISHED'}],
        'standings': {'competitionId': 'LIGA_1', 'group': 'Clausura', 'rank': 3, 'total': 18,
          'rows': [{'group': 'Clausura', 'rank': 3, 'teamId': 5}, {'group': 'Apertura', 'rank': 1, 'teamId': 5}]}});
      expect(c.upcoming.single.id, 1);
      expect(c.results.single.id, 2);
      expect(c.standings!.groupRows.length, 1);
      expect(footballTeamMonth(c.upcoming.single, currentYear: 2026), 'Por reprogramar');
      expect(footballTeamMonth(_m(3, kickoff: DateTime(2026, 11, 2)), currentYear: 2026), 'Noviembre');
    });
  });

  // ---------------------------------------------------------------- navigation
  testWidgets('each section keeps its scroll position when coming back', (tester) async {
    final service = _Football(list: [for (var i = 1; i <= 30; i++) _m(i, status: 'SCHEDULED')]);
    await _pumpHub(tester, service, size: const Size(390, 900));
    await tester.tap(find.byKey(const ValueKey('ver_todos_LIGA_1')));
    await _settle(tester);
    final list = find.byKey(const PageStorageKey<String>('centro_list_forYou_today:ALL'));
    expect(list, findsOneWidget);
    await tester.drag(list, const Offset(0, -900));
    await _settle(tester);
    double offset() => tester.state<ScrollableState>(find.descendant(
        of: find.byKey(const PageStorageKey<String>('centro_list_forYou_today:ALL')),
        matching: find.byType(Scrollable)).first).position.pixels;
    final before = offset();
    expect(before, greaterThan(300));
    for (final section in ['section_results', 'section_today']) {
      await tester.ensureVisible(find.byKey(ValueKey(section)));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(section)));
      await _settle(tester);
    }
    expect(service.calls, contains('matches:RESULTS'), reason: 'the section really changed');
    expect(offset(), closeTo(before, 1));
    expect(service.calls.where((c) => c == 'featured').length, 1, reason: 'no duplicate hero request on rebuild');
  });
}

// ------------------------------------------------------------------- football fakes

const _comps = [
  FootballCompetition(id: 'LIGA_1', name: 'Liga 1 Perú', available: true, region: 'PERU', group: 'peru'),
];

class _Football extends GarraFootballService {
  _Football({this.list = const []}) : super(dio: Dio());
  List<FootballMatch> list;
  final List<String> calls = [];
  FootballDetail? Function(FootballMatch match, String? section)? onDetail;

  @override
  Future<List<FootballCompetition>> competitions() async => _comps;

  @override
  Future<FootballPage<FootballMatch>> matches(FootballView view, {String? competition}) async {
    calls.add('matches:${view.wire}');
    return FootballPage(items: list, stale: false, unavailable: false, partial: false);
  }

  @override
  Future<FootballFeatured?> featured() async {
    calls.add('featured');
    return null;
  }

  @override
  Future<FootballDetail?> detail(FootballMatch match, {String? section}) async {
    calls.add('detail:${section ?? 'BASE'}');
    return onDetail?.call(match, section) ?? FootballDetail(match: match, events: const [], lineups: const [],
        statistics: const [], partial: false, stale: false);
  }
}

Future<void> _pumpHub(WidgetTester tester, _Football service, {Size size = const Size(390, 1400)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(initialLocation: '/centro-garra', routes: [
    GoRoute(path: '/centro-garra', builder: (_, _) => const CentroGarraPage()),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    garraFootballServiceProvider.overrideWithValue(service),
    connectivityStatusProvider.overrideWith(_Net.new),
    communityServiceProvider.overrideWithValue(_Community()),
  ], child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
}

Future<void> _pumpDetail(WidgetTester tester, _Football service, FootballMatch match,
    {Size size = const Size(390, 1200), List<String>? visited}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(initialLocation: '/d', routes: [
    GoRoute(path: '/d', builder: (_, _) => CentroGarraMatchDetailPage(match: match)),
    GoRoute(path: '/centro-garra/chat-futbolero', builder: (_, state) {
      visited?.add(state.uri.queryParameters['partido'] ?? '');
      return const Scaffold(body: Text('CHAT'));
    }),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    garraFootballServiceProvider.overrideWithValue(service),
    connectivityStatusProvider.overrideWith(_Net.new),
    communityServiceProvider.overrideWithValue(_Community()),
  ], child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
}
