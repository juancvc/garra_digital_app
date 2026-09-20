import 'package:url_launcher/url_launcher.dart';

typedef MarketplaceUrlLauncher = Future<bool> Function(Uri uri);

/// Overridable for tests; production uses url_launcher.
MarketplaceUrlLauncher marketplaceUrlLauncher = (uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
};
