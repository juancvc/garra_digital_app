import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ranking_service.dart';
import '../../data/ranking_model.dart';

final rankingServiceProvider = Provider((ref) => RankingService());

final rankingProvider = FutureProvider<List<RankingModel>>((ref) async {
  final service = ref.read(rankingServiceProvider);
  return service.getTopRanking();
});