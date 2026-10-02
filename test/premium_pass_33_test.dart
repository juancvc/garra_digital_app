import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/core/widgets/garra_states.dart';
import 'package:garra_digital_app/features/community/data/wall_post_model.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/garra_social_post_card.dart';

WallPostModel _post(String? reaction) => WallPostModel(
  id: 'post-1',
  username: 'crema',
  fullName: 'Hincha Crema',
  content: 'Vamos la U',
  imageUrl: null,
  locationTag: 'HOME',
  status: 'ACTIVE',
  reportCount: 0,
  createdAt: DateTime.utc(2026, 9, 30).toIso8601String(),
  myReaction: reaction,
  reactionCount: reaction == null ? 0 : 1,
  reactionSummary: reaction == null ? const {} : const {'LIKE': 1},
);

void main() {
  testWidgets('selected reaction is visually distinct without changing action',
      (tester) async {
    var taps = 0;
    Future<void> show(String? reaction) => tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: GarraSocialPostCard(
        post: _post(reaction), onOpen: () {}, onReact: () => taps++,
      )),
    ));

    await show(null);
    final inactive = tester.widget<Text>(find.text('Reaccionar'));
    expect(inactive.style?.fontWeight, isNot(FontWeight.w800));
    await show('LIKE');
    final active = tester.widget<Text>(find.text('Me gusta'));
    expect(active.style?.fontWeight, FontWeight.w800);
    await tester.tap(find.text('Me gusta'));
    expect(taps, 1);
  });

  testWidgets('shared empty and error states retain their actions',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme,
      home: Scaffold(body: GarraErrorState(onRetry: () => retried = true))));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retried, isTrue);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme,
      home: const Scaffold(body: GarraEmptyState(
        title: 'Sin contenido', message: 'Vuelve más tarde.'))));
    expect(find.text('Sin contenido'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
  });

  testWidgets('conversation loading uses a stable three-row placeholder',
      (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme,
      home: const Scaffold(body: GarraConversationSkeleton())));
    expect(find.byType(GarraSkeleton), findsNWidgets(3));
  });

  testWidgets('feed actions fit a narrow screen with larger text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme,
      home: Scaffold(body: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: SizedBox(width: 280, child: GarraSocialPostCard(
          post: _post('LIKE'), onOpen: () {}, onShare: () {},
        )),
      )),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Compartir'), findsOneWidget);
  });

  testWidgets('selected long reaction label remains fully visible on narrow screens',
      (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme,
      home: Scaffold(body: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: SizedBox(width: 300, child: GarraSocialPostCard(
          post: _post('FIRE'), onOpen: () {}, onReact: () {},
          onComment: () {}, onShare: () {},
        )),
      )),
    ));
    final label = find.text('Está que arde');
    expect(label, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
