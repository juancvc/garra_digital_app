import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/config/app_config_service.dart';
import 'package:garra_digital_app/core/widgets/app_gates.dart';
import 'package:garra_digital_app/core/widgets/garra_cached_network_image.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/community_social_page.dart';
import 'package:garra_digital_app/features/community/presentation/providers/community_provider.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_post_media_grid.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';
import 'package:garra_digital_app/features/admin/data/admin_center_service.dart';
import 'package:garra_digital_app/features/admin/presentation/admin_center_page.dart';
import 'package:garra_digital_app/features/auth/data/auth_service.dart';
import 'package:garra_digital_app/features/auth/data/auth_user.dart';

Map<String, dynamic> _backendPost({
  required String id,
  required List<Map<String, dynamic>> media,
}) {
  return {
    'id': id,
    'username': 'maria.crema',
    'fullName': 'María Ríos',
    'content': 'La pasión reúne generaciones en Perú.',
    'locationTag': 'Surco',
    'status': 'PUBLISHED',
    'createdAt': '2026-09-24T12:00:00Z',
    'reactionCount': 8,
    'commentCount': 2,
    'media': media,
  };
}

Map<String, dynamic> _photo(int index) => {
  'id': 'association-$index',
  'mediaAssetId': 'asset-$index',
  'url': 'https://cdn.garra.test/posts/photo-$index.jpg',
  'sortOrder': index,
};

class _FeedService extends CommunityService {
  _FeedService(this.posts);

  final List<WallPostModel> posts;

  @override
  Future<List<WallPostModel>> getGlobalFeed({String mode = 'RECENT'}) async {
    expect(mode, 'RECENT');
    return posts;
  }
}

class _AuthService extends AuthService {
  _AuthService(this.user);

  final AuthUser? user;

  @override
  Future<AuthUser?> me() async => user;
}

class _AdminService extends AdminCenterService {
  @override
  Future<StagingShowcasePreview> stagingShowcasePreview() async {
    return const StagingShowcasePreview(
      communities: 6,
      sellers: 8,
      stores: 8,
      listings: 18,
      mojibakeRecords: 4,
    );
  }
}

AppConfigModel _config(String environment) => AppConfigModel(
  environment: environment,
  maintenanceMode: false,
  minimumSupportedVersion: '1.0.0',
  latestVersion: '1.0.0',
  features: const {},
);

void main() {
  test('mobile showcase-visible source contains no mojibake markers', () {
    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in sourceFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(
          anyOf(contains('Ã'), contains('Â'), contains('ƒ'), contains('�')),
        ),
        reason: file.path,
      );
    }
  });

  test('realistic backend feed preserves media contract and ordering', () {
    final one = WallPostModel.fromJson(
      _backendPost(id: 'post-1', media: [_photo(0)]),
    );
    final two = WallPostModel.fromJson(
      _backendPost(id: 'post-2', media: [_photo(1), _photo(0)]),
    );

    expect(one.media.single.mediaAssetId, 'asset-0');
    expect(one.media.single.url, endsWith('photo-0.jpg'));
    expect(two.media, hasLength(2));
    expect(two.media.first.sortOrder, 1);
  });

  testWidgets('one-photo social post renders a large editorial image', (
    tester,
  ) async {
    final post = WallPostModel.fromJson(
      _backendPost(id: 'post-1', media: [_photo(0)]),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: GarraSocialPostCard(post: post, onOpen: () {}),
          ),
        ),
      ),
    );

    expect(find.byType(GarraPostMediaGrid), findsOneWidget);
    expect(find.byType(GarraCachedNetworkImage), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AspectRatio && widget.aspectRatio == 4 / 3,
      ),
      findsOneWidget,
    );
  });

  testWidgets('two-photo social post renders the split grid', (tester) async {
    final post = WallPostModel.fromJson(
      _backendPost(id: 'post-2', media: [_photo(0), _photo(1)]),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: GarraSocialPostCard(post: post, onOpen: () {}),
          ),
        ),
      ),
    );

    expect(find.byType(GarraCachedNetworkImage), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AspectRatio && widget.aspectRatio == 16 / 9,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Community root is a recent social feed without a back arrow', (
    tester,
  ) async {
    final post = WallPostModel.fromJson(
      _backendPost(id: 'post-1', media: [_photo(0)]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityServiceProvider.overrideWithValue(_FeedService([post])),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const CommunitySocialPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Comunidad'), findsOneWidget);
    expect(find.byType(GarraSocialPostCard), findsOneWidget);
    expect(find.byType(GarraPostMediaGrid), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.groups_2_outlined), findsOneWidget);
  });

  testWidgets('optional update is compact and does not require Overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      Theme(
        data: AppTheme.darkTheme,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topCenter,
            child: OptionalUpdateBanner(
              latestVersion: '1.0.1',
              onDismiss: () {},
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(OptionalUpdateBanner));
    expect(size.height, 42);
    expect(find.byType(Overlay), findsNothing);
  });

  testWidgets('staging activation is hidden outside staging', (tester) async {
    const admin = AuthUser(
      userId: 'admin-1',
      email: 'admin@example.com',
      username: 'admin',
      fullName: 'Admin',
      status: 'ACTIVE',
      role: 'ADMIN',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProviderScope(
          child: AdminCenterPage(
            authService: _AuthService(admin),
            adminService: _AdminService(),
            appConfig: _config('production'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Activar contenido de staging'), findsNothing);
  });

  testWidgets('staging activation requires an admin role', (tester) async {
    const fan = AuthUser(
      userId: 'fan-1',
      email: 'fan@example.com',
      username: 'fan',
      fullName: 'Fan',
      status: 'ACTIVE',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProviderScope(
          child: AdminCenterPage(
            authService: _AuthService(fan),
            adminService: _AdminService(),
            appConfig: _config('staging'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sin acceso'), findsOneWidget);
    expect(find.text('Activar contenido de staging'), findsNothing);
  });

  testWidgets('admin sees prefix-scoped staging activation confirmation', (
    tester,
  ) async {
    const admin = AuthUser(
      userId: 'admin-1',
      email: 'admin@example.com',
      username: 'admin',
      fullName: 'Admin',
      status: 'ACTIVE',
      role: 'SUPERADMIN',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProviderScope(
          child: AdminCenterPage(
            authService: _AuthService(admin),
            adminService: _AdminService(),
            appConfig: _config('staging'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Activar contenido de staging'));
    await tester.pump();

    expect(find.textContaining('40 registros pendientes'), findsOneWidget);
    expect(find.textContaining('crema-vivo'), findsWidgets);
    expect(find.textContaining('@garra.staging.internal'), findsOneWidget);
  });
}
