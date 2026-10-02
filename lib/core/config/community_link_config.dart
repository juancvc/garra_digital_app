/// Public HTTPS origin owned by Garra. Supply it at build time with
/// --dart-define=GARRA_PUBLIC_BASE_URL=https://verified-host.example.
class CommunityLinkConfig {
  const CommunityLinkConfig._();

  static const publicBaseUrl = String.fromEnvironment('GARRA_PUBLIC_BASE_URL');

  static Uri? communityUri(String slug, {String? baseUrl}) {
    final origin = Uri.tryParse((baseUrl ?? publicBaseUrl).trim());
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/') ||
        !RegExp(r'^[a-z0-9-]+$').hasMatch(slug)) {
      return null;
    }
    return origin.replace(pathSegments: ['comunidades', slug]);
  }

  static String? shareText(String name, String slug, {String? baseUrl}) {
    final link = communityUri(slug, baseUrl: baseUrl);
    return link == null ? null : 'Únete a $name en Garra Digital\n$link';
  }

  /// Only community destinations may survive an authentication redirect.
  static String? safeDestination(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 2 ||
        !['clans', 'comunidades'].contains(uri.pathSegments.first) ||
        !RegExp(r'^[a-z0-9-]+$')
            .hasMatch(uri.pathSegments.last)) {
      return null;
    }
    return '/clans/${uri.pathSegments.last}';
  }
}
