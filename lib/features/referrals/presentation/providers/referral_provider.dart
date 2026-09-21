import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/referral_models.dart';
import '../../data/referral_service.dart';

final referralServiceProvider =
    Provider<ReferralService>((ref) => ReferralService());

final referralMeProvider = FutureProvider.autoDispose<ReferralMe>((ref) async {
  return ref.watch(referralServiceProvider).me();
});
