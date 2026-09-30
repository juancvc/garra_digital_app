import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:garra_digital_app/core/widgets/linked_text.dart';
import 'package:garra_digital_app/features/community/data/post_location.dart';
import 'package:garra_digital_app/features/community/data/community_service.dart';
import 'package:garra_digital_app/features/community/data/create_wall_post_request.dart';
import 'package:garra_digital_app/features/community/presentation/create_community_post_page.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/post_location_label.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/social_link_card.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';
import 'package:garra_digital_app/features/community/presentation/post_location_picker.dart';
import 'package:garra_digital_app/features/locations/data/location_service.dart';
import 'package:garra_digital_app/features/locations/data/crema_point_model.dart';

class FakePoints extends LocationService {
  FakePoints() : super(dio: Dio());
  int calls = 0;

  @override
  Future<List<CremaPointModel>> getActivePoints() async {
    calls++;
    return const [CremaPointModel(id: 'point', name: 'Estadio Monumental',
      description: null, type: 'STADIUM', address: 'Ate',
      latitude: -12.0, longitude: -77.0, verified: true, sponsor: false,
      status: 'ACTIVE', createdAt: '', updatedAt: '')];
  }
}

class FakePosts extends CommunityService {
  FakePosts() : super(dio: Dio());
  PostLocation? submitted;
  String? matchTag;
  int calls = 0;

  @override
  Future<WallActionResult> createGlobalPost({required String content,
    String? mediaAssetId, List<String>? mediaAssetIds, String? locationTag,
    PostLocation? postLocation, String visibility = 'PUBLIC'}) async {
    submitted = postLocation;
    calls++;
    return WallActionResult.success(message: 'ok');
  }

  @override
  Future<WallActionResult> createPost(CreateWallPostRequest request) async {
    submitted = request.postLocation;
    matchTag = request.locationTag;
    calls++;
    return WallActionResult.success(message: 'ok');
  }
}

void main() {
  test('HTTP(S) parser keeps multiple links and trims punctuation', () {
    final links = httpLinks('Mira https://example.com/a, y http://example.org/b!').toList();
    expect(links.map((link) => link.text),
        ['https://example.com/a', 'http://example.org/b']);
    expect(httpLinks('javascript:alert(1) invalid://site').toList(), isEmpty);
    expect(httpLinks('https://bad..host').toList(), isEmpty);
  });

  test('social card recognizes only the first supported video/post', () {
    expect(firstSocialLink('https://site.test/a https://youtu.be/abc123 ' 
        'https://www.tiktok.com/@fan/video/123')?.provider, 'YouTube');
    expect(firstSocialLink('https://www.tiktok.com/@fan/video/123')?.provider,
        'TikTok');
    expect(firstSocialLink('https://www.instagram.com/reel/abc/')?.provider,
        'Instagram');
    expect(firstSocialLink('https://site.test/a'), isNull);
    expect(firstSocialLink('https://youtube.com.evil.test/watch?v=abc'), isNull);
  });

  test('post location parses and survives shared-original projection', () {
    final location = PostLocation.fromJson({
      'name': 'Cusco', 'kind': 'CITY_OR_AREA',
    });
    expect(location.toJson(), {'name': 'Cusco', 'kind': 'CITY_OR_AREA'});
    final original = SharedOriginalPostModel(
      id: 'original', authorId: 'author', username: 'fan',
      fullName: 'Fan', content: 'Hola', postLocation: location,
    );
    expect(original.asPost().postLocation?.name, 'Cusco');
  });

  testWidgets('link and location widgets render without changing text', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      const LinkedText('Mira https://example.com/a', style: TextStyle()),
      const PostLocationLabel(location: PostLocation(
          name: 'Cusco', kind: 'CITY_OR_AREA')),
      SocialLinkCard(link: firstSocialLink('https://youtu.be/abc')!),
    ]))));
    expect(find.textContaining('https://example.com/a'), findsOneWidget);
    expect(find.text('Cusco'), findsOneWidget);
    expect(find.textContaining('YouTube'), findsOneWidget);
  });

  testWidgets('narrow card remains within its width', (tester) async {
    final post = WallPostModel.fromJson({
      'id': 'p', 'username': 'ana', 'fullName': 'Ana', 'content': 'Vamos la U',
      'status': 'ACTIVE', 'contextType': 'GLOBAL',
      'createdAt': '2026-09-29T12:00:00Z', 'reactionCount': 2,
      'reactionSummary': {'FIRE': 2}, 'commentCount': 3, 'shareCount': 1,
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 280,
          child: GarraSocialPostCard(post: post, onOpen: () {})),
    ))));
    final error = tester.takeException();
    expect(error, isNull);
  });

  testWidgets('shared original shows its own link card and location', (tester) async {
    final share = WallPostModel.fromJson({
      'id': 'share', 'username': 'luis', 'fullName': 'Luis', 'content': '',
      'status': 'ACTIVE', 'contextType': 'GLOBAL',
      'createdAt': '2026-09-29T12:00:00Z',
      'originalPost': {
        'id': 'original', 'authorId': 'ana', 'username': 'ana',
        'fullName': 'Ana', 'content': 'Mira https://youtu.be/abc123',
        'createdAt': '2026-09-29T11:00:00Z',
        'postLocation': {'name': 'Cusco', 'kind': 'CITY_OR_AREA'},
      },
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        GarraSocialPostCard(post: share, onOpen: () {}))));
    expect(find.text('Cusco'), findsOneWidget);
    expect(find.textContaining('YouTube'), findsOneWidget);
    expect(find.byType(LinkedText), findsOneWidget);
  });

  testWidgets('ordinary post card shows location and one social card', (tester) async {
    final post = WallPostModel.fromJson({
      'id': 'p', 'username': 'ana', 'fullName': 'Ana',
      'content': 'https://www.instagram.com/reel/abc/ y https://youtu.be/xyz',
      'status': 'ACTIVE', 'contextType': 'GLOBAL',
      'createdAt': '2026-09-29T12:00:00Z',
      'postLocation': {'name': 'Cusco', 'kind': 'CITY_OR_AREA'},
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        GarraSocialPostCard(post: post, onOpen: () {}))));
    expect(find.text('Cusco'), findsOneWidget);
    expect(find.byType(SocialLinkCard), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
  });

  testWidgets('tapping a link does not trigger its parent post tap', (tester) async {
    var postOpens = 0;
    final opened = <Uri>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: InkWell(
      onTap: () => postOpens++,
      child: LinkedText('Abre https://example.com/post.',
          style: const TextStyle(), onOpenLink: opened.add),
    ))));
    await tester.tap(find.byType(LinkedText));
    await tester.pump();
    expect(opened.single.toString(), 'https://example.com/post');
    expect(postOpens, 0);
  });

  testWidgets('city selection is explicit and has no coordinates', (tester) async {
    final points = FakePoints();
    PostLocation? selected;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async => selected = await pickPostLocation(context,
            locationService: points), child: const Text('Agregar ubicación')),
    )))));
    await tester.tap(find.text('Agregar ubicación'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Cusco  ');
    await tester.pump();
    await tester.tap(find.text('Usar ciudad o zona'));
    await tester.pumpAndSettle();
    expect(selected?.name, 'Cusco');
    expect(selected?.latitude, isNull);
    expect(points.calls, 1);
  });

  testWidgets('catalog point selection carries catalog coordinates', (tester) async {
    final points = FakePoints();
    PostLocation? selected;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () async => selected = await pickPostLocation(context,
            locationService: points), child: const Text('Agregar ubicación')),
    )))));
    await tester.tap(find.text('Agregar ubicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estadio Monumental'));
    await tester.pumpAndSettle();
    expect(selected?.kind, 'PLACE');
    expect(selected?.latitude, -12.0);
    expect(selected?.longitude, -77.0);
  });

  for (final match in [false, true]) {
    testWidgets('${match ? 'MATCH' : 'GLOBAL'} composer guards and sends selected city',
        (tester) async {
      final posts = FakePosts();
      final points = FakePoints();
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Feed'))),
        GoRoute(path: '/compose', builder: (_, _) => CreateCommunityPostPage(
          matchId: match ? 'match-1' : null,
          communityService: posts, locationService: points)),
      ]);
      await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
      router.push('/compose');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar ubicación'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Cusco');
      await tester.pump();
      await tester.tap(find.text('Usar ciudad o zona'));
      await tester.pumpAndSettle();
      expect(find.text('Cusco'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar borrador?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Vamos la U');
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(posts.submitted?.name, 'Cusco');
      expect(posts.submitted?.latitude, isNull);
      if (match) expect(posts.matchTag, 'HOME');
    });
  }

  testWidgets('composer can change and remove location, then publish without it',
      (tester) async {
    final posts = FakePosts();
    final points = FakePoints();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Feed'))),
      GoRoute(path: '/compose', builder: (_, _) => CreateCommunityPostPage(
        communityService: posts, locationService: points)),
    ]);
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    router.push('/compose');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar ubicación'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Cusco');
    await tester.pump();
    await tester.tap(find.text('Usar ciudad o zona'));
    await tester.pumpAndSettle();
    expect(find.text('Cusco'), findsOneWidget);
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estadio Monumental'));
    await tester.pumpAndSettle();
    expect(find.text('Estadio Monumental'), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar ubicación'));
    await tester.pumpAndSettle();
    expect(find.text('Estadio Monumental'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Sin ubicación');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(posts.calls, 1);
    expect(posts.submitted, isNull);
  });
}
