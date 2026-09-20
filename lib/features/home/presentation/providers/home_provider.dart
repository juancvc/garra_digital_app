import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/home_models.dart';
import '../../data/home_service.dart';

final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService();
});

final homeProvider = FutureProvider.autoDispose<HomeModel>((ref) async {
  return ref.watch(homeServiceProvider).getHome();
});
