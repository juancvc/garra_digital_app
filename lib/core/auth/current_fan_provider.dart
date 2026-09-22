import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_service.dart';
import '../../features/auth/data/auth_user.dart';

/// Session identity loaded once for UI (isMine, admin, avatars).
final currentFanProvider =
    AsyncNotifierProvider<CurrentFanNotifier, AuthUser?>(CurrentFanNotifier.new);

class CurrentFanNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    try {
      return await AuthService().me();
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  void clear() {
    state = const AsyncData(null);
  }
}

String? currentFanIdOf(WidgetRef ref) =>
    ref.watch(currentFanProvider).asData?.value?.id;

bool isAdminOf(WidgetRef ref) {
  final me = ref.watch(currentFanProvider).asData?.value;
  return me?.isAdmin == true || me?.isSuperAdmin == true;
}
