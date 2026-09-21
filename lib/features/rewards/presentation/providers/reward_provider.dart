import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reward_models.dart';
import '../../data/reward_service.dart';

final rewardServiceProvider = Provider<RewardService>((ref) => RewardService());

final rewardCatalogProvider =
    FutureProvider.autoDispose<List<RewardOffer>>((ref) async {
  return ref.watch(rewardServiceProvider).catalog(available: true);
});

final rewardDetailProvider =
    FutureProvider.autoDispose.family<RewardOffer, String>((ref, slug) async {
  return ref.watch(rewardServiceProvider).detail(slug);
});

final myRewardsProvider =
    FutureProvider.autoDispose<List<RewardRedemption>>((ref) async {
  return ref.watch(rewardServiceProvider).myRedemptions();
});
