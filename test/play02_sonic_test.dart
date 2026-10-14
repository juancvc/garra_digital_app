import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/legal/legal_acceptance_checkbox.dart';
import 'package:garra_digital_app/core/legal/legal_acceptance_service.dart';
import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/auth/presentation/legal_acceptance_page.dart';
import 'package:garra_digital_app/features/chat/presentation/chat_message_reactions.dart';
import 'package:garra_digital_app/features/community/data/community_report.dart';
import 'package:garra_digital_app/features/community/presentation/widgets/chat_message_safety_actions.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_models.dart';
import 'package:go_router/go_router.dart';

class _FakeLegalService extends LegalAcceptanceService {
  final accepted = <LegalAcceptanceChannel>[];

  @override
  Future<LegalAcceptanceStatus> status() async => _status(false);

  @override
  Future<LegalAcceptanceStatus> accept(
    LegalAcceptanceChannel channel, {
    LegalAcceptanceStatus? current,
  }) async {
    accepted.add(channel);
    return _status(true);
  }
}

LegalAcceptanceStatus _status(bool accepted) => LegalAcceptanceStatus(
  termsVersion: 'draft-2026-10',
  privacyVersion: 'draft-2026-10',
  termsPath: '/legal/terms',
  privacyPath: '/legal/privacy',
  accepted: accepted,
);

void main() {
  group('PLAY-02 marketplace report contract', () {
    test('COUNTERFEIT is offered with the Spanish label', () {
      final counterfeit = marketplaceListingReportReasons.firstWhere(
        (r) => r.code == 'COUNTERFEIT',
      );
      expect(
        counterfeit.label,
        'Falsificaci\u00f3n o infracci\u00f3n de marca',
      );
      expect(marketplaceListingReportReasons.map((r) => r.code).toSet(), {
        'SCAM',
        'COUNTERFEIT',
        'PROHIBITED_ITEM',
        'MISLEADING',
        'HARASSMENT',
        'OTHER',
      });
    });

    test('payload matches CreateMarketplaceReportRequest', () {
      const request = MarketplaceReportRequest(
        listingSlug: 'camiseta-1',
        reason: 'COUNTERFEIT',
        details: ' ',
      );
      expect(request.toJson(), {
        'targetType': 'LISTING',
        'targetSlug': 'camiseta-1',
        'reason': 'COUNTERFEIT',
      });
    });
  });

  group('PLAY-02 chat safety actions', () {
    test('new report targets use the backend codes', () {
      expect(GarraReportTarget.directMessage.apiValue, 'DIRECT_MESSAGE');
      expect(
        GarraReportTarget.communityChatMessage.apiValue,
        'COMMUNITY_CHAT_MESSAGE',
      );
    });

    testWidgets('report message, report user and block user', (tester) async {
      late List<ChatMessageAction> actions;
      late List<ChatMessageAction> empty;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                actions = chatMessageSafetyActions(
                  context: context,
                  messageTarget: GarraReportTarget.directMessage,
                  messageId: 'm1',
                  authorId: 'u2',
                  authorName: 'Otro',
                  keyPrefix: 'dm',
                );
                empty = chatMessageSafetyActions(
                  context: context,
                  messageTarget: GarraReportTarget.communityChatMessage,
                  messageId: 'm1',
                  authorId: '',
                  authorName: '',
                  keyPrefix: 'cc',
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(actions.map((a) => a.label).toList(), [
        'Denunciar mensaje',
        'Denunciar usuario',
        'Bloquear usuario',
      ]);
      expect(actions.map((a) => a.key).toList(), const [
        Key('dm-action-report-message'),
        Key('dm-action-report-user'),
        Key('dm-action-block-user'),
      ]);
      expect(empty, isEmpty);
    });
  });

  group('PLAY-02 legal acceptance', () {
    test('status parses the server contract', () {
      final s = LegalAcceptanceStatus.fromJson({
        'termsVersion': 'draft-2026-10',
        'privacyVersion': 'draft-2026-10',
        'termsPath': '/legal/terms',
        'privacyPath': '/legal/privacy',
        'finalTexts': false,
        'accepted': false,
        'acceptedAt': null,
      });
      expect(s.accepted, isFalse);
      expect(s.acceptedAt, isNull);
      expect(s.termsPath, '/legal/terms');
      expect(LegalAcceptanceChannel.updatePrompt.code, 'UPDATE_PROMPT');
      expect(LegalAcceptanceChannel.signup.code, 'SIGNUP');
    });

    testWidgets('checkbox is not pre-checked and links Terms and Privacy', (
      tester,
    ) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => LegalAcceptanceCheckbox(
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('legal-accept-checkbox')),
            )
            .value,
        isFalse,
      );
      expect(find.byKey(const ValueKey('legal-terms-link')), findsOneWidget);
      expect(find.byKey(const ValueKey('legal-privacy-link')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('legal-accept-checkbox')));
      await tester.pump();
      expect(value, isTrue);
    });

    testWidgets('gate requires the checkbox, then records UPDATE_PROMPT', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _FakeLegalService();
      final router = GoRouter(
        initialLocation: '/legal-acceptance',
        routes: [
          GoRoute(
            path: '/legal-acceptance',
            builder: (_, __) => const LegalAcceptancePage(),
          ),
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            legalAcceptanceServiceProvider.overrideWithValue(service),
            postLegalDestinationProvider.overrideWithValue(() async => '/home'),
          ],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aceptar y continuar'));
      await tester.pumpAndSettle();
      expect(service.accepted, isEmpty);
      expect(find.byKey(const ValueKey('legal-accept-error')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('legal-accept-checkbox')));
      await tester.pump();
      await tester.tap(find.text('Aceptar y continuar'));
      await tester.pumpAndSettle();
      expect(service.accepted, [LegalAcceptanceChannel.updatePrompt]);
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}
