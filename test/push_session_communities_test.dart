import 'package:flutter_test/flutter_test.dart';

import 'package:garra_digital_app/features/notifications/data/notification_service.dart';
import 'package:garra_digital_app/features/notifications/data/push_router.dart';
import 'package:garra_digital_app/features/notifications/data/push_session_coordinator.dart';

void main() {
  group('push routing communities', () {
    const router = PushRouter();

    test('CLAN_INVITATION_PUSH_ROUTES_INVITATIONS', () {
      expect(
        router.resolveRoute(
          authenticated: true,
          type: 'CLAN',
          referenceType: 'CLAN_INVITATION',
          referenceId: '11111111-1111-1111-1111-111111111111',
        ),
        '/clans/invitations',
      );
    });

    test('CLAN_UUID_PUSH_DOES_NOT_ROUTE_AS_SLUG', () {
      expect(
        router.resolveRoute(
          authenticated: true,
          type: 'CLAN',
          referenceType: 'CLAN',
          referenceId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        ),
        '/clans',
      );
      expect(
        router.resolveRoute(
          authenticated: true,
          referenceType: 'CLAN',
          referenceId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        ).contains('aaaaaaaa'),
        isFalse,
      );
    });

    test('NOTIFICATION_ITEM_ROUTING_USES_PUSH_ROUTER', () {
      final item = NotificationItem(
        id: '1',
        type: 'CLAN',
        title: 'Invitación',
        message: 'Te invitaron',
        referenceType: 'CLAN_INVITATION',
        referenceId: 'inv-1',
        createdAt: DateTime.utc(2026, 1, 1),
        read: false,
      );
      expect(
        router.resolveRoute(
          authenticated: true,
          type: item.type,
          referenceType: item.referenceType,
          referenceId: item.referenceId,
        ),
        '/clans/invitations',
      );
    });
  });

  group('push session coordinator', () {
    test('PUSH_AFTER_AUTH_IDEMPOTENT_REFRESH_ONCE', () async {
      var registerCalls = 0;
      var listenCalls = 0;
      final coordinator = PushSessionCoordinator(
        register: () async {
          registerCalls++;
        },
        listen: () {
          listenCalls++;
        },
      );

      await coordinator.afterAuthenticated();
      await coordinator.afterAuthenticated();
      await coordinator.bootstrapIfAuthenticated(hasAuth: true);

      expect(registerCalls, 3);
      expect(listenCalls, 1);
    });

    test('AUTH_CONTINUES_IF_PUSH_REGISTRATION_FAILS', () async {
      final coordinator = PushSessionCoordinator(
        register: () async {
          throw StateError('fcm down');
        },
        listen: () {},
      );
      await expectLater(
        coordinator.afterAuthenticated(),
        completes,
      );
    });

    test('BOOTSTRAP_SKIPPED_WHEN_LOGGED_OUT', () async {
      var registerCalls = 0;
      final coordinator = PushSessionCoordinator(
        register: () async {
          registerCalls++;
        },
        listen: () {},
      );
      await coordinator.bootstrapIfAuthenticated(hasAuth: false);
      expect(registerCalls, 0);
    });
  });
}
