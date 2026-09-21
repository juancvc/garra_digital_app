import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/notifications/data/push_router.dart';

void main() {
  group('social graph 09D contracts', () {
    test('AUTH_USER_ADMIN_ROLE', () {
      final admin = AuthUser.fromJson({
        'userId': '1',
        'email': 'a@t.com',
        'username': 'admin',
        'fullName': 'Admin',
        'status': 'ACTIVE',
        'role': 'ADMIN',
      });
      expect(admin.isAdmin, isTrue);

      final fan = AuthUser.fromJson({
        'userId': '2',
        'email': 'f@t.com',
        'username': 'fan',
        'fullName': 'Fan',
        'status': 'ACTIVE',
      });
      expect(fan.isAdmin, isFalse);
    });

    test('WALL_POST_SAVED_BY_ME', () {
      final post = WallPostModel.fromJson({
        'id': 'p1',
        'username': 'crema',
        'fullName': 'Crema Fan',
        'content': 'Guardado',
        'status': 'ACTIVE',
        'reportCount': 0,
        'createdAt': '2026-01-01T00:00:00Z',
        'contextType': 'GLOBAL',
        'savedByMe': true,
        'authorId': 'u1',
      });
      expect(post.savedByMe, isTrue);
      expect(post.authorId, 'u1');
    });

    test('FEED_MODE_VALUES', () {
      const modes = ['FOR_YOU', 'FOLLOWING', 'RECENT'];
      expect(modes.length, 3);
      expect(modes.first, 'FOR_YOU');
    });

    test('PUSH_ROUTE_FAN_PROFILE', () {
      const router = PushRouter();
      expect(
        router.resolveRoute(
          authenticated: true,
          referenceType: 'FAN_USER',
          referenceId: 'u99',
        ),
        '/comunidad/u/u99',
      );
    });
  });
}
