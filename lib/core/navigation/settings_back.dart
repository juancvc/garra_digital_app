import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Canonical parent when a settings-related route has no [GoRouter] history.
String settingsBackFallback(String routePath) {
  if (routePath == '/settings') return '/passport';
  if (routePath == '/settings/help/guide' ||
      routePath == '/settings/help/faq' ||
      routePath == '/settings/help/diagnostics') {
    return '/settings/help';
  }
  if (routePath.startsWith('/settings/')) return '/settings';
  return '/passport';
}

void settingsNavigateBack(BuildContext context, String routePath) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  final router = GoRouter.maybeOf(context);
  if (router == null) return;
  final fallback = settingsBackFallback(routePath);
  if (router.routeInformationProvider.value.uri.path != fallback) {
    router.go(fallback);
  }
}

/// Android Back + AppBar back for settings stack pages without a false exit.
class GarraSettingsRouteScope extends StatelessWidget {
  const GarraSettingsRouteScope({
    super.key,
    required this.routePath,
    required this.child,
  });

  final String routePath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return PopScope(
      canPop: navigator.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) settingsNavigateBack(context, routePath);
      },
      child: child,
    );
  }
}

PreferredSizeWidget garraSettingsAppBar(
  BuildContext context, {
  required String routePath,
  required String title,
}) {
  return AppBar(
    title: Text(title),
    leading: BackButton(
      onPressed: () => settingsNavigateBack(context, routePath),
    ),
  );
}
