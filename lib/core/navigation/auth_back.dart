import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Uses the real Auth stack when present, with a canonical direct-entry exit.
void authNavigateBack(BuildContext context, {String fallback = '/welcome'}) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  final router = GoRouter.maybeOf(context);
  if (router != null &&
      router.routeInformationProvider.value.uri.path != fallback) {
    router.go(fallback);
  }
}

class GarraAuthRouteScope extends StatelessWidget {
  const GarraAuthRouteScope({
    super.key,
    required this.child,
    this.fallback = '/welcome',
  });

  final Widget child;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) authNavigateBack(context, fallback: fallback);
      },
      child: child,
    );
  }
}
