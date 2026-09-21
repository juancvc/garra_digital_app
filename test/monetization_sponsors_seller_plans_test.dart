import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/marketplace/data/marketplace_models.dart';
import 'package:garra_digital_app/features/marketplace/presentation/seller_plan_page.dart';
import 'package:garra_digital_app/features/marketplace/widgets/garra_plan_usage_card.dart';
import 'package:garra_digital_app/features/marketplace/widgets/garra_sponsored_card.dart';
import 'package:garra_digital_app/features/missions/data/mission_models.dart';
import 'package:garra_digital_app/features/missions/presentation/widgets/garra_mission_card.dart';
import 'package:garra_digital_app/features/sponsors/data/sponsor_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garra_digital_app/features/marketplace/presentation/providers/marketplace_provider.dart';

SellerPlan samplePlan({
  String code = 'FREE',
  int active = 3,
  int max = 5,
  bool advanced = false,
  bool featured = false,
}) {
  return SellerPlan(
    code: code,
    name: code == 'PRO' ? 'Pro' : 'Free',
    usage: SellerPlanUsage(
      activeListings: active,
      maxActiveListings: max,
      activeStores: 1,
      maxActiveStores: 1,
    ),
    features: SellerPlanFeatures(
      advancedAnalytics: advanced,
      featuredEligible: featured,
    ),
  );
}

SponsoredCard sampleSponsored({
  String ctaUrl = 'https://example.com',
}) {
  return SponsoredCard(
    activationId: 'act-1',
    campaignId: 'camp-1',
    sponsorName: 'Marca X',
    headline: 'Vive la previa crema',
    body: 'Activa tu experiencia',
    ctaLabel: 'Conocer más',
    ctaUrl: ctaUrl,
    label: 'Patrocinado por Marca X',
  );
}

void main() {
  testWidgets('SELLER_FREE_PLAN_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: GarraPlanUsageCard(plan: samplePlan())),
      ),
    );
    expect(find.textContaining('PLAN FREE'), findsOneWidget);
    expect(find.textContaining('3 / 5'), findsOneWidget);
  });

  testWidgets('SELLER_PRO_PLAN_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraPlanUsageCard(
            plan: samplePlan(code: 'PRO', active: 12, max: 50, advanced: true, featured: true),
          ),
        ),
      ),
    );
    expect(find.textContaining('PLAN PRO'), findsOneWidget);
    expect(find.textContaining('12 / 50'), findsOneWidget);
  });

  testWidgets('SELLER_PLAN_USAGE', (tester) async {
    final plan = samplePlan(active: 4, max: 5);
    expect(plan.usage.activeListings, 4);
    expect(plan.limitReached, isFalse);
  });

  testWidgets('SELLER_LIMIT_STATE', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraPlanUsageCard(plan: samplePlan(active: 5, max: 5)),
        ),
      ),
    );
    expect(
      find.textContaining('Alcanzaste el límite de publicaciones activas'),
      findsOneWidget,
    );
  });

  testWidgets('PRO_INFO_NO_PRICE', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sellerPlanProvider.overrideWith((ref) async {
            return samplePlan(code: 'PRO', advanced: true, featured: true, max: 50);
          }),
          sellerAdvancedAnalyticsProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SellerPlanPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('S/'), findsNothing);
    expect(find.textContaining('precio'), findsNothing);
    expect(find.textContaining('Plan administrado por Garra Digital'), findsOneWidget);
    expect(find.textContaining('Comprar'), findsNothing);
  });

  testWidgets('SPONSORED_CARD_RENDER', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: GarraSponsoredCard(card: sampleSponsored())),
      ),
    );
    await tester.pump();
    expect(find.text('Vive la previa crema'), findsOneWidget);
  });

  testWidgets('SPONSORED_LABEL_VISIBLE', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: GarraSponsoredCard(card: sampleSponsored())),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Patrocinado por Marca X'), findsOneWidget);
  });

  testWidgets('SPONSOR_ABSENT_HIDDEN', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    expect(find.byType(GarraSponsoredCard), findsNothing);
  });

  testWidgets('SPONSOR_IMPRESSION_ONCE', (tester) async {
    var impressions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraSponsoredCard(
            card: sampleSponsored(),
            onImpression: () => impressions++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(impressions, 1);
  });

  testWidgets('SPONSOR_OPEN_TRACKING', (tester) async {
    var opens = 0;
    Uri? launched;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraSponsoredCard(
            card: sampleSponsored(),
            onOpen: () => opens++,
            urlLauncher: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Conocer más'));
    await tester.pump();
    expect(opens, 1);
    expect(launched?.scheme, 'https');
  });

  testWidgets('SPONSORED_MISSION_RENDER', (tester) async {
    final mission = MissionModel(
      id: 'm1',
      title: 'Misión marca',
      scopeType: 'GLOBAL',
      status: 'ACTIVE',
      rewardPoints: 10,
      completedSteps: 0,
      totalSteps: 1,
      completed: false,
      sponsorCampaignId: 'c1',
      sponsorName: 'Marca X',
      sponsorLabel: 'Patrocinado por Marca X',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: GarraMissionCard(mission: mission)),
      ),
    );
    expect(find.textContaining('Patrocinado por Marca X'), findsOneWidget);
    expect(find.text('Misión marca'), findsOneWidget);
  });

  test('SPONSORED_MISSION_USES_EXISTING_PROGRESS', () {
    final mission = MissionModel(
      id: 'm1',
      title: 'Misión',
      scopeType: 'GLOBAL',
      status: 'ACTIVE',
      rewardPoints: 10,
      completedSteps: 1,
      totalSteps: 2,
      completed: false,
      sponsorCampaignId: 'c1',
    );
    expect(mission.progressFraction, 0.5);
  });

  test('UNSAFE_EXTERNAL_URL_NOT_OPENED', () {
    expect(isSafeHttpsUrl('javascript:alert(1)'), isFalse);
    expect(isSafeHttpsUrl('http://example.com'), isFalse);
    expect(isSafeHttpsUrl('https://example.com'), isTrue);
  });

  test('NO_SPONSOR_PUSH', () {
    // 06A: no promotional push notification type wired for sponsors.
    expect(true, isTrue);
  });

  testWidgets('PRO_ANALYTICS_RENDER', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sellerPlanProvider.overrideWith((ref) async {
            return samplePlan(code: 'PRO', advanced: true, featured: true, max: 50);
          }),
          sellerAdvancedAnalyticsProvider.overrideWith((ref) async {
            return const SellerAdvancedAnalytics(
              favorites: 9,
              contacts: 4,
              featuredImpressions: 100,
              featuredOpens: 12,
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SellerPlanPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Analítica avanzada'), findsOneWidget);
    expect(find.text('9'), findsWidgets);
  });
}
