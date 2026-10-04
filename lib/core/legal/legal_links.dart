import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';

/// Absolute URL of a backend legal page (`/legal/privacy`, `/legal/terms`,
/// `/legal/community`). Shared by Settings and the Garra profile so both open
/// exactly the same document.
Uri resolveLegalUri(String? pathOrUrl) {
  if (pathOrUrl == null || pathOrUrl.isEmpty) {
    return Uri.parse(ApiConfig.baseUrl.replaceAll('/api/v1', '/legal/privacy'));
  }
  if (pathOrUrl.startsWith('http')) return Uri.parse(pathOrUrl);
  final root = ApiConfig.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
  return Uri.parse('$root$pathOrUrl');
}

/// Opens "Normas de comunidad". Returns false (never throws) when the device
/// cannot open it, so callers can show a friendly message.
Future<bool> openCommunityGuidelines() async {
  try {
    return await launchUrl(
      resolveLegalUri('/legal/community'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
