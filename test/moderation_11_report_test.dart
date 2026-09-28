import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/chat/data/chat_service.dart';
import 'package:garra_digital_app/features/clans/data/clan_models.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_tribuna_page.dart';
import 'package:garra_digital_app/features/clans/presentation/providers/clans_provider.dart';
import 'package:garra_digital_app/features/community/data/community_report.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/public_fan_profile_page.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_report_sheet.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';

import 'clans_foundation_test.dart' show FakeClanService, sampleClan;

// MODERATION_11: platform reports (post, comment, profile).

const _me = 'u-me';
const _other = 'u-otro';
const _slug = 'garra-surco';

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

WallPostModel _post({required String authorId, bool clan = false}) =>
    WallPostModel.fromJson({
      'id': 'post-1',
      'username': 'autor',
      'fullName': 'Hincha Autor',
      'content': 'Arenga crema',
      'status': 'ACTIVE',
      'createdAt': '2026-09-26T19:00:00Z',
      'reactionCount': 0,
      'commentCount': 2,
      'authorId': authorId,
      'isMine': authorId == _me,
      if (clan) 'contextType': 'CLAN',
      if (clan) 'clanSlug': _slug,
    });

Map<String, dynamic> _commentJson(String id, String authorId) => {
  'id': id,
  'postId': 'post-1',
  'username': 'autor',
  'fullName': 'Hincha Autor',
  'content': 'Comentario $id',
  'status': 'ACTIVE',
  'createdAt': '2026-09-26T20:00:00Z',
  'authorId': authorId,
  'reactionCount': 0,
  'reactionSummary': const <String, int>{},
  'myReaction': null,
  'parentCommentId': null,
  'replyCount': 0,
};

class _ReportCall {
  _ReportCall(this.target, this.targetId, this.reason, this.detail);

  final GarraReportTarget target;
  final String targetId;
  final String reason;
  final String? detail;
}

class _ReportCommunity extends CommunityService {
  _ReportCommunity({
    String postAuthor = _other,
    this.profile,
    bool clan = false,
  }) : post = _post(authorId: postAuthor, clan: clan),
       super(dio: Dio());

  final WallPostModel post;
  final Map<String, dynamic>? profile;
  final List<_ReportCall> reports = [];
  Completer<ReportSubmitResult>? pending;
  ReportSubmitResult result = ReportSubmitResult.success();

  @override
  Future<WallPostModel> getPost(String postId) async => post;

  @override
  Future<CommentsPageResult> listComments({
    required String postId,
    String? cursor,
    int size = 20,
  }) async => CommentsPageResult.fromJson({
    'items': [_commentJson('c-mine', _me), _commentJson('c-other', _other)],
    'page': {'size': size, 'hasNext': false, 'nextCursor': null},
  });

  @override
  Future<Map<String, dynamic>> getPublicProfile(String userId) async =>
      profile ?? const {};

  @override
  Future<ReportSubmitResult> createReport({
    required GarraReportTarget target,
    required String targetId,
    required String reason,
    String? detail,
  }) {
    reports.add(_ReportCall(target, targetId, reason, detail));
    return pending?.future ?? Future.value(result);
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

class _TribunaClanService extends FakeClanService {
  _TribunaClanService({super.detail, this.posts = const []});

  final List<WallPostModel> posts;

  @override
  Future<ClanPage<WallPostModel>> getClanPosts(
    String slug, {
    String? cursor,
    int size = 20,
  }) async => ClanPage(items: posts);
}

Map<String, dynamic> _profile({required bool me}) => {
  'displayName': me ? 'T\u00fa' : 'Mar\u00eda Quispe',
  'username': me ? 'yo' : 'mariaquispe',
  'followerCount': 4,
  'followingCount': 2,
  'globalPostCount': 0,
  'isFollowedByMe': false,
  'isBlockedByMe': false,
  'isMe': me,
  'globalPosts': <dynamic>[],
};

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  CommunityService? community,
  FakeClanService? clan,
  String fanId = _me,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (community != null)
          communityServiceProvider.overrideWith((ref) => community),
        if (clan != null) clanServiceProvider.overrideWithValue(clan),
        currentFanProvider.overrideWith(() => _FanAs(fanId)),
      ],
      child: MaterialApp(theme: theme ?? AppTheme.darkTheme, home: home),
    ),
  );
  await tester.pumpAndSettle();
}

/// Host page with a button that opens the shared report sheet.
Future<void> _pumpSheetHost(
  WidgetTester tester,
  _ReportCommunity community, {
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('open_report'),
              onPressed: () => showGarraReportSheet(
                context,
                service: community,
                target: GarraReportTarget.post,
                targetId: 'post-1',
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open_report')));
  await tester.pumpAndSettle();
}

Future<void> _openCommentMenu(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('comment_menu_$id')));
  await tester.pumpAndSettle();
}

Color? _textColor(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).text.style?.color;

void main() {
  group('post report entry points', () {
    testWidgets('FEED_CARD_OTHERS_POST_SHOWS_DENUNCIAR', (tester) async {
      var reported = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: GarraSocialPostCard(
              post: _post(authorId: _other),
              onOpen: () {},
              onReport: () => reported++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Denunciar publicaci\u00f3n'));
      await tester.pumpAndSettle();
      expect(reported, 1);
    });

    testWidgets('FEED_CARD_OWN_POST_HIDES_DENUNCIAR', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: GarraSocialPostCard(
              post: _post(authorId: _me),
              onOpen: () {},
              onReport: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar publicaci\u00f3n'), findsOneWidget);
      expect(find.text('Denunciar publicaci\u00f3n'), findsNothing);
    });

    testWidgets('POST_DETAIL_OTHERS_POST_REPORTS_POST_TARGET', (tester) async {
      final community = _ReportCommunity();
      await _pump(
        tester,
        const PostDetailScreen(postId: 'post-1'),
        community: community,
      );
      await tester.tap(find.byKey(const ValueKey('post_detail_menu')));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar publicaci\u00f3n'), findsNothing);
      await tester.tap(find.text('Denunciar publicaci\u00f3n'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report_reason_SPAM')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_submit')));
      await tester.pumpAndSettle();
      expect(community.reports, hasLength(1));
      expect(community.reports.single.target, GarraReportTarget.post);
      expect(community.reports.single.targetId, 'post-1');
      expect(community.reports.single.reason, 'SPAM');
    });

    testWidgets('POST_DETAIL_OWN_POST_HIDES_DENUNCIAR', (tester) async {
      await _pump(
        tester,
        const PostDetailScreen(postId: 'post-1'),
        community: _ReportCommunity(postAuthor: _me),
      );
      await tester.tap(find.byKey(const ValueKey('post_detail_menu')));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar publicaci\u00f3n'), findsOneWidget);
      expect(find.text('Denunciar publicaci\u00f3n'), findsNothing);
    });

    testWidgets('CLAN_TRIBUNA_CARD_MEMBER_SEES_ONLY_DENUNCIAR', (tester) async {
      await _pump(
        tester,
        const ClanTribunaPage(slug: _slug),
        community: _ReportCommunity(clan: true),
        clan: _TribunaClanService(
          detail: sampleClan(
            slug: _slug,
            myMembership: const ClanMembershipSummary(
              role: 'MEMBER',
              status: 'ACTIVE',
            ),
          ),
          posts: [_post(authorId: _other, clan: true)],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('clan_post_menu_post-1')));
      await tester.pumpAndSettle();
      expect(find.text('Denunciar publicaci\u00f3n'), findsOneWidget);
      expect(find.text('Ocultar publicaci\u00f3n'), findsNothing);
    });

    testWidgets('CLAN_TRIBUNA_CARD_OWN_POST_HAS_NO_REPORT', (tester) async {
      await _pump(
        tester,
        const ClanTribunaPage(slug: _slug),
        community: _ReportCommunity(clan: true, postAuthor: _me),
        clan: _TribunaClanService(
          detail: sampleClan(
            slug: _slug,
            myMembership: const ClanMembershipSummary(
              role: 'MEMBER',
              status: 'ACTIVE',
            ),
          ),
          posts: [_post(authorId: _me, clan: true)],
        ),
      );
      expect(find.text('Arenga crema'), findsOneWidget);
      expect(find.byKey(const ValueKey('clan_post_menu_post-1')), findsNothing);
    });
  });

  group('comment report', () {
    testWidgets('OTHERS_COMMENT_SHOWS_DENUNCIAR_COMENTARIO', (tester) async {
      final community = _ReportCommunity();
      await _pump(
        tester,
        const PostDetailScreen(postId: 'post-1'),
        community: community,
      );
      await _openCommentMenu(tester, 'c-other');
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Ocultar comentario'), findsNothing);
      await tester.tap(find.text('Denunciar comentario'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_reason_HARASSMENT')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_submit')));
      await tester.pumpAndSettle();
      expect(community.reports.single.target, GarraReportTarget.comment);
      expect(community.reports.single.targetId, 'c-other');
      expect(community.reports.single.reason, 'HARASSMENT');
    });

    testWidgets('OWN_COMMENT_HIDES_DENUNCIAR_COMENTARIO', (tester) async {
      await _pump(
        tester,
        const PostDetailScreen(postId: 'post-1'),
        community: _ReportCommunity(),
      );
      await _openCommentMenu(tester, 'c-mine');
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      expect(find.text('Denunciar comentario'), findsNothing);
    });

    testWidgets('MODERATOR_SEES_OCULTAR_AND_DENUNCIAR_COMENTARIO', (
      tester,
    ) async {
      await _pump(
        tester,
        const PostDetailScreen(
          postId: 'post-1',
          moderation: PostDetailModeration(clanSlug: _slug),
        ),
        community: _ReportCommunity(clan: true),
        fanId: 'u-lucho',
      );
      await _openCommentMenu(tester, 'c-other');
      expect(find.text('Ocultar comentario'), findsOneWidget);
      expect(find.text('Denunciar comentario'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
    });
  });

  group('profile report', () {
    testWidgets('OTHERS_PROFILE_SHOWS_DENUNCIAR_PERFIL', (tester) async {
      final community = _ReportCommunity(profile: _profile(me: false));
      await _pump(
        tester,
        PublicFanProfilePage(
          userId: 'fan-2',
          communityService: community,
          chatService: _FakeChat(),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('profile_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Denunciar perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Denunciar perfil'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('report_reason_IMPERSONATION')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_submit')));
      await tester.pumpAndSettle();
      expect(community.reports.single.target, GarraReportTarget.profile);
      expect(community.reports.single.targetId, 'fan-2');
      expect(community.reports.single.reason, 'IMPERSONATION');
      expect(find.text(garraReportThanksMessage), findsOneWidget);
    });

    testWidgets('OWN_PROFILE_HAS_NO_REPORT_MENU', (tester) async {
      await _pump(
        tester,
        PublicFanProfilePage(
          userId: _me,
          communityService: _ReportCommunity(profile: _profile(me: true)),
          chatService: _FakeChat(),
        ),
      );
      expect(find.text('Editar perfil'), findsWidgets);
      expect(find.byKey(const ValueKey('profile_menu')), findsNothing);
      expect(find.text('Denunciar perfil'), findsNothing);
    });
  });

  group('report sheet', () {
    testWidgets('SHOWS_REASON_CATALOG_WITH_48DP_TAPS', (tester) async {
      await _pumpSheetHost(tester, _ReportCommunity());
      expect(garraReportReasons, hasLength(10));
      for (final label in const [
        'Spam',
        'Contenido no apropiado',
        'Acoso u hostigamiento',
        'Violencia o amenazas',
        'Odio o discriminaci\u00f3n',
        'Terrorismo o extremismo',
        'Estafa o fraude',
        'Suplantaci\u00f3n de identidad',
        'Informaci\u00f3n personal',
        'Otro',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      for (final reason in garraReportReasons) {
        final size = tester.getSize(
          find.byKey(ValueKey('report_reason_${reason.code}')),
        );
        expect(size.height, greaterThanOrEqualTo(48));
      }
      final submit = tester.widget<FilledButton>(
        find.byKey(const ValueKey('report_submit')),
      );
      expect(submit.onPressed, isNull);
      expect(find.byKey(const ValueKey('report_detail_field')), findsNothing);
    });

    testWidgets('DETAIL_IS_OPTIONAL_AND_SENT_WHEN_WRITTEN', (tester) async {
      final community = _ReportCommunity();
      await _pumpSheetHost(tester, community);
      await tester.tap(find.byKey(const ValueKey('report_reason_OTHER')));
      await tester.pumpAndSettle();
      expect(find.text('Cu\u00e9ntanos un poco m\u00e1s'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('report_detail_field')),
      );
      expect(field.maxLength, 500);
      await tester.tap(find.byKey(const ValueKey('report_submit')));
      await tester.pumpAndSettle();
      expect(community.reports.single.reason, 'OTHER');
      expect(community.reports.single.detail ?? '', isEmpty);

      await tester.tap(find.byKey(const ValueKey('open_report')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_reason_SPAM')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('report_detail_field')),
        'Publica enlaces falsos',
      );
      await tester.tap(find.byKey(const ValueKey('report_submit')));
      await tester.pumpAndSettle();
      expect(community.reports.last.detail, 'Publica enlaces falsos');
    });

    testWidgets('LOADING_PREVENTS_DOUBLE_SUBMIT', (tester) async {
      final community = _ReportCommunity()
        ..pending = Completer<ReportSubmitResult>();
      await _pumpSheetHost(tester, community);
      await tester.tap(find.byKey(const ValueKey('report_reason_SPAM')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_submit')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('report_submit')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(community.reports, hasLength(1));
      community.pending!.complete(ReportSubmitResult.success());
      await tester.pumpAndSettle();
      expect(community.reports, hasLength(1));
    });

    testWidgets('SUCCESS_CLOSES_SHEET_WITH_SNACKBAR', (tester) async {
      await _pumpSheetHost(tester, _ReportCommunity());
      await tester.tap(find.byKey(const ValueKey('report_reason_FRAUD')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report_sheet')), findsNothing);
      expect(find.text('Gracias. Revisaremos tu denuncia.'), findsOneWidget);
    });

    testWidgets('BACKEND_ERROR_KEEPS_SHEET_OPEN_WITH_MESSAGE', (tester) async {
      final community = _ReportCommunity()
        ..result = ReportSubmitResult.failure('Ya denunciaste este contenido.');
      await _pumpSheetHost(tester, community);
      await tester.tap(find.byKey(const ValueKey('report_reason_SPAM')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report_sheet')), findsOneWidget);
      expect(find.text('Ya denunciaste este contenido.'), findsOneWidget);
      expect(find.text(garraReportThanksMessage), findsNothing);
      final submit = tester.widget<FilledButton>(
        find.byKey(const ValueKey('report_submit')),
      );
      expect(submit.onPressed, isNotNull);
    });
  });

  group('service', () {
    test('CREATE_REPORT_SENDS_PAYLOAD_AND_MAPS_BACKEND_MESSAGE', () async {
      RequestOptions? sent;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              sent = options;
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 400,
                    data: {'message': 'Ya denunciaste este contenido.'},
                  ),
                ),
              );
            },
          ),
        );
      final result = await CommunityService(dio: dio).createReport(
        target: GarraReportTarget.comment,
        targetId: 'c-1',
        reason: 'HATE',
        detail: '  insultos  ',
      );
      expect(sent!.path, '/community/reports');
      expect(sent!.data, {
        'targetType': 'COMMENT',
        'targetId': 'c-1',
        'reason': 'HATE',
        'detail': 'insultos',
      });
      expect(result.success, isFalse);
      expect(result.message, 'Ya denunciaste este contenido.');
    });
  });

  group('theme', () {
    testWidgets('CREMA_READABLE', (tester) async {
      const crema = GarraSemanticColors.crema;
      await _pumpSheetHost(
        tester,
        _ReportCommunity(),
        theme: AppTheme.lightTheme,
      );
      expect(
        _textColor(tester, find.text('Denunciar publicaci\u00f3n')),
        crema.textPrimary,
      );
      expect(
        _textColor(
          tester,
          find.text('\u00bfPor qu\u00e9 quieres denunciar esto?'),
        ),
        crema.textSecondary,
      );
      expect(_textColor(tester, find.text('Spam')), crema.textPrimary);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, crema.surface);
    });

    testWidgets('NOCHE_READABLE', (tester) async {
      const noche = GarraSemanticColors.noche;
      final community = _ReportCommunity()
        ..result = ReportSubmitResult.failure('Ya denunciaste este contenido.');
      await _pumpSheetHost(tester, community, theme: AppTheme.darkTheme);
      expect(
        _textColor(tester, find.text('Denunciar publicaci\u00f3n')),
        noche.textPrimary,
      );
      expect(_textColor(tester, find.text('Spam')), noche.textPrimary);
      await tester.tap(find.byKey(const ValueKey('report_reason_SPAM')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_submit')));
      await tester.pumpAndSettle();
      expect(
        _textColor(tester, find.byKey(const ValueKey('report_error'))),
        noche.danger,
      );
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, noche.surface);
    });
  });
}
