import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sponsor_service.dart';

final sponsorServiceProvider = Provider<SponsorService>((ref) {
  return SponsorService();
});

final matchdaySponsorCardProvider =
    FutureProvider.autoDispose.family<SponsoredCard?, String?>((ref, matchId) {
  return ref.watch(sponsorServiceProvider).getMatchdayCard(matchId: matchId);
});
