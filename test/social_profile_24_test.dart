import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/features/passport/data/passport_models.dart';
import 'package:garra_digital_app/features/passport/presentation/social_profile_links.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garra_digital_app/core/widgets/garra_form.dart';
import 'package:garra_digital_app/features/passport/data/passport_service.dart';
import 'package:garra_digital_app/features/passport/presentation/profile_edit_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/providers/passport_provider.dart';

class _Community extends CommunityService {
  _Community(this.profile) : super(dio: Dio());
  final Map<String, dynamic> profile;
  @override
  Future<Map<String, dynamic>> getPublicProfile(String userId) async => profile;
  @override
  Future<bool> registerProfileView(String userId) async => false;
  @override
  Future<List<Map<String, dynamic>>> getProfileFollows(String userId, {required bool followers}) async => [
    {'userId': 'other', 'displayName': 'Hincha Dos', 'username': 'hincha2'},
  ];
}

class _Chat extends ChatService {
  _Chat(this.value) : super(dio: Dio());
  final ChatRelationship value;
  @override
  Future<ChatRelationship> relationship(String userId, {String context = 'SOCIAL'}) async => value;
}

class _RejectingPassportService extends PassportService {
  _RejectingPassportService() : super(dio: Dio());
  @override
  Future<PassportModel> updateMyProfile(ProfileUpdateRequest request) async {
    final options = RequestOptions(path: '/profile/me');
    throw DioException(requestOptions: options,
        response: Response(requestOptions: options, statusCode: 400,
            data: {'message': 'Enlace de INSTAGRAM no válido'}));
  }
}

PassportModel _passport() => const PassportModel(
  identity: PassportIdentity(username: 'ana', displayName: 'Ana'),
  level: PassportLevel(number: 1, name: 'Hincha', points: 0,
      levelMinPoints: 0, progressPercent: 0, pointsToNextLevel: 10),
  stats: PassportStats(checkIns: 0, predictions: 0, predictionPoints: 0, posts: 0),
  globalRank: null, profileVisibility: 'PUBLIC', viewerIsOwner: true,
);

Map<String, dynamic> _profile({String visibility = 'PUBLIC'}) => {
  'id': 'fan', 'username': 'ana', 'displayName': 'Ana',
  'profileVisibility': visibility, 'bio': visibility == 'PRIVATE' ? null : 'Bio crema',
  'primaryClanName': visibility == 'PRIVATE' ? null : 'Garra Norte',
  'instagramUrl': visibility == 'PRIVATE' ? null : 'https://www.instagram.com/ana/',
  'followerCount': 1, 'followingCount': 1, 'globalPostCount': 0,
  'isMe': false, 'globalPosts': <dynamic>[],
};

void main() {
  test('legacy identity has no social links', () {
    final identity = PassportIdentity.fromJson(const {
      'username': 'ana', 'displayName': 'Ana',
    });
    expect(identity.instagramUrl, isNull);
    expect(identity.tiktokUrl, isNull);
    expect(identity.youtubeUrl, isNull);
  });

  test('profile PATCH emits explicit null only when social links are edited', () {
    expect(const ProfileUpdateRequest(displayName: 'Ana').toJson(),
        isNot(contains('instagramUrl')));
    final json = const ProfileUpdateRequest(updateSocialLinks: true,
        instagramUrl: '@ana', tiktokUrl: '').toJson();
    expect(json['instagramUrl'], '@ana');
    expect(json['tiktokUrl'], '');
    expect(json.containsKey('youtubeUrl'), isTrue);
    expect(json['youtubeUrl'], isNull);
  });

  testWidgets('social links show configured safe platforms only', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SocialProfileLinks(
      instagramUrl: 'https://www.instagram.com/ana/',
      tiktokUrl: 'https://tiktok.com.evil.test/@ana',
      youtubeUrl: 'https://www.youtube.com/@ana',
    ))));
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('TikTok'), findsNothing);
    expect(find.text('YouTube'), findsOneWidget);
  });

  testWidgets('public profile shows bio clan links and follower list', (tester) async {
    final service = _Community(_profile());
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) =>
      PublicFanProfilePage(userId: 'fan', communityService: service,
          chatService: _Chat(ChatRelationship.none()))),
      GoRoute(path: '/comunidad/u/:userId', builder: (_, state) =>
          Scaffold(body: Text('PROFILE:${state.pathParameters['userId']}')))]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Bio crema'), findsOneWidget);
    expect(find.text('Comunidad: Garra Norte'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    await tester.tap(find.text('Seguidores'));
    await tester.pumpAndSettle();
    expect(find.text('Hincha Dos'), findsOneWidget);
    await tester.tap(find.text('Hincha Dos'));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE:other'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hincha Dos'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiendo'));
    await tester.pumpAndSettle();
    expect(find.text('Hincha Dos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('private visitor sees identity and actions without expanded content', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PublicFanProfilePage(userId: 'fan',
      communityService: _Community(_profile(visibility: 'PRIVATE')),
      chatService: _Chat(const ChatRelationship(status: 'PENDING', outgoing: true)))));
    await tester.pumpAndSettle();
    expect(find.text('@ana'), findsOneWidget);
    expect(find.text('Bio crema'), findsNothing);
    expect(find.text('Instagram'), findsNothing);
    expect(find.text('Publicaciones'), findsNothing);
    expect(find.text('Solicitud enviada'), findsOneWidget);
  });

  testWidgets('invalid social URL shows a clear error and keeps draft', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      myPassportProvider.overrideWith((ref) async => _passport()),
      passportServiceProvider.overrideWithValue(_RejectingPassportService()),
    ], child: const MaterialApp(home: ProfileEditScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Instagram'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.descendant(
      of: find.widgetWithText(GarraTextField, 'Instagram'),
      matching: find.byType(TextFormField),
    ),
        'https://instagram.com.evil.test/ana');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    expect(find.text('Enlace de INSTAGRAM no válido'), findsOneWidget);
    expect(find.text('https://instagram.com.evil.test/ana'), findsOneWidget);
  });

  testWidgets('profile save stays reachable above keyboard on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      myPassportProvider.overrideWith((ref) async => _passport()),
    ], child: const MaterialApp(home: ProfileEditScreen())));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.text('Guardar cambios').hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(find.text('YouTube'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('YouTube'), findsOneWidget);
  });
}
