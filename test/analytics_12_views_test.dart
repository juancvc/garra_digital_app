import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/core/utils/garra_count_format.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/garra_view_tracker.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_viewport_tracker.dart';
import 'package:garra_digital_app/features/home/presentation/social_feed_tab.dart';

// ANALYTICS_12: post views + profile visits (mobile side).

const _me = 'u-me';
const _other = 'u-otro';

class _FanAs extends CurrentFanNotifier {
  _FanAs(this.id);

  final String id;

  @override
  Future<AuthUser?> build() async => AuthUser(
    userId: id,
    email: '$id@garra.pe',
    username: id,
    fullName: 'Hincha $id',
    status: 'ACTIVE',
  );
}

WallPostModel _post(String id, {String authorId = _other, int views = 0}) =>
    WallPostModel.fromJson({
      'id': id,
      'username': 'autor',
      'fullName': 'Hincha Autor',
      'content': 'Arenga crema $id',
      'status': 'ACTIVE',
      'createdAt': '2026-09-26T19:00:00Z',
      'reactionCount': 0,
      'commentCount': 0,
      'viewCount': views,
      'authorId': authorId,
      'isMine': authorId == _me,
    });

Map<String, dynamic> _profile({required bool me, int? views}) => {
  'displayName': me ? 'T\u00fa' : 'Mar\u00eda Quispe',
  'username': me ? 'yo' : 'mariaquispe',
  'followerCount': 4,
  'followingCount': 2,
  'globalPostCount': 0,
  'isFollowedByMe': false,
  'isBlockedByMe': false,
  'isMe': me,
  'globalPosts': <dynamic>[],
  'profileViewCount': ?views,
};

class _ViewsCommunity extends CommunityService {
  _ViewsCommunity({
    this.post,
    this.feed = const [],
    this.profile,
    this.countedViewCount = 8,
  }) : super(dio: Dio());

  final WallPostModel? post;
  final List<WallPostModel> feed;
  final Map<String, dynamic>? profile;
  final int countedViewCount;
  final List<String> postViews = [];
  final List<String> profileViews = [];

  @override
  Future<WallPostModel> getPost(String postId) async => post!;

  @override
  Future<CommentsPageResult> listComments({
    required String postId,
    String? cursor,
    int size = 20,
  }) async => CommentsPageResult.fromJson({
    'items': <dynamic>[],
    'page': {'size': size, 'hasNext': false, 'nextCursor': null},
  });

  @override
  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async =>
      feed;

  @override
  Future<Map<String, dynamic>> getPublicProfile(String userId) async =>
      profile ?? const {};

  @override
  Future<PostViewResult?> registerPostView(String postId) async {
    postViews.add(postId);
    return PostViewResult(counted: true, viewCount: countedViewCount);
  }

  @override
  Future<bool> registerProfileView(String userId) async {
    profileViews.add(userId);
    return true;
  }
}

class _FakeChat extends ChatService {
  _FakeChat() : super(dio: Dio());

  @override
  Future<ChatRelationship> relationship(
    String userId, {
    String context = 'SOCIAL',
  }) async => ChatRelationship.none();
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  CommunityService? community,
  String fanId = _me,
  ThemeData? theme,
  Size size = const Size(800, 2400),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (community != null)
          communityServiceProvider.overrideWith((ref) => community),
        currentFanProvider.overrideWith(() => _FanAs(fanId)),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        home: Scaffold(body: home),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Widget _profilePage(String userId, _ViewsCommunity community) =>
    PublicFanProfilePage(
      userId: userId,
      communityService: community,
      chatService: _FakeChat(),
    );

Color? _textColor(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).text.style?.color;

Finder get _viewIcon => find.descendant(
  of: find.byKey(const ValueKey('post_view_count')),
  matching: find.byIcon(Icons.visibility_outlined),
);

List<WallPostModel> _feed() => [
  _post('post-0'),
  _post('post-mine', authorId: _me),
  for (var i = 2; i < 12; i++) _post('post-$i'),
];

void main() {
  setUp(() => GarraViewTracker.instance.resetForTest());

  group('formatGarraCount', () {
    test('COMPACT_SPANISH_CASES', () {
      expect(formatGarraCount(-3), '0');
      expect(formatGarraCount(0), '0');
      expect(formatGarraCount(7), '7');
      expect(formatGarraCount(999), '999');
      expect(formatGarraCount(1000), '1 mil');
      expect(formatGarraCount(1200), '1.2 mil');
      expect(formatGarraCount(1250), '1.2 mil');
      expect(formatGarraCount(9999), '9.9 mil');
      expect(formatGarraCount(10000), '10 mil');
      expect(formatGarraCount(10500), '10 mil');
      expect(formatGarraCount(999999), '999 mil');
      expect(formatGarraCount(1000000), '1 M');
      expect(formatGarraCount(1500000), '1.5 M');
      expect(formatGarraCount(12345678), '12 M');
    });
  });

  group('post view UI', () {
    testWidgets('CARD_SHOWS_EYE_AND_COMPACT_COUNT', (tester) async {
      await _pump(
        tester,
        GarraSocialPostCard(post: _post('p', views: 1500), onOpen: () {}),
      );
      expect(find.byKey(const ValueKey('post_view_count')), findsOneWidget);
      expect(_viewIcon, findsOneWidget);
      expect(find.text('1.5 mil'), findsOneWidget);
    });

    testWidgets('CARD_HIDES_VIEWS_WHEN_ZERO', (tester) async {
      await _pump(tester, GarraSocialPostCard(post: _post('p'), onOpen: () {}));
      expect(find.byKey(const ValueKey('post_view_count')), findsNothing);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });

    testWidgets('DETAIL_SHOWS_EXPLICIT_COUNT_AND_OWN_POST_NOT_REGISTERED', (
      tester,
    ) async {
      final community = _ViewsCommunity(
        post: _post('post-1', authorId: _me, views: 1234),
      );
      await _pump(
        tester,
        const PostDetailScreen(postId: 'post-1'),
        community: community,
      );
      expect(find.text('1.2 mil vistas'), findsOneWidget);
      expect(_viewIcon, findsOneWidget);
      expect(community.postViews, isEmpty);
    });

    testWidgets('DETAIL_OTHERS_POST_REGISTERS_ONCE_AND_UPDATES_COUNT', (
      tester,
    ) async {
      final community = _ViewsCommunity(
        post: _post('post-1', views: 7),
        countedViewCount: 8,
      );
      await _pump(
        tester,
        const PostDetailScreen(postId: 'post-1'),
        community: community,
      );
      expect(community.postViews, ['post-1']);
      expect(find.text('8 vistas'), findsOneWidget);

      // Re-opening in the same session does not send another request.
      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        const PostDetailScreen(postId: 'post-1'),
        community: community,
      );
      expect(community.postViews, ['post-1']);
    });
  });

  group('feed visibility tracking', () {
    testWidgets('FEED_DOES_NOT_REGISTER_ON_BUILD', (tester) async {
      final community = _ViewsCommunity(feed: _feed());
      await _pump(
        tester,
        const SocialFeedTab(mode: 'FOR_YOU'),
        community: community,
        size: const Size(800, 1000),
        settle: false,
      );
      expect(find.byType(GarraViewportTracker), findsWidgets);
      await tester.pump(const Duration(milliseconds: 900));
      expect(community.postViews, isEmpty);
    });

    testWidgets('FEED_VISIBLE_1S_REGISTERS_ONCE_SKIPS_OWN_AND_OFFSCREEN', (
      tester,
    ) async {
      final community = _ViewsCommunity(feed: _feed());
      await _pump(
        tester,
        const SocialFeedTab(mode: 'FOR_YOU'),
        community: community,
        size: const Size(800, 1000),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 1100));
      expect(community.postViews, contains('post-0'));
      expect(community.postViews, isNot(contains('post-mine')));
      expect(community.postViews, isNot(contains('post-11')));
      final firstRound = List<String>.from(community.postViews);

      // More time and small scrolls do not repeat already-seen cards.
      await tester.pump(const Duration(seconds: 3));
      await tester.drag(find.byType(ListView), const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.drag(find.byType(ListView), const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 1100));
      for (final id in firstRound) {
        expect(community.postViews.where((v) => v == id).length, 1);
      }
      expect(community.postViews, isNot(contains('post-mine')));

      // Scrolling far down brings post-11 into view -> counted after 1s.
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(community.postViews.where((v) => v == 'post-11').length, 1);
      expect(community.postViews, isNot(contains('post-mine')));
    });

    testWidgets('VISIBILITY_CRITERION_50_PERCENT_FOR_1S_FIRES_ONCE', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var fired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              children: [
                const SizedBox(height: 520),
                GarraViewportTracker(
                  id: 'p',
                  onVisible: () => fired++,
                  child: const SizedBox(height: 200),
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      );
      // 80/200 = 40% visible: never fires.
      await tester.pump(const Duration(seconds: 2));
      expect(fired, 0);

      // 140/200 = 70% visible, but interrupted before 1s.
      controller.jumpTo(60);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      controller.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(fired, 0);

      // Visible again: needs a full uninterrupted second.
      controller.jumpTo(60);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(fired, 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(fired, 1);

      // Fires only once.
      controller.jumpTo(0);
      await tester.pump();
      controller.jumpTo(60);
      await tester.pump(const Duration(seconds: 2));
      expect(fired, 1);
    });

    testWidgets('DISABLED_TRACKER_NEVER_FIRES', (tester) async {
      var fired = 0;
      await _pump(
        tester,
        GarraViewportTracker(
          id: 'own',
          enabled: false,
          onVisible: () => fired++,
          child: const SizedBox(height: 200),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(fired, 0);
    });

    test('SESSION_CACHE_PREVENTS_REPEATS', () async {
      final community = _ViewsCommunity();
      final tracker = GarraViewTracker.instance;
      expect(await tracker.trackPostView(community, 'post-9'), 8);
      expect(await tracker.trackPostView(community, 'post-9'), isNull);
      expect(await tracker.trackProfileView(community, 'fan-2'), isTrue);
      expect(await tracker.trackProfileView(community, 'fan-2'), isFalse);
      expect(community.postViews, ['post-9']);
      expect(community.profileViews, ['fan-2']);
      expect(tracker.hasTrackedPost('post-9'), isTrue);
      expect(tracker.hasTrackedProfile('fan-2'), isTrue);
    });
  });

  group('profile visits', () {
    testWidgets('OTHERS_PROFILE_REGISTERS_ONCE_AND_SHOWS_NO_COUNTER', (
      tester,
    ) async {
      // Even if a payload carried the field, a non-owner never renders it.
      final community = _ViewsCommunity(
        profile: _profile(me: false, views: 99),
      );
      await _pump(
        tester,
        _profilePage('fan-2', community),
        community: community,
      );
      expect(community.profileViews, ['fan-2']);
      expect(find.byKey(const Key('profile_views')), findsNothing);
      expect(find.textContaining('visita'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        _profilePage('fan-2', community),
        community: community,
      );
      expect(community.profileViews, ['fan-2']);
    });

    testWidgets('MY_PROFILE_SHOWS_VISITS_AND_DOES_NOT_REGISTER', (
      tester,
    ) async {
      final community = _ViewsCommunity(profile: _profile(me: true, views: 37));
      await _pump(tester, _profilePage(_me, community), community: community);
      expect(community.profileViews, isEmpty);
      expect(find.byKey(const Key('profile_views')), findsOneWidget);
      expect(find.text('37 visitas'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('profile_views')),
          matching: find.byIcon(Icons.visibility_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('MY_PROFILE_SINGULAR_AND_COMPACT', (tester) async {
      final one = _ViewsCommunity(profile: _profile(me: true, views: 1));
      await _pump(tester, _profilePage(_me, one), community: one);
      expect(find.text('1 visita'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      final many = _ViewsCommunity(profile: _profile(me: true, views: 2400));
      await _pump(tester, _profilePage(_me, many), community: many);
      expect(find.text('2.4 mil visitas'), findsOneWidget);
    });
  });

  group('themes', () {
    for (final entry in {'CREMA': false, 'NOCHE': true}.entries) {
      testWidgets('${entry.key}_VIEW_METRICS_USE_SEMANTIC_TOKENS', (
        tester,
      ) async {
        final theme = entry.value ? AppTheme.darkTheme : AppTheme.lightTheme;
        final colors = entry.value
            ? GarraSemanticColors.noche
            : GarraSemanticColors.crema;
        await _pump(
          tester,
          GarraSocialPostCard(post: _post('p', views: 42), onOpen: () {}),
          theme: theme,
        );
        expect(tester.widget<Icon>(_viewIcon).color, colors.textSecondary);
        expect(_textColor(tester, find.text('42')), colors.textSecondary);

        await tester.pumpWidget(const SizedBox());
        final community = _ViewsCommunity(
          profile: _profile(me: true, views: 5),
        );
        await _pump(
          tester,
          _profilePage(_me, community),
          community: community,
          theme: theme,
        );
        expect(
          _textColor(tester, find.text('5 visitas')),
          colors.textSecondary,
        );
        expect(colors.textSecondary, isNot(colors.surface));
      });
    }
  });
}
