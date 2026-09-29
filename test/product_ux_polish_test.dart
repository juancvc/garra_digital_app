import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/media/media_upload_service.dart';
import 'package:garra_digital_app/core/widgets/garra_avatar.dart';
import 'package:garra_digital_app/core/utils/date_utils.dart';
import 'package:garra_digital_app/features/community/data/wall_comment_model.dart';
import 'package:garra_digital_app/features/community/presentation/create_community_post_page.dart';
import 'package:garra_digital_app/features/locations/presentation/negocios_cremas_page.dart';
import 'package:image_picker/image_picker.dart';

class _MatchPhotoMedia extends MediaUploadService {
  _MatchPhotoMedia() : super(dio: Dio());

  int singlePicks = 0;
  int multiPicks = 0;
  int uploads = 0;

  @override
  Future<XFile?> pickImage({double maxSide = 1920}) async {
    singlePicks++;
    return XFile('match.jpg');
  }

  @override
  Future<List<XFile>> pickMultiImage({int max = 4}) async {
    multiPicks++;
    return [XFile('first.jpg'), XFile('second.jpg')];
  }

  @override
  Future<MediaDraft> uploadFile({
    required XFile file,
    required MediaUploadPurpose purpose,
    void Function(MediaDraft draft)? onUpdate,
    int? squareMax,
    bool Function()? canStartRemote,
    CancelToken? cancelToken,
  }) async {
    uploads++;
    final draft = MediaDraft(
      localId: file.path,
      assetId: 'asset-${file.path}',
      state: MediaUploadState.ready,
    );
    onUpdate?.call(draft);
    return draft;
  }
}

void main() {
  test('UTC timestamps stay on the same instant in local display', () {
    final zoned = parseGarraInstant('2026-09-25T07:00:00Z');
    final bare = parseGarraInstant('2026-09-25T07:00:00');
    final offset = parseGarraInstant('2026-09-25T02:00:00-05:00');

    expect(zoned, DateTime.utc(2026, 9, 25, 7));
    expect(bare, zoned);
    expect(offset!.toUtc(), DateTime.utc(2026, 9, 25, 7));

    final relative = formatGarraRelativeTime(
      '2026-09-25T07:00:00Z',
      now: DateTime.utc(2026, 9, 25, 8),
    );
    expect(relative, 'hace 1 h');
    expect(
      formatGarraRelativeTime(
        '2026-09-25T07:00:00',
        now: DateTime.utc(2026, 9, 25, 8),
      ),
      'hace 1 h',
    );
  });

  testWidgets('comment row shows avatar fallback and relative time', (
    tester,
  ) async {
    const comment = WallCommentModel(
      id: 'c1',
      postId: 'p1',
      username: 'ana',
      fullName: 'Ana Quispe',
      content: 'Vamos crema',
      createdAt: '2026-09-25T07:00:00Z',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const GarraAvatar(displayName: 'Ana Quispe', size: 30),
              Text(
                '${comment.fullName} · ${formatGarraRelativeTime(comment.createdAt, now: DateTime.utc(2026, 9, 25, 8))}',
              ),
              Text(comment.content),
            ],
          ),
        ),
      ),
    );
    expect(find.text('AQ'), findsOneWidget);
    expect(find.textContaining('Ana Quispe · hace 1 h'), findsOneWidget);
    expect(comment.avatarUrl, isNull);
  });

  testWidgets('create post header fits a narrow phone and has one counter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateCommunityPostPage())),
    );
    await tester.pump();
    expect(find.text('Nueva publicación'), findsOneWidget);
    expect(find.byTooltip('Cancelar'), findsOneWidget);
    expect(find.text('Publicar'), findsOneWidget);
    expect(find.text('Agregar fotos'), findsOneWidget);
    expect(find.textContaining('/220'), findsOneWidget);
    expect(find.textContaining('/4'), findsNothing);
    expect(tester.takeException(), isNull);

    // POLISH_05: posts stay at the backend limit (220, @Size + VARCHAR(220)).
    await tester.enterText(find.byType(TextField), 'a' * 230);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text.length,
      220,
    );
  });

  testWidgets('match post offers one photo while global post offers photos', (
    tester,
  ) async {
    final media = _MatchPhotoMedia();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CreateCommunityPostPage(matchId: 'match-1', media: media),
        ),
      ),
    );
    expect(find.text('Agregar foto'), findsOneWidget);
    expect(find.text('Agregar fotos'), findsNothing);
    await tester.tap(find.text('Agregar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir de galería'));
    await tester.pumpAndSettle();
    expect(media.singlePicks, 1);
    expect(media.multiPicks, 0);
    expect(media.uploads, 1);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('add-photos')))
          .onPressed,
      isNull,
    );

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateCommunityPostPage())),
    );
    expect(find.text('Agregar fotos'), findsOneWidget);
  });

  testWidgets('negocios cremas is separate from the stadium route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const NegociosCremasPage()),
    );
    expect(find.text('Negocios Cremas'), findsOneWidget);
    expect(find.text('Mi negocio'), findsOneWidget);
    expect(find.text('Ruta al Templo'), findsNothing);
    expect(find.text('Consultar por chat'), findsNothing);
  });
}
