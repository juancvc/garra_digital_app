import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/history_models.dart';
import '../../data/history_service.dart';

final historyServiceProvider = Provider<HistoryService>((ref) {
  return HistoryService();
});

final historyYearsProvider =
    FutureProvider.autoDispose<List<int>>((ref) async {
  return ref.watch(historyServiceProvider).getAvailableYears();
});

final yearRecapProvider =
    FutureProvider.autoDispose.family<YearRecapModel, int>((ref, year) {
  return ref.watch(historyServiceProvider).getYearRecap(year);
});
