import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/community/data/report_wall_post_request.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/notifications/data/push_router.dart';
import 'package:garra_digital_app/features/solidarity/data/solidarity_service.dart';

void main() {
  group('community 365 contracts', () {
    test('REPORT_CATEGORY_PAYLOAD', () {
      final json = const ReportWallPostRequest(
        category: 'SPAM',
        reason: 'mucho spam',
      ).toJson();
      expect(json['category'], 'SPAM');
      expect(json['reason'], 'mucho spam');
    });

    test('GLOBAL_POST_MODEL_AUTHOR', () {
      final post = WallPostModel.fromJson({
        'id': 'p1',
        'username': 'crema',
        'fullName': 'Crema Fan',
        'content': 'Hola 365',
        'imageUrl': null,
        'locationTag': 'HOME',
        'status': 'ACTIVE',
        'reportCount': 0,
        'createdAt': '2026-01-01T00:00:00Z',
        'contextType': 'GLOBAL',
        'authorId': 'u-1',
      });
      expect(post.contextType, 'GLOBAL');
      expect(post.authorId, 'u-1');
      expect(post.matchId, '');
    });

    test('PUSH_ROUTES_SOLIDARIA_AND_OFFERS', () {
      const router = PushRouter();
      expect(
        router.resolveRoute(
          authenticated: true,
          referenceType: 'SOLIDARITY',
          referenceId: 'c1',
        ),
        '/solidaria/c1',
      );
      expect(
        router.resolveRoute(
          authenticated: true,
          referenceType: 'BUSINESS_OFFER',
          referenceId: 'o1',
        ),
        '/ruta-templo?offerId=o1',
      );
      expect(
        router.resolveRoute(
          authenticated: true,
          referenceType: 'CREMA_POINT',
        ),
        '/ruta-templo',
      );
      expect(
        router.resolveRoute(
          authenticated: true,
          referenceType: 'FOLLOWED_BUSINESS',
        ),
        '/ruta-templo',
      );
    });

    test('SOLIDARITY_MODEL_VERIFIED', () {
      final c = SolidarityCampaign.fromJson({
        'id': '1',
        'title': 'Sangre',
        'description': 'd',
        'type': 'BLOOD',
        'city': 'Lima',
        'status': 'ACTIVE',
        'verificationStatus': 'VERIFIED',
      });
      expect(c.isVerified, isTrue);
    });
  });
}
