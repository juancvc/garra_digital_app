import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkConnectivity { online, degraded, offline }

abstract interface class ConnectivitySource {
  Future<List<ConnectivityResult>> check();
  Stream<List<ConnectivityResult>> get changes;
}

class PluginConnectivitySource implements ConnectivitySource {
  PluginConnectivitySource({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> check() => _connectivity.checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}

final connectivitySourceProvider = Provider<ConnectivitySource>(
  (ref) => PluginConnectivitySource(),
);

final connectivityStatusProvider =
    NotifierProvider<ConnectivityStatusController, NetworkConnectivity>(
      ConnectivityStatusController.new,
    );

class ConnectivityStatusController extends Notifier<NetworkConnectivity> {
  bool? _hasTransport;

  @override
  NetworkConnectivity build() {
    final source = ref.watch(connectivitySourceProvider);
    var active = true;
    var receivedEvent = false;
    final subscription = source.changes.listen((results) {
      if (!active) return;
      receivedEvent = true;
      _applyTransport(results);
    });
    ref.onDispose(() {
      active = false;
      subscription.cancel();
    });
    unawaited(() async {
      try {
        final results = await source.check();
        if (active && !receivedEvent) _applyTransport(results);
      } catch (_) {
        // A failed platform check does not prove that the device is offline.
      }
    }());
    // No known failure yet. ONLINE is not proof that the API or R2 is healthy.
    return NetworkConnectivity.online;
  }

  void _applyTransport(List<ConnectivityResult> results) {
    final available = results.any(
      (result) => result != ConnectivityResult.none,
    );
    _hasTransport = available;
    if (!available) {
      state = NetworkConnectivity.offline;
    } else if (state == NetworkConnectivity.offline) {
      state = NetworkConnectivity.online;
    }
    // Preserve DEGRADED until a future request-health signal clears it.
  }

  /// Reserved for later request/latency observation; does not issue a request.
  void reportDegraded() {
    if (_hasTransport != false) state = NetworkConnectivity.degraded;
  }

  /// Reserved for later request-health observation; does not issue a request.
  void reportHealthy() {
    if (_hasTransport != false) state = NetworkConnectivity.online;
  }
}
