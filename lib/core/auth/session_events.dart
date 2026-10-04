import 'dart:async';

/// What happened to the session, announced from places that have no
/// BuildContext (the Dio interceptors, [AuthService.logout]). One listener,
/// [SessionScope], turns it into provider resets and navigation, so no screen
/// needs its own copy of that logic.
enum SessionEventKind {
  /// The user signed out (or deleted the account): user-scoped state must go.
  ended,

  /// The server definitively rejected the refresh token: sign in again.
  expired,

  /// HTTP 403 + `errors.code == MEMBERSHIP_REQUIRED`: the Garra profile is
  /// still pending, so only /complete-profile makes sense.
  membershipRequired,
}

class SessionEvents {
  SessionEvents._();

  static final StreamController<SessionEventKind> _controller =
      StreamController<SessionEventKind>.broadcast();

  static Stream<SessionEventKind> get stream => _controller.stream;

  static void emit(SessionEventKind kind) {
    if (!_controller.isClosed) _controller.add(kind);
  }
}
