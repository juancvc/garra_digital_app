import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/matchday_poll_models.dart';
import '../../data/polla_models.dart';
import '../../data/polla_service.dart';

final pollaServiceProvider = Provider<PollaService>((ref) {
  return PollaService();
});

final pollaProvider =
    FutureProvider.autoDispose.family<PollaResponse, String>((ref, matchId) {
  return ref.watch(pollaServiceProvider).getPolla(matchId);
});

final matchdayProvider =
    FutureProvider.autoDispose.family<MatchdaySummary, String>((ref, matchId) {
  return ref.watch(pollaServiceProvider).getMatchday(matchId);
});

final matchdayPollsProvider =
    FutureProvider.autoDispose.family<List<MatchPoll>, String>((ref, matchId) {
  return ref.watch(pollaServiceProvider).listPolls(matchId);
});

final pollResultsProvider = FutureProvider.autoDispose
    .family<MatchPollResults, String>((ref, pollId) {
  return ref.watch(pollaServiceProvider).getPollResults(pollId);
});
