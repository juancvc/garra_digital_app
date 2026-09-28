import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/auth/current_fan_provider.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/theme/garra_semantic_colors.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';
import 'package:garra_digital_app/features/clans/data/clan_admin_permissions.dart';
import 'package:garra_digital_app/features/clans/data/clan_models.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_bans_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_manage_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_members_admin_page.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_tribuna_page.dart';
import 'package:garra_digital_app/features/clans/presentation/providers/clans_provider.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/post_detail_screen.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';

import 'clans_foundation_test.dart' show FakeClanService, sampleClan;

// COMMUNITY_V2_B: members, roles, bans and clan content moderation.

const _slug = 'garra-surco';
const _owner = ClanMembershipSummary(role: 'OWNER', status: 'ACTIVE');
const _admin = ClanMembershipSummary(role: 'ADMIN', status: 'ACTIVE');
const _moderator = ClanMembershipSummary(role: 'MODERATOR', status: 'ACTIVE');
const _member = ClanMembershipSummary(role: 'MEMBER', status: 'ACTIVE');

final _members = [
  ClanMemberModel(
    username: 'duena',
    displayName: 'Ana Due\u00f1a',
    fanUserId: 'u-ana',
    role: 'OWNER',
    joinedAt: DateTime.utc(2026, 1, 10),
  ),
  ClanMemberModel(
    username: 'pepe',
    displayName: 'Pepe Admin',
    fanUserId: 'u-pepe',
    role: 'ADMIN',
    joinedAt: DateTime.utc(2026, 2, 10),
  ),
  ClanMemberModel(
    username: 'lucho',
    displayName: 'Lucho Mod',
    fanUserId: 'u-lucho',
    role: 'MODERATOR',
    joinedAt: DateTime.utc(2026, 3, 10),
  ),
  ClanMemberModel(
    username: 'maria',
    displayName: 'Mar\u00eda',
    fanUserId: 'u-maria',
    role: 'MEMBER',
    joinedAt: DateTime.utc(2026, 4, 10),
  ),
];

class _Fan extends CurrentFanNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _AdminClanService extends FakeClanService {
  _AdminClanService({
    super.detail,
    super.members,
    this.bans = const [],
    this.posts = const [],
  });

  List<ClanBanModel> bans;
  List<WallPostModel> posts;
  final List<String> calls = [];

  @override
  Future<void> updateMemberRole(
    String slug,
    String username,
    String role,
  ) async {
    calls.add('role:$username:$role');
  }

  @override
  Future<void> removeMember(String slug, String username) async {
    calls.add('remove:$username');
    members = members.where((m) => m.username != username).toList();
  }

  @override
  Future<void> banMember(String slug, String username, {String? reason}) async {
    calls.add('ban:$username:${reason ?? '-'}');
    members = members.where((m) => m.username != username).toList();
  }

  @override
  Future<void> transferOwnership(String slug, String username) async {
    calls.add('transfer:$username');
  }

  @override
  Future<List<ClanBanModel>> listBans(String slug) async => bans;

  @override
  Future<void> unban(String slug, String fanUserId) async {
    calls.add('unban:$fanUserId');
    bans = bans.where((b) => b.fanUserId != fanUserId).toList();
  }

  @override
  Future<ClanPage<WallPostModel>> getClanPosts(
    String slug, {
    String? cursor,
    int size = 20,
  }) async {
    return ClanPage(items: posts);
  }
}

Map<String, dynamic> _commentJson(String id, String authorId) => {
  'id': id,
  'postId': 'post-1',
  'username': 'otro',
  'fullName': 'Hincha Otro',
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

WallPostModel _clanPost() => WallPostModel.fromJson({
  'id': 'post-1',
  'username': 'otro',
  'fullName': 'Hincha Otro',
  'content': 'Arenga del clan',
  'status': 'ACTIVE',
  'createdAt': '2026-09-26T19:00:00Z',
  'reactionCount': 0,
  'commentCount': 1,
  'authorId': 'u-otro',
  'isMine': false,
  'contextType': 'CLAN',
  'clanSlug': _slug,
});

class _ModCommunity extends CommunityService {
  _ModCommunity() : super(dio: Dio());

  final List<String> calls = [];
  final post = _clanPost();

  @override
  Future<WallPostModel> getPost(String postId) async => post;

  @override
  Future<CommentsPageResult> listComments({
    required String postId,
    String? cursor,
    int size = 20,
  }) async => CommentsPageResult.fromJson({
    'items': [_commentJson('c1', 'u-otro')],
    'page': {'size': size, 'hasNext': false, 'nextCursor': null},
  });

  @override
  Future<CommentActionResult> hideClanPost({
    required String clanSlug,
    required String postId,
  }) async {
    calls.add('hidePost:$clanSlug:$postId');
    return CommentActionResult.success(message: 'Publicaci\u00f3n oculta');
  }

  @override
  Future<CommentActionResult> hideClanComment({
    required String clanSlug,
    required String postId,
    required String commentId,
  }) async {
    calls.add('hideComment:$clanSlug:$postId:$commentId');
    return CommentActionResult.success(message: 'Comentario oculto');
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  FakeClanService? clan,
  CommunityService? community,
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (clan != null) clanServiceProvider.overrideWithValue(clan),
        if (community != null)
          communityServiceProvider.overrideWith((ref) => community),
        currentFanProvider.overrideWith(_Fan.new),
      ],
      child: MaterialApp(theme: theme ?? AppTheme.darkTheme, home: home),
    ),
  );
  await tester.pumpAndSettle();
}

_AdminClanService _service(
  ClanMembershipSummary me, {
  List<ClanBanModel> bans = const [],
  List<WallPostModel> posts = const [],
}) => _AdminClanService(
  detail: sampleClan(slug: _slug, myMembership: me),
  members: _members,
  bans: bans,
  posts: posts,
);

Future<void> _openActions(WidgetTester tester, String username) async {
  await tester.tap(find.byKey(ValueKey('member_actions_$username')));
  await tester.pumpAndSettle();
}

Color? _textColor(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).text.style?.color;

void main() {
  group('permission helper (mirrors backend ClanPermissions)', () {
    test('OWNER_ACTIONS', () {
      expect(
        ClanAdminPermissions.actionsFor(actor: 'OWNER', target: 'MEMBER'),
        [
          ClanMemberAction.makeAdmin,
          ClanMemberAction.makeModerator,
          ClanMemberAction.remove,
          ClanMemberAction.ban,
          ClanMemberAction.transferOwnership,
        ],
      );
      expect(ClanAdminPermissions.actionsFor(actor: 'OWNER', target: 'ADMIN'), [
        ClanMemberAction.makeModerator,
        ClanMemberAction.makeMember,
        ClanMemberAction.remove,
        ClanMemberAction.ban,
        ClanMemberAction.transferOwnership,
      ]);
      expect(
        ClanAdminPermissions.actionsFor(actor: 'OWNER', target: 'OWNER'),
        isEmpty,
      );
    });

    test('ADMIN_ONLY_ALLOWED_ACTIONS', () {
      expect(
        ClanAdminPermissions.actionsFor(actor: 'ADMIN', target: 'MEMBER'),
        [
          ClanMemberAction.makeModerator,
          ClanMemberAction.remove,
          ClanMemberAction.ban,
        ],
      );
      expect(
        ClanAdminPermissions.actionsFor(actor: 'ADMIN', target: 'MODERATOR'),
        [
          ClanMemberAction.makeMember,
          ClanMemberAction.remove,
          ClanMemberAction.ban,
        ],
      );
      expect(
        ClanAdminPermissions.actionsFor(actor: 'ADMIN', target: 'ADMIN'),
        isEmpty,
      );
      expect(
        ClanAdminPermissions.actionsFor(actor: 'ADMIN', target: 'OWNER'),
        isEmpty,
      );
      expect(ClanAdminPermissions.canUnban('ADMIN'), isTrue);
    });

    test('MODERATOR_AND_MEMBER_HAVE_NO_MEMBERSHIP_ACTIONS', () {
      for (final target in ['OWNER', 'ADMIN', 'MODERATOR', 'MEMBER']) {
        expect(
          ClanAdminPermissions.actionsFor(actor: 'MODERATOR', target: target),
          isEmpty,
        );
        expect(
          ClanAdminPermissions.actionsFor(actor: 'MEMBER', target: target),
          isEmpty,
        );
      }
      expect(ClanAdminPermissions.canManageCommunity('MODERATOR'), isFalse);
      expect(ClanAdminPermissions.canViewBans('MODERATOR'), isFalse);
      expect(ClanAdminPermissions.canModerateContent('MODERATOR'), isTrue);
      expect(ClanAdminPermissions.canModerateContent('MEMBER'), isFalse);
      expect(sampleClan(myMembership: _moderator).canManage, isFalse);
      expect(sampleClan(myMembership: _member).canManage, isFalse);
    });

    test('SPANISH_ROLE_LABELS', () {
      expect(ClanRoleLabels.label('OWNER'), 'Propietario');
      expect(ClanRoleLabels.label('ADMIN'), 'Administrador');
      expect(ClanRoleLabels.label('MODERATOR'), 'Moderador');
      expect(ClanRoleLabels.label('MEMBER'), 'Miembro');
    });
  });

  group('member management', () {
    testWidgets('OWNER_SEES_MEMBER_MANAGEMENT', (tester) async {
      final service = _service(_owner);
      await _pump(tester, const ClanManagePage(slug: _slug), clan: service);
      expect(
        find.byKey(const ValueKey('manage_members_entry')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('manage_bans_entry')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('manage_members_entry')),
      );
      await tester.tap(find.byKey(const ValueKey('manage_members_entry')));
      await tester.pumpAndSettle();
      expect(find.byType(ClanMembersAdminPage), findsOneWidget);
      expect(find.text('Propietario'), findsOneWidget);
      expect(find.text('Administrador'), findsOneWidget);
      expect(find.text('Moderador'), findsOneWidget);
      expect(find.text('Miembro'), findsOneWidget);
      expect(find.byKey(const ValueKey('member_actions_duena')), findsNothing);

      await _openActions(tester, 'maria');
      for (final label in [
        'Hacer administrador',
        'Hacer moderador',
        'Expulsar',
        'Expulsar y bloquear',
        'Transferir propiedad',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Hacer miembro'), findsNothing);
      await tester.tap(find.text('Hacer moderador'));
      await tester.pumpAndSettle();
      expect(service.calls, contains('role:maria:MODERATOR'));
    });

    testWidgets('ADMIN_SEES_ONLY_ALLOWED_ACTIONS', (tester) async {
      await _pump(
        tester,
        const ClanMembersAdminPage(slug: _slug),
        clan: _service(_admin),
      );
      expect(find.byKey(const ValueKey('member_actions_duena')), findsNothing);
      expect(find.byKey(const ValueKey('member_actions_pepe')), findsNothing);
      await _openActions(tester, 'maria');
      expect(find.text('Hacer moderador'), findsOneWidget);
      expect(find.text('Expulsar'), findsOneWidget);
      expect(find.text('Expulsar y bloquear'), findsOneWidget);
      expect(find.text('Hacer administrador'), findsNothing);
      expect(find.text('Transferir propiedad'), findsNothing);
    });

    testWidgets('MODERATOR_SEES_NO_MEMBERSHIP_ACTIONS', (tester) async {
      await _pump(
        tester,
        const ClanMembersAdminPage(slug: _slug),
        clan: _service(_moderator),
      );
      expect(find.text('Acceso restringido'), findsOneWidget);
      expect(find.byKey(const ValueKey('member_actions_maria')), findsNothing);
    });

    testWidgets('MEMBER_SEES_NO_ADMIN', (tester) async {
      await _pump(
        tester,
        const ClanBansPage(slug: _slug),
        clan: _service(_member),
      );
      expect(find.text('Acceso restringido'), findsOneWidget);
      expect(find.textContaining('Quitar bloqueo'), findsNothing);
    });

    testWidgets('CONFIRM_EXPULSAR', (tester) async {
      final service = _service(_owner);
      await _pump(
        tester,
        const ClanMembersAdminPage(slug: _slug),
        clan: service,
      );
      await _openActions(tester, 'maria');
      await tester.tap(find.text('Expulsar'));
      await tester.pumpAndSettle();
      expect(find.text('\u00bfExpulsar a Mar\u00eda?'), findsOneWidget);
      expect(find.text('Podr\u00e1 volver a unirse.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('clan_confirm_cancel')));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);

      await _openActions(tester, 'maria');
      await tester.tap(find.text('Expulsar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('clan_confirm_accept')));
      await tester.pumpAndSettle();
      expect(service.calls, ['remove:maria']);
      expect(find.text('Mar\u00eda'), findsNothing);
    });

    testWidgets('CONFIRM_EXPULSAR_Y_BLOQUEAR_WITH_REASON', (tester) async {
      final service = _service(_owner);
      await _pump(
        tester,
        const ClanMembersAdminPage(slug: _slug),
        clan: service,
      );
      await _openActions(tester, 'maria');
      await tester.tap(find.text('Expulsar y bloquear'));
      await tester.pumpAndSettle();
      expect(
        find.text('\u00bfExpulsar y bloquear a Mar\u00eda?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'No podr\u00e1 volver a unirse ni solicitar ingreso hasta que quites el bloqueo.',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('clan_ban_reason')),
        'Insultos',
      );
      await tester.tap(find.byKey(const ValueKey('clan_confirm_accept')));
      await tester.pumpAndSettle();
      expect(service.calls, ['ban:maria:Insultos']);
    });

    testWidgets('CONFIRM_TRANSFER', (tester) async {
      final service = _service(_owner);
      await _pump(
        tester,
        const ClanMembersAdminPage(slug: _slug),
        clan: service,
      );
      await _openActions(tester, 'pepe');
      await tester.tap(find.text('Transferir propiedad'));
      await tester.pumpAndSettle();
      expect(
        find.text('\u00bfTransferir la propiedad a Pepe Admin?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('clan_confirm_accept')));
      await tester.pumpAndSettle();
      expect(service.calls, ['transfer:pepe']);
    });
  });

  group('blocked people', () {
    final ban = ClanBanModel(
      fanUserId: 'u-maria',
      username: 'maria',
      displayName: 'Mar\u00eda',
      reason: 'Spam',
      createdAt: DateTime.utc(2026, 9, 20, 12),
      bannedByDisplayName: 'Ana Due\u00f1a',
    );

    testWidgets('BLOCKED_LIST_AND_QUITAR_BLOQUEO', (tester) async {
      final service = _service(_admin, bans: [ban]);
      await _pump(tester, const ClanBansPage(slug: _slug), clan: service);
      expect(find.text('Mar\u00eda'), findsOneWidget);
      expect(find.text('Motivo: Spam'), findsOneWidget);
      expect(find.textContaining('por Ana Due\u00f1a'), findsOneWidget);
      expect(find.textContaining('Bloqueado el 20/09/2026'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('unban_u-maria')));
      await tester.pumpAndSettle();
      expect(
        find.text('\u00bfQuitar el bloqueo a Mar\u00eda?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('clan_confirm_accept')));
      await tester.pumpAndSettle();
      expect(service.calls, ['unban:u-maria']);
      expect(find.text('No hay personas bloqueadas.'), findsOneWidget);
    });
  });

  group('content moderation', () {
    testWidgets('MODERATOR_SEES_OCULTAR_PUBLICACION', (tester) async {
      final community = _ModCommunity();
      await _pump(
        tester,
        const ClanTribunaPage(slug: _slug),
        clan: _service(_moderator, posts: [_clanPost()]),
        community: community,
      );
      await tester.tap(find.byKey(const ValueKey('clan_post_menu_post-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ocultar publicaci\u00f3n'));
      await tester.pumpAndSettle();
      expect(find.text('\u00bfOcultar esta publicaci\u00f3n?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('post_hide_confirm')));
      await tester.pumpAndSettle();
      expect(community.calls, ['hidePost:$_slug:post-1']);
    });

    testWidgets('MEMBER_DOES_NOT_SEE_OCULTAR_PUBLICACION', (tester) async {
      await _pump(
        tester,
        const ClanTribunaPage(slug: _slug),
        clan: _service(_member, posts: [_clanPost()]),
        community: _ModCommunity(),
      );
      expect(find.text('Arenga del clan'), findsOneWidget);
      expect(find.byKey(const ValueKey('clan_post_menu_post-1')), findsNothing);
    });

    testWidgets('MODERATOR_SEES_OCULTAR_COMENTARIO', (tester) async {
      final community = _ModCommunity();
      await _pump(
        tester,
        const PostDetailScreen(
          postId: 'post-1',
          moderation: PostDetailModeration(clanSlug: _slug),
        ),
        community: community,
      );
      await tester.tap(find.byKey(const ValueKey('comment_menu_c1')));
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsNothing);
      await tester.tap(find.text('Ocultar comentario'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('comment_hide_confirm')));
      await tester.pumpAndSettle();
      expect(community.calls, ['hideComment:$_slug:post-1:c1']);
      expect(find.text('Comentario c1'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('post_detail_menu')));
      await tester.pumpAndSettle();
      expect(find.text('Ocultar publicaci\u00f3n'), findsOneWidget);
      expect(find.text('Eliminar publicaci\u00f3n'), findsNothing);
    });

    testWidgets('MEMBER_DOES_NOT_SEE_OCULTAR_COMENTARIO', (tester) async {
      await _pump(
        tester,
        const PostDetailScreen(postId: 'post-1'),
        community: _ModCommunity(),
      );
      expect(find.text('Comentario c1'), findsOneWidget);
      expect(find.byKey(const ValueKey('comment_menu_c1')), findsNothing);
      expect(find.byKey(const ValueKey('post_detail_menu')), findsNothing);
    });
  });

  group('theme', () {
    testWidgets('CREMA_READABLE', (tester) async {
      const crema = GarraSemanticColors.crema;
      await _pump(
        tester,
        const ClanMembersAdminPage(slug: _slug),
        clan: _service(_owner),
        theme: AppTheme.lightTheme,
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, crema.background);
      expect(_textColor(tester, find.text('Mar\u00eda')), crema.textPrimary);
      expect(_textColor(tester, find.text('@maria')), crema.textSecondary);
      expect(_textColor(tester, find.text('Miembro')), crema.brandPrestige);
    });

    testWidgets('NOCHE_READABLE', (tester) async {
      const noche = GarraSemanticColors.noche;
      await _pump(
        tester,
        const ClanBansPage(slug: _slug),
        clan: _service(
          _owner,
          bans: [
            ClanBanModel(
              fanUserId: 'u-maria',
              username: 'maria',
              displayName: 'Mar\u00eda',
              createdAt: DateTime.utc(2026, 9, 20, 12),
            ),
          ],
        ),
        theme: AppTheme.darkTheme,
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, noche.background);
      expect(_textColor(tester, find.text('Mar\u00eda')), noche.textPrimary);
      expect(_textColor(tester, find.text('@maria')), noche.textSecondary);
    });
  });
}
