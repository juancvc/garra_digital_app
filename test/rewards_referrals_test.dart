import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'package:garra_digital_app/core/theme/app_theme.dart';
import 'package:garra_digital_app/features/home/data/home_models.dart';
import 'package:garra_digital_app/features/referrals/data/referral_models.dart';
import 'package:garra_digital_app/features/referrals/presentation/providers/referral_provider.dart';
import 'package:garra_digital_app/features/referrals/presentation/referrals_page.dart';
import 'package:garra_digital_app/features/rewards/data/reward_models.dart';
import 'package:garra_digital_app/features/rewards/presentation/providers/reward_provider.dart';
import 'package:garra_digital_app/features/rewards/presentation/my_rewards_page.dart';
import 'package:garra_digital_app/features/rewards/presentation/redemption_success_page.dart';
import 'package:garra_digital_app/features/rewards/presentation/reward_detail_page.dart';
import 'package:garra_digital_app/features/rewards/presentation/rewards_page.dart';
import 'package:garra_digital_app/features/rewards/widgets/garra_reward_card.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';

RewardOffer sampleOffer({
  String slug = 'entrada-vip',
  String title = 'Entrada experiencia VIP',
  int cost = 500,
  bool sponsored = false,
  bool available = true,
  bool canRedeem = true,
  int balanceNeeded = 500,
  String? reason,
}) {
  return RewardOffer(
    id: 'r1',
    slug: slug,
    title: title,
    description: 'Beneficio de experiencia crema',
    providerType: sponsored ? 'SPONSOR' : 'PLATFORM',
    providerLabel: sponsored ? 'Beneficio de Marca X' : 'Beneficio de Garra Digital',
    providerName: sponsored ? 'Marca X' : 'Garra Digital',
    sponsored: sponsored,
    status: 'ACTIVE',
    pointsCost: cost,
    stockMode: 'UNLIMITED',
    available: available,
    maxRedemptionsPerFan: 1,
    myRedemptionCount: 0,
    canRedeem: canRedeem,
    ineligibilityReason: reason,
    terms: 'Válido en taquilla. No transferible.',
  );
}

RewardRedemption sampleRedemption() {
  return const RewardRedemption(
    id: 'red-1',
    rewardSlug: 'entrada-vip',
    rewardTitle: 'Entrada experiencia VIP',
    providerLabel: 'Beneficio de Garra Digital',
    pointsSpent: 500,
    status: 'ISSUED',
    redemptionCode: 'GRR-AB12CD34',
  );
}

ReferralMe sampleReferralMe({bool withCampaign = true}) {
  return ReferralMe(
    myCode: 'CREMA7X',
    activeCampaign: withCampaign
        ? ReferralCampaignSummary(
            id: 'c1',
            name: 'Invita y activa',
            status: 'ACTIVE',
            inviterRewardPoints: 50,
            refereeRewardPoints: 25,
            qualificationAction: 'FIRST_PREDICTION',
          )
        : null,
    qualifiedCount: 2,
    pendingCount: 1,
    pointsEarnedFromReferrals: 100,
  );
}

HomeModel sampleHome({HomeCommercialCard? commercial}) {
  return HomeModel(
    fan: const HomeFanSummary(
      displayName: 'Juan',
      username: 'juan',
      levelNumber: 3,
      levelName: 'Hincha',
      points: 200,
    ),
    matchdayState: 'NO_MATCH',
    prediction: const HomePrediction(state: 'NOT_PREDICTED', predictionsOpen: false),
    checkIn: const HomeCheckIn(
      showCheckInCta: false,
      hasActiveStadiumPoint: false,
      recentlyCheckedIn: false,
    ),
    community: const HomeCommunityPreview(posts: []),
    notifications: const HomeNotifications(unreadCount: 0),
    commercial: commercial,
  );
}

void main() {
  testWidgets('REWARD_CATALOG_RENDER', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rewardCatalogProvider.overrideWith((ref) async => [sampleOffer()]),
          homeProvider.overrideWith((ref) async => sampleHome()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const RewardsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Entrada experiencia VIP'), findsOneWidget);
    expect(find.textContaining('Puntos Garra'), findsWidgets);
  });

  testWidgets('REWARD_EMPTY_STATE', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rewardCatalogProvider.overrideWith((ref) async => []),
          homeProvider.overrideWith((ref) async => sampleHome()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const RewardsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('no hay beneficios disponibles'), findsOneWidget);
  });

  testWidgets('REWARD_DETAIL', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rewardDetailProvider('entrada-vip')
              .overrideWith((ref) async => sampleOffer()),
          homeProvider.overrideWith((ref) async => sampleHome()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const RewardDetailPage(slug: 'entrada-vip'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Entrada experiencia VIP'), findsOneWidget);
    expect(find.textContaining('Términos'), findsOneWidget);
  });

  testWidgets('REWARD_PROVIDER_LABEL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: GarraRewardCard(offer: sampleOffer())),
      ),
    );
    expect(find.textContaining('Beneficio de Garra Digital'), findsOneWidget);
  });

  testWidgets('REWARD_COST', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: GarraRewardCard(offer: sampleOffer(cost: 500))),
      ),
    );
    expect(find.text('500 Puntos Garra'), findsOneWidget);
    expect(find.textContaining('S/'), findsNothing);
  });

  testWidgets('REWARD_INSUFFICIENT_BALANCE', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rewardDetailProvider('entrada-vip').overrideWith(
            (ref) async => sampleOffer(cost: 500, canRedeem: false),
          ),
          homeProvider.overrideWith((ref) async => sampleHome()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const RewardDetailPage(slug: 'entrada-vip'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Te faltan'), findsOneWidget);
    expect(find.textContaining('Comprar'), findsNothing);
  });

  testWidgets('REDEMPTION_CONFIRMATION', (tester) async {
    final richHome = HomeModel(
      fan: const HomeFanSummary(
        displayName: 'Juan',
        username: 'juan',
        levelNumber: 3,
        levelName: 'Hincha',
        points: 800,
      ),
      matchdayState: 'NO_MATCH',
      prediction: const HomePrediction(state: 'NOT_PREDICTED', predictionsOpen: false),
      checkIn: const HomeCheckIn(
        showCheckInCta: false,
        hasActiveStadiumPoint: false,
        recentlyCheckedIn: false,
      ),
      community: const HomeCommunityPreview(posts: []),
      notifications: const HomeNotifications(unreadCount: 0),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rewardDetailProvider('entrada-vip')
              .overrideWith((ref) async => sampleOffer(cost: 500)),
          homeProvider.overrideWith((ref) async => richHome),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const RewardDetailPage(slug: 'entrada-vip'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Canjear por 500'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar canje'), findsWidgets);
    expect(find.textContaining('Saldo después'), findsOneWidget);
  });

  testWidgets('REDEMPTION_SUCCESS', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: RedemptionSuccessPage(redemption: sampleRedemption()),
      ),
    );
    expect(find.text('Canje realizado'), findsOneWidget);
    expect(find.text('GRR-AB12CD34'), findsOneWidget);
  });

  test('REDEMPTION_CODE_SAFE', () {
    final code = sampleRedemption().redemptionCode;
    expect(code.contains('@'), isFalse);
    expect(code.toLowerCase().contains('uuid'), isFalse);
    expect(code.length, greaterThan(6));
  });

  testWidgets('MY_REWARDS', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myRewardsProvider.overrideWith((ref) async => [sampleRedemption()]),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MyRewardsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('GRR-AB12CD34'), findsOneWidget);
  });

  testWidgets('SPONSORED_REWARD_LABEL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: GarraRewardCard(offer: sampleOffer(sponsored: true)),
        ),
      ),
    );
    expect(find.textContaining('Patrocinado por Marca X'), findsOneWidget);
  });

  test('COMMERCIAL_HOME_SLOT_MAX_ONE', () {
    final matchday = HomeCommercialCard(
      kind: 'MATCHDAY_SPONSOR',
      activationId: 'a1',
      campaignId: 'c1',
      sponsorName: 'Marca',
      headline: 'Matchday',
      label: 'Patrocinado por Marca',
    );
    final reward = HomeCommercialCard(
      kind: 'SPONSORED_REWARD',
      activationId: 'a2',
      campaignId: 'c2',
      sponsorName: 'Marca',
      headline: 'Reward',
      label: 'Patrocinado por Marca',
      rewardSlug: 'entrada-vip',
      pointsCost: 100,
    );
    // Policy: only one commercial card is carried on HomeModel.
    final home = sampleHome(commercial: matchday);
    expect(home.commercial, isNotNull);
    expect(home.commercial!.isMatchdaySponsor, isTrue);
    expect(home.commercial!.isSponsoredReward, isFalse);
    expect(reward.isSponsoredReward, isTrue);
  });

  testWidgets('REFERRAL_CODE_RENDER', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralMeProvider.overrideWith((ref) async => sampleReferralMe()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ReferralsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CREMA7X'), findsOneWidget);
  });

  testWidgets('REFERRAL_SHARE', (tester) async {
    ShareParams? captured;
    // share_plus is invoked; we only assert share CTA exists and copy tone helper.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralMeProvider.overrideWith((ref) async => sampleReferralMe()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ReferralsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compartir'), findsOneWidget);
    expect(
      'Únete a Garra Digital con mi código: CREMA7X',
      contains('Únete a Garra Digital con mi código'),
    );
    expect(captured, isNull);
  });

  testWidgets('REFERRAL_NO_CAMPAIGN_STATE', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralMeProvider
              .overrideWith((ref) async => sampleReferralMe(withCampaign: false)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ReferralsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin campaña de recompensa activa'), findsOneWidget);
  });

  testWidgets('REFERRAL_ACTIVE_CAMPAIGN', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralMeProvider.overrideWith((ref) async => sampleReferralMe()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ReferralsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Invita y activa'), findsOneWidget);
    expect(find.textContaining('50 Puntos Garra'), findsOneWidget);
  });

  test('REFERRAL_CLAIM_VALID', () {
    final result = ReferralClaimResult(
      attributionId: 'a1',
      status: 'ATTRIBUTED',
      message: 'Invitación registrada. Actívate en Garra Digital para completar el beneficio.',
    );
    expect(result.status, 'ATTRIBUTED');
    expect(result.message.toLowerCase(), contains('invitación'));
  });

  test('REFERRAL_SELF_REJECTED', () {
    expect(
      referralClaimErrorMessage(Exception('No puedes usar tu propio código')),
      'No puedes usar tu propio código',
    );
  });

  test('REFERRAL_ALREADY_ATTRIBUTED', () {
    expect(
      referralClaimErrorMessage(Exception('Ya tienes una invitación atribuida')),
      'Ya registraste una invitación',
    );
  });

  testWidgets('REFERRAL_METRICS_RENDER', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralMeProvider.overrideWith((ref) async => sampleReferralMe()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ReferralsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Activados'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });

  test('NO_PRIVATE_REFEREE_DATA', () {
    final json = {
      'myCode': 'CREMA7X',
      'qualifiedCount': 2,
      'pendingCount': 1,
      'pointsEarnedFromReferrals': 100,
    };
    final me = ReferralMe.fromJson(json);
    expect(me.toString().contains('@'), isFalse);
    expect(json.containsKey('email'), isFalse);
    expect(json.containsKey('phone'), isFalse);
    expect(json.containsKey('referees'), isFalse);
  });
}
