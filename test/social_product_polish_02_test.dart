import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/utils/country_labels.dart';
import 'package:garra_digital_app/features/chat/data/chat_models.dart';
import 'package:garra_digital_app/features/clans/data/clan_models.dart';
import 'package:garra_digital_app/features/clans/data/clan_service.dart';
import 'package:garra_digital_app/features/clans/presentation/clan_detail_page.dart';
import 'package:garra_digital_app/features/clans/presentation/providers/clans_provider.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/create_community_post_page.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';
import 'package:garra_digital_app/features/passport/data/passport_models.dart';
import 'package:garra_digital_app/features/passport/presentation/profile_edit_screen.dart';
import 'package:garra_digital_app/features/passport/presentation/providers/passport_provider.dart';

void main() {
  test('spanish labels stay off raw enums', () {
    expect(countryName('PE'), 'Perú');
    expect(clanVisibilityLabel('PUBLIC'), 'Pública');
    expect(clanVisibilityLabel('PRIVATE'), 'Privada');
    expect(
      const ChatConversation(
        id: '1',
        otherUserId: '2',
        otherDisplayName: 'Ana',
        status: 'PENDING',
      ).statusLabel,
      'Pendiente',
    );
    expect(
      const ChatConversation(
        id: '1',
        otherUserId: '2',
        otherDisplayName: 'Ana',
        status: 'REJECTED',
      ).statusLabel,
      'Rechazado',
    );
  });

  test('comment parses avatar and author', () {
    final comment = WallCommentModel.fromJson({
      'id': 'c1',
      'postId': 'p1',
      'username': 'ana',
      'fullName': 'Ana',
      'content': 'Hola',
      'createdAt': '2026-09-25T07:00:00Z',
      'avatarUrl': 'https://cdn/a.jpg',
      'authorId': 'user-1',
    });
    expect(comment.avatarUrl, 'https://cdn/a.jpg');
    expect(comment.authorId, 'user-1');
  });

  testWidgets('profile edit offers photo and country name', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPassportProvider.overrideWith((ref) async => _passport()),
        ],
        child: const MaterialApp(home: ProfileEditScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cambiar foto'), findsOneWidget);
    expect(find.text('País'), findsOneWidget);
    expect(find.text('Perú'), findsOneWidget);
    expect(find.text('País (ISO-2)'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Visibilidad'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Público'), findsOneWidget);
    final year = find.byKey(const Key('profile-supporter-year'));
    await tester.ensureVisible(year);
    await tester.enterText(year, '1800');
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    expect(find.text('Año no válido'), findsOneWidget);
  });

  testWidgets('composer offers gallery and camera wording', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateCommunityPostPage())),
    );
    await tester.pump();
    await tester.tap(find.text('Agregar fotos'));
    await tester.pumpAndSettle();
    expect(find.text('Elegir de galería'), findsOneWidget);
    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Adjuntar archivos'), findsNothing);
  });

  testWidgets('delete confirmation is spanish and destructive', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmAndDeletePublication(
                context: context,
                delete: () async {
                  deleted = true;
                },
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar publicación?'), findsOneWidget);
    expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('community opens on publicaciones and lists members', (
    tester,
  ) async {
    final service = _CommunityFake(
      members: [
        const ClanMemberModel(
          username: 'ana',
          displayName: 'Ana Quispe',
          fanUserId: 'user-1',
          role: 'MEMBER',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clanServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: ClanDetailPage(slug: 'cremas-surco')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Publicaciones'), findsOneWidget);
    expect(find.text('Cremas de Surco'), findsWidgets);
    expect(find.textContaining('Pública'), findsWidgets);
    expect(find.text('Unido ✓'), findsOneWidget);
    await tester.tap(find.text('Miembros'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Quispe'), findsOneWidget);
    expect(find.text('@ana'), findsOneWidget);
    expect(find.text('Seguir'), findsOneWidget);
    await tester.tap(find.text('Información'));
    await tester.pumpAndSettle();
    expect(find.text('Perú'), findsOneWidget);
    expect(find.text('PUBLIC'), findsNothing);
  });

  testWidgets('members empty and error resolve', (tester) async {
    final empty = _CommunityFake(members: const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clanServiceProvider.overrideWithValue(empty)],
        child: const MaterialApp(home: ClanDetailPage(slug: 'cremas-surco')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Miembros'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay miembros'), findsOneWidget);

    final failing = _CommunityFake(members: const [], failMembers: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clanServiceProvider.overrideWithValue(failing)],
        child: const MaterialApp(home: ClanDetailPage(slug: 'cremas-surco')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Miembros'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
  });
}

PassportModel _passport() {
  return const PassportModel(
    identity: PassportIdentity(
      username: 'ana',
      displayName: 'Ana Quispe',
      countryCode: 'PE',
      city: 'Lima',
    ),
    level: PassportLevel(
      number: 1,
      name: 'Hincha',
      points: 0,
      levelMinPoints: 0,
      progressPercent: 0,
      pointsToNextLevel: 10,
    ),
    stats: PassportStats(
      checkIns: 0,
      predictions: 0,
      predictionPoints: 0,
      posts: 0,
      streakCurrent: 0,
      streakBest: 0,
    ),
    globalRank: null,
    profileVisibility: 'PUBLIC',
    viewerIsOwner: true,
  );
}

class _CommunityFake extends ClanService {
  _CommunityFake({required this.members, this.failMembers = false})
    : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost')));

  final List<ClanMemberModel> members;
  final bool failMembers;

  @override
  Future<ClanModel> getClan(String slug) async {
    return const ClanModel(
      id: 'c1',
      slug: 'cremas-surco',
      name: 'Cremas de Surco',
      description: 'Barrio crema',
      city: 'Lima',
      countryCode: 'PE',
      visibility: 'PUBLIC',
      joinPolicy: 'OPEN',
      status: 'ACTIVE',
      memberCount: 2,
      myMembership: ClanMembershipSummary(role: 'MEMBER', status: 'ACTIVE'),
    );
  }

  @override
  Future<ClanPage<WallPostModel>> getClanPosts(
    String slug, {
    String? cursor,
    int size = 20,
  }) async {
    return ClanPage(items: const []);
  }

  @override
  Future<ClanPage<ClanMemberModel>> getMembers(
    String slug, {
    String? cursor,
    int size = 20,
  }) async {
    if (failMembers) throw Exception('boom');
    return ClanPage(items: members);
  }
}
