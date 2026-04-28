import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prediction_service.dart';

final predictionServiceProvider = Provider<PredictionService>((ref) {
  return PredictionService();
});

final myPredictionsProvider = FutureProvider((ref) async {
  final service = ref.read(predictionServiceProvider);
  return service.getMyPredictions();
});