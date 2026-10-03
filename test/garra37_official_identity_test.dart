import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_share_sheet.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';

const _badge = ValueKey('garra_official_badge');

Map<String, dynamic> _postJson({
  String id = 'p1',
  String fullName = 'Ana',
  String accountType = 'STANDARD',
}) => {
  'id': id,
  'username': 'ana',
  'fullName': fullName,
  'content': 'Vamos la U',
  'status': 'ACTIVE',
  'contextType': 'GLOBAL',
  'accountType': accountType,
  'createdAt': '2026-09-29T12:00:00Z',
  'shareCount': 1,
};

WallPostModel _post({
  String fullName = 'Ana',
  String accountType = 'STANDARD',
}) => WallPostModel.fromJson(
  _postJson(fullName: fullName, accountType: accountType),
);

WallPostModel _share({
  String originalType = 'PLATFORM_OFFICIAL',
  String sharerType = 'STANDARD',
}) => WallPostModel.fromJson({
  'id': 'share',
  'username': 'luis',
  'fullName': 'Luis',
  'content': '',
  'status': 'ACTIVE',
  'contextType': 'GLOBAL',
  'accountType': sharerType,
  'createdAt': '2026-09-29T13:00:00Z',
  'originalPost': {
    'id': 'original',
    'authorId': 'garra-id',
    'username': 'garradigital',
    'fullName': 'Garra Digital',
    'content': 'Bienvenidos a la tribuna',
    'createdAt': '2026-09-29T12:00:00Z',
    'shareCount': 3,
    'accountType': originalType,
  },
});

Widget _host(Widget child, {double width = 360, GarraSemanticColors? colors}) =>
    MaterialApp(
      theme: ThemeData(extensions: [colors ?? GarraSemanticColors.noche]),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );

class _Service extends CommunityService {
  _Service() : super(dio: Dio());
  int shareCalls = 0;
}

class _ProfileService extends CommunityService {
  _ProfileService(this.profile) : super(dio: Dio());
  final Map<String, dynamic> profile;
  @override
  Future<Map<String, dynamic>> getPublicProfile(String userId) async => profile;
  @override
  Future<bool> registerProfileView(String userId) async => false;
}

class _Chat extends ChatService {
  _Chat() : super(dio: Dio());
  @override
  Future<ChatRelationship> relationship(
    String userId, {
    String context = 'SOCIAL',
  }) async => ChatRelationship.none();
}

Future<GarraShareOutcome?> _openSheet(
  WidgetTester tester,
  WallPostModel post, {
  required bool allowInternalRepost,
}) async {
  GarraShareOutcome? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showGarraShareSheet(
              context,
              post: post,
              service: _Service(),
              allowInternalRepost: allowInternalRepost,
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('models read the backend accountType', () {
    test('defaults to STANDARD when absent (old backend)', () {
      expect(WallPostModel.fromJson({'id': 'x'}).isOfficial, isFalse);
      expect(WallPostModel.fromJson({'id': 'x'}).accountType, 'STANDARD');
      expect(WallCommentModel.fromJson({'id': 'c'}).isOfficial, isFalse);
      expect(AuthUser.fromJson({'id': 'u'}).isPlatformOfficial, isFalse);
    });

    test('PLATFORM_OFFICIAL is parsed for post, original, comment and me', () {
      final share = _share();
      expect(share.isOfficial, isFalse);
      expect(share.originalPost!.isOfficial, isTrue);
      expect(share.originalPost!.asPost().isOfficial, isTrue);
      expect(share.copyWith(shareCount: 9).accountType, 'STANDARD');
      expect(_post(accountType: 'PLATFORM_OFFICIAL').isOfficial, isTrue);
      expect(
        WallCommentModel.fromJson({
          'id': 'c',
          'accountType': 'PLATFORM_OFFICIAL',
        }).isOfficial,
        isTrue,
      );
      expect(
        AuthUser.fromJson({
          'id': 'u',
          'accountType': 'PLATFORM_OFFICIAL',
        }).isPlatformOfficial,
        isTrue,
      );
    });
  });

  group('post card official treatment', () {
    testWidgets('normal post has no official treatment', (tester) async {
      await tester.pumpWidget(
        _host(GarraSocialPostCard(post: _post(), onOpen: () {})),
      );
      expect(find.byKey(_badge), findsNothing);
      expect(find.text('Garra Oficial'), findsNothing);
    });

    testWidgets(
      'a user named "Garra Digital" is NOT official without the backend flag',
      (tester) async {
        await tester.pumpWidget(
          _host(
            GarraSocialPostCard(
              post: _post(fullName: 'Garra Digital'),
              onOpen: () {},
            ),
          ),
        );
        expect(find.text('Garra Digital'), findsOneWidget);
        expect(find.byKey(_badge), findsNothing);
      },
    );

    for (final entry in {
      'noche': GarraSemanticColors.noche,
      'crema': GarraSemanticColors.crema,
    }.entries) {
      testWidgets('official post shows the sober badge (${entry.key})', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            GarraSocialPostCard(
              post: _post(
                fullName: 'Garra Digital',
                accountType: 'PLATFORM_OFFICIAL',
              ),
              onOpen: () {},
            ),
            colors: entry.value,
          ),
        );
        expect(find.byKey(_badge), findsOneWidget);
        expect(find.text('Garra Oficial'), findsOneWidget);
        expect(find.text('Garra Digital'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'repost of an official post shows the original, badge on the original only',
      (tester) async {
        await tester.pumpWidget(
          _host(GarraSocialPostCard(post: _share(), onOpen: () {})),
        );
        expect(find.text('Luis compartió'), findsOneWidget);
        expect(find.text('Garra Digital'), findsOneWidget);
        expect(find.text('Bienvenidos a la tribuna'), findsOneWidget);
        expect(find.byKey(_badge), findsOneWidget);
      },
    );

    testWidgets('repost of a normal post has no badge', (tester) async {
      await tester.pumpWidget(
        _host(
          GarraSocialPostCard(
            post: _share(originalType: 'STANDARD'),
            onOpen: () {},
          ),
        ),
      );
      expect(find.byKey(_badge), findsNothing);
    });

    testWidgets('narrow width and large text do not overflow', (tester) async {
      tester.view.physicalSize = const Size(220, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [GarraSemanticColors.noche]),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  GarraSocialPostCard(
                    post: _post(
                      fullName: 'Garra Digital Oficial de la Comunidad Crema',
                      accountType: 'PLATFORM_OFFICIAL',
                    ),
                    onOpen: () {},
                  ),
                  GarraSocialPostCard(post: _share(), onOpen: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(_badge), findsNWidgets(2));
    });
  });

  group('official public profile', () {
    Future<void> pumpProfile(WidgetTester tester, String accountType) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [GarraSemanticColors.noche]),
          home: PublicFanProfilePage(
            userId: 'fan',
            communityService: _ProfileService({
              'id': 'fan',
              'username': 'garradigital',
              'displayName': 'Garra Digital',
              'profileVisibility': 'PUBLIC',
              'followerCount': 1,
              'followingCount': 0,
              'globalPostCount': 0,
              'isMe': false,
              'globalPosts': <dynamic>[],
              'accountType': accountType,
            }),
            chatService: _Chat(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('official profile shows Garra Oficial', (tester) async {
      await pumpProfile(tester, 'PLATFORM_OFFICIAL');
      expect(find.text('Garra Digital'), findsOneWidget);
      expect(find.byKey(_badge), findsOneWidget);
      expect(
        find.text('Seguidores'),
        findsOneWidget,
      ); // social capabilities kept
    });

    testWidgets('standard profile with the same name has no badge', (
      tester,
    ) async {
      await pumpProfile(tester, 'STANDARD');
      expect(find.byKey(_badge), findsNothing);
    });
  });

  group('share sheet: internal repost vs external share', () {
    testWidgets('an original post offers in-app repost and external share', (
      tester,
    ) async {
      await _openSheet(tester, _post(), allowInternalRepost: true);
      expect(find.text('Compartir en Garra'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Compartir en otras apps'), findsOneWidget);
    });

    testWidgets(
      'a repost card hides internal repost but keeps external share',
      (tester) async {
        await _openSheet(
          tester,
          _share().originalPost!.asPost(),
          allowInternalRepost: false,
        );
        expect(find.text('Compartir en Garra'), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Compartir en otras apps'), findsOneWidget);
      },
    );

    testWidgets('external share from a repost resolves to the original post', (
      tester,
    ) async {
      final original = _share().originalPost!.asPost();
      GarraShareOutcome? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showGarraShareSheet(
                  context,
                  post: original,
                  service: _Service(),
                  allowInternalRepost: false,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compartir en otras apps'));
      await tester.pumpAndSettle();
      expect(result?.external, isTrue);
      // the post handed to the sheet (and later used for the link/text) is the original
      expect(original.id, 'original');
      expect(original.originalPost, isNull);
    });
  });
}
