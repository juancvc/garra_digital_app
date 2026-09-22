import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';

void main() {
  group('own post permissions', () {
    test('isMine posts never treat author as blockable', () {
      const mine = WallPostModel(
        id: '1',
        username: 'me',
        fullName: 'Me',
        content: 'hola',
        imageUrl: null,
        locationTag: '',
        status: 'ACTIVE',
        reportCount: 0,
        createdAt: '2026-01-01',
        isMine: true,
        authorId: 'aaa',
      );
      expect(mine.isMine, isTrue);
      // UI contract: onBlock/onReport must be null when isMine.
      final showBlock = !mine.isMine && mine.authorId != null;
      final showReport = !mine.isMine;
      expect(showBlock, isFalse);
      expect(showReport, isFalse);
    });

    test('other posts allow block/report', () {
      const other = WallPostModel(
        id: '2',
        username: 'other',
        fullName: 'Other',
        content: 'hola',
        imageUrl: null,
        locationTag: '',
        status: 'ACTIVE',
        reportCount: 0,
        createdAt: '2026-01-01',
        isMine: false,
        authorId: 'bbb',
      );
      expect(!other.isMine && other.authorId != null, isTrue);
    });
  });

  group('roles', () {
    test('SUPERADMIN is admin', () {
      const u = AuthUser(
        userId: '1',
        email: 'a@b.c',
        username: 'sa',
        fullName: 'SA',
        status: 'ACTIVE',
        role: 'SUPERADMIN',
      );
      expect(u.isSuperAdmin, isTrue);
      expect(u.isAdmin, isTrue);
    });

    test('USER is not admin', () {
      const u = AuthUser(
        userId: '1',
        email: 'a@b.c',
        username: 'u',
        fullName: 'U',
        status: 'ACTIVE',
        role: 'USER',
      );
      expect(u.isAdmin, isFalse);
      expect(u.isSuperAdmin, isFalse);
    });
  });

  group('media model', () {
    test('parses media array and legacy imageUrl', () {
      final post = WallPostModel.fromJson({
        'id': '1',
        'username': 'u',
        'fullName': 'U',
        'content': 'x',
        'status': 'ACTIVE',
        'reportCount': 0,
        'createdAt': 't',
        'locationTag': '',
        'isMine': true,
        'media': [
          {'id': 'm1', 'url': 'https://a/1.jpg', 'sortOrder': 0},
          {'id': 'm2', 'url': 'https://a/2.jpg', 'sortOrder': 1},
        ],
      });
      expect(post.media.length, 2);
      expect(post.imageUrl, 'https://a/1.jpg');
      expect(post.isMine, isTrue);
    });
  });
}
