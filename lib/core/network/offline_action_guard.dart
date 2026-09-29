import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_status.dart';

const offlineActionMessage = 'Necesitas conexión a internet para continuar';

/// Call immediately before a user-initiated network operation. DEGRADED remains
/// usable; this guard only stops a known absence of network transport.
bool allowNetworkAction(BuildContext context) {
  ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
  } on StateError {
    // Legacy isolated widgets have no app-level ProviderScope.
    return true;
  }
  if (container.read(connectivityStatusProvider) !=
      NetworkConnectivity.offline) {
    return true;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..clearSnackBars()
    ..showSnackBar(const SnackBar(content: Text(offlineActionMessage)));
  return false;
}
