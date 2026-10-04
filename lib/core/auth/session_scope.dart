import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart'
    show currentUserProvider;
import '../../features/community/presentation/providers/community_provider.dart'
    show followStateProvider, myWallPostsProvider, wallStatusProvider;
import '../../features/home/presentation/providers/home_provider.dart';
import '../../features/locations/presentation/providers/checkin_provider.dart'
    as checkins;
import '../../features/locations/presentation/providers/location_provider.dart'
    as locations
    show myCheckInsProvider;
import '../../features/predictions/presentation/providers/prediction_provider.dart'
    show myPredictionsProvider;
import 'current_fan_provider.dart';
import 'session_events.dart';

/// Providers that hold one person's data and are not auto-disposed: they must
/// not outlive the session (logout A -> login B would otherwise show A).
/// Auto-disposed providers rebuild by themselves when listened again.
void resetUserScopedProviders(ProviderContainer container) {
  container
    ..invalidate(currentFanProvider)
    ..invalidate(currentUserProvider)
    ..invalidate(followStateProvider)
    ..invalidate(wallStatusProvider)
    ..invalidate(myWallPostsProvider)
    ..invalidate(checkins.myCheckInsProvider)
    ..invalidate(locations.myCheckInsProvider)
    ..invalidate(myPredictionsProvider);
}

/// Single place that reacts to [SessionEvents] and to the app coming back from
/// the background. Mounted once, above the router's pages.
class SessionScope extends ConsumerStatefulWidget {
  const SessionScope({
    super.key,
    required this.router,
    required this.child,
    this.resumeRefreshAfter = const Duration(seconds: 45),
  });

  final GoRouter router;
  final Widget child;

  /// A background stay shorter than this does not refresh anything.
  final Duration resumeRefreshAfter;

  @override
  ConsumerState<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends ConsumerState<SessionScope>
    with WidgetsBindingObserver {
  StreamSubscription<SessionEventKind>? _sub;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = SessionEvents.stream.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onEvent(SessionEventKind kind) {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    switch (kind) {
      case SessionEventKind.ended:
        resetUserScopedProviders(container);
      case SessionEventKind.expired:
        resetUserScopedProviders(container);
        widget.router.go('/welcome');
      case SessionEventKind.membershipRequired:
        container.invalidate(currentFanProvider);
        final path = widget.router.routeInformationProvider.value.uri.path;
        if (path != '/complete-profile') widget.router.go('/complete-profile');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final since = _pausedAt;
    _pausedAt = null;
    if (since == null || !mounted) return;
    if (DateTime.now().difference(since) < widget.resumeRefreshAfter) return;
    // Home (bell badge, match card) is stale after a long stay in background.
    // Chat unread already reconciles itself on resume. Home keeps what it
    // shows while it reloads, so this never resets its tab or scroll.
    ProviderScope.containerOf(context, listen: false).invalidate(homeProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
