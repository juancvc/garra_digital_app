import '../data/push_device_service.dart';

/// Coordinates FCM registration after authentication without touching AuthService.
///
/// Ensures [onTokenRefresh] is subscribed at most once per process lifetime.
class PushSessionCoordinator {
  PushSessionCoordinator({
    Future<void> Function()? register,
    void Function()? listen,
  })  : _register = register,
        _listen = listen;

  final Future<void> Function()? _register;
  final void Function()? _listen;

  bool _refreshListening = false;

  /// Call after successful login / Google / profile completion.
  Future<void> afterAuthenticated() => _activate();

  /// Call on app start when a session token already exists.
  Future<void> bootstrapIfAuthenticated({required bool hasAuth}) async {
    if (!hasAuth) return;
    await _activate();
  }

  Future<void> _activate() async {
    try {
      final register = _register;
      if (register != null) {
        await register();
      } else {
        await PushDeviceService().registerCurrentToken();
      }
    } catch (_) {
      // Best-effort — never block auth navigation.
    }

    if (!_refreshListening) {
      _refreshListening = true;
      try {
        final listen = _listen;
        if (listen != null) {
          listen();
        } else {
          PushDeviceService().listenForRefresh();
        }
      } catch (_) {}
    }
  }
}

/// Process-wide coordinator used by login + main bootstrap.
final PushSessionCoordinator pushSessionCoordinator = PushSessionCoordinator();
