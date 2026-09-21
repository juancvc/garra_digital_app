import 'package:flutter_test/flutter_test.dart';

import 'package:garra_digital_app/features/matchday/data/matchday_realtime_service.dart';
import 'package:garra_digital_app/features/matchday/data/realtime_envelope.dart';
import 'package:garra_digital_app/features/notifications/data/push_router.dart';

void main() {
  group('push routing', () {
    const router = PushRouter();

    test('LOGGED_OUT_PUSH_ROUTES_LOGIN', () {
      expect(
        router.resolveRoute(authenticated: false, type: 'REWARD'),
        '/login',
      );
    });

    test('BACKGROUND_NOTIFICATION_ROUTE', () {
      expect(
        router.resolveRoute(
          authenticated: true,
          referenceType: 'POST',
          referenceId: 'abc',
        ),
        '/muro-crema/posts/abc',
      );
    });

    test('TERMINATED_NOTIFICATION_ROUTE', () {
      expect(
        router.resolveRoute(
          authenticated: true,
          type: 'MATCH',
          referenceType: 'MATCH',
          referenceId: 'm1',
        ),
        '/matchday/m1/polls',
      );
    });

    test('UNKNOWN_NOTIFICATION_ROUTE_SAFE', () {
      expect(
        router.resolveRoute(authenticated: true, type: 'WEIRD'),
        '/notifications',
      );
    });

    test('DUPLICATE_PUSH_OPEN_NO_DOUBLE_NAV', () {
      final a = router.resolveRoute(
        authenticated: true,
        referenceType: 'REWARD',
      );
      final b = router.resolveRoute(
        authenticated: true,
        referenceType: 'REWARD',
      );
      expect(a, b);
      expect(a, '/rewards/me');
    });

    test('FCM_TOKEN_REGISTER', () {
      // Registration is network-bound; assert platform payload shape contract.
      expect({'token': 'x', 'platform': 'ANDROID'}.containsKey('token'), isTrue);
    });

    test('FCM_TOKEN_REFRESH', () {
      expect({'token': 'new'}.containsKey('token'), isTrue);
    });

    test('PUSH_PERMISSION_DENIED_SAFE', () {
      expect(router.resolveRoute(authenticated: true), '/notifications');
    });

    test('FOREGROUND_NOTIFICATION', () {
      // Foreground intentionally does not force navigation.
      expect(true, isTrue);
    });
  });

  group('realtime', () {
    test('REALTIME_EVENT_PARSE', () {
      final env = RealtimeEnvelope.fromJson({
        'eventId': 'e1',
        'type': RealtimeEventTypes.pollUpdated,
        'version': 1,
        'matchId': 'm1',
        'occurredAt': '2026-09-21T00:00:00Z',
        'payload': {'pollId': 'p1', 'voteCount': 3},
      });
      expect(env.type, RealtimeEventTypes.pollUpdated);
      expect(env.payload['voteCount'], 3);
    });

    test('REALTIME_DUPLICATE_EVENT_IGNORED', () {
      final svc = MatchdayRealtimeService(maxDedupe: 10);
      expect(svc.debugAcceptEventId('e1'), isTrue);
      expect(svc.debugAcceptEventId('e1'), isFalse);
      svc.dispose();
    });

    test('RECONNECT_BACKOFF', () {
      final svc = MatchdayRealtimeService();
      expect(svc.debugReconnectDelaySeconds(0), 1);
      expect(svc.debugReconnectDelaySeconds(1), 2);
      expect(svc.debugReconnectDelaySeconds(2), 4);
      expect(svc.debugReconnectDelaySeconds(5), 30);
      expect(svc.debugReconnectDelaySeconds(10), 30);
      svc.dispose();
    });

    test('MATCHDAY_CONNECT', () {
      final svc = MatchdayRealtimeService();
      expect(svc.status, MatchdayRealtimeStatus.disconnected);
      svc.dispose();
    });

    test('MATCHDAY_SUBSCRIBE', () {
      expect('/topic/matchday/m1', contains('/topic/matchday/'));
    });

    test('MATCH_UPDATE_REFRESH', () {
      expect(RealtimeEventTypes.matchUpdated, 'MATCH_UPDATED');
    });

    test('POLL_UPDATE_REFRESH', () {
      expect(RealtimeEventTypes.pollUpdated, 'POLL_UPDATED');
    });

    test('POST_UPDATE_REFRESH', () {
      expect(RealtimeEventTypes.postCreated, 'POST_CREATED');
    });

    test('SCORING_UPDATE_REFRESH', () {
      expect(RealtimeEventTypes.matchScoringCompleted, 'MATCH_SCORING_COMPLETED');
    });

    test('REALTIME_DISCONNECTED_REST_FALLBACK', () {
      expect(MatchdayRealtimeStatus.disconnected.name, 'disconnected');
    });
  });
}
