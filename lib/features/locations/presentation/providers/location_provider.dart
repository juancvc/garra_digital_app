import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/checkin_model.dart';
import '../../data/crema_point_model.dart';
import '../../data/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final cremaPointsProvider = FutureProvider<List<CremaPointModel>>((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getActivePoints();
});

final myCheckInsProvider = FutureProvider<List<CheckInModel>>((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getMyCheckIns();
});