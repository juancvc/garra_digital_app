import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/match_model.dart';
import '../../data/match_service.dart';

final matchServiceProvider = Provider<MatchService>((ref) {
  return MatchService();
});

final upcomingMatchesProvider = FutureProvider<List<MatchModel>>((ref) async {
  final service = ref.read(matchServiceProvider);
  return service.getUpcomingMatches();
});