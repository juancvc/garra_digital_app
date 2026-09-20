import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/passport_models.dart';
import '../../data/passport_service.dart';

final passportServiceProvider = Provider<PassportService>((ref) {
  return PassportService();
});

final myPassportProvider = FutureProvider.autoDispose<PassportModel>((ref) async {
  return ref.watch(passportServiceProvider).getMyPassport();
});
