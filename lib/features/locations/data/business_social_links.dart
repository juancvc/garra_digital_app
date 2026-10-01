import '../../marketplace/data/marketplace_url_launcher.dart';

enum BusinessSocialNetwork { instagram, facebook, tiktok }

String socialNetworkLabel(BusinessSocialNetwork network) => switch (network) {
  BusinessSocialNetwork.instagram => 'Instagram',
  BusinessSocialNetwork.facebook => 'Facebook',
  BusinessSocialNetwork.tiktok => 'TikTok',
};

String socialNetworkHost(BusinessSocialNetwork network) => switch (network) {
  BusinessSocialNetwork.instagram => 'www.instagram.com',
  BusinessSocialNetwork.facebook => 'www.facebook.com',
  BusinessSocialNetwork.tiktok => 'www.tiktok.com',
};

/// Accepts only a handle or a matching official HTTPS profile URL.
Uri? businessSocialUri(BusinessSocialNetwork network, String? input) {
  var raw = input?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    final parsed = Uri.tryParse(raw);
    if (parsed == null || parsed.scheme != 'https') return null;
    final host = parsed.host.toLowerCase();
    final official = socialNetworkHost(network);
    if (host != official && host != official.replaceFirst('www.', '')) {
      return null;
    }
    raw =
        parsed.pathSegments.where((part) => part.isNotEmpty).firstOrNull ?? '';
  }
  final handle = raw.replaceFirst(RegExp(r'^@'), '');
  if (!RegExp(r'^[A-Za-z0-9._-]{1,60}$').hasMatch(handle)) return null;
  final segment = network == BusinessSocialNetwork.tiktok ? '@$handle' : handle;
  return Uri.https(socialNetworkHost(network), '/$segment');
}

Future<bool> openBusinessSocial(
  BusinessSocialNetwork network,
  String? input,
) async {
  final uri = businessSocialUri(network, input);
  if (uri == null) return false;
  try {
    return await marketplaceUrlLauncher(uri);
  } catch (_) {
    return false;
  }
}
