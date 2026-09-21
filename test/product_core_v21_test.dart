import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garra_digital_app/core/network/dio_client.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_share_card.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/locations/data/crema_business_application_service.dart';
import 'package:garra_digital_app/features/notifications/data/push_router.dart';

void main() {
  group('home mode selection', () {
    HomeModel base({required String matchdayState}) {
      return HomeModel(
        fan: const HomeFanSummary(
          displayName: 'Crema',
          username: 'crema',
          levelNumber: 1,
          levelName: 'Hincha',
          points: 10,
        ),
        matchdayState: matchdayState,
        prediction: const HomePrediction(
          state: 'NOT_PREDICTED',
          predictionsOpen: false,
        ),
        checkIn: const HomeCheckIn(
          showCheckInCta: false,
          hasActiveStadiumPoint: false,
          recentlyCheckedIn: false,
        ),
        community: const HomeCommunityPreview(posts: []),
        notifications: const HomeNotifications(unreadCount: 0),
      );
    }

    test('HOME_MATCHDAY_DEFAULT_WHEN_LIVE', () {
      final home = base(matchdayState: 'LIVE');
      expect(home.isLive || home.isMatchday, isTrue);
    });

    test('HOME_COMMUNITY_DEFAULT_WHEN_NO_MATCH', () {
      final home = base(matchdayState: 'NO_MATCH');
      expect(home.isLive || home.isMatchday, isFalse);
    });
  });

  group('http resilience', () {
    test('GET_RETRY_ON_502', () {
      expect(
        HttpResiliencePolicy.shouldRetryGet(
          method: 'GET',
          alreadyRetried: false,
          statusCode: 502,
        ),
        isTrue,
      );
    });

    test('NO_POST_RETRY', () {
      expect(HttpResiliencePolicy.shouldRetryPost(), isFalse);
      expect(
        HttpResiliencePolicy.shouldRetryGet(
          method: 'POST',
          alreadyRetried: false,
          statusCode: 502,
        ),
        isFalse,
      );
    });

    test('GET_RETRY_ONCE_ONLY', () {
      expect(
        HttpResiliencePolicy.shouldRetryGet(
          method: 'GET',
          alreadyRetried: true,
          type: DioExceptionType.connectionTimeout,
        ),
        isFalse,
      );
    });
  });

  group('business + notifications', () {
    test('BUSINESS_STATUS_LABELS', () {
      expect(CremaBusinessApplicationStatus.pending.label, 'En revisión');
      expect(CremaBusinessApplicationStatus.verified.label, 'Verificado');
      expect(
        CremaBusinessApplicationStatus.fromApi('VERIFIED'),
        CremaBusinessApplicationStatus.verified,
      );
    });

    test('BUSINESS_NOTIFICATION_ROUTES_MI_NEGOCIO', () {
      const router = PushRouter();
      expect(
        router.resolveRoute(
          authenticated: true,
          referenceType: 'CREMA_BUSINESS_APPLICATION',
          referenceId: 'app-1',
        ),
        '/ruta-templo/mi-negocio',
      );
    });
  });

  group('share card', () {
    test('SHARE_CARD_STYLES_EXIST', () {
      expect(GarraShareCardStyle.values.length, 3);
    });
  });
}
