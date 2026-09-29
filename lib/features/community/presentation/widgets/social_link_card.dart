import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/linked_text.dart';

class SocialLink {
  const SocialLink(this.provider, this.uri);
  final String provider;
  final Uri uri;
}

SocialLink? firstSocialLink(String content) {
  for (final link in httpLinks(content)) {
    final host = link.uri.host.toLowerCase();
    final segments = link.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if ((host == 'youtube.com' || host == 'www.youtube.com' ||
         host == 'm.youtube.com') &&
        ((link.uri.path == '/watch' && link.uri.queryParameters['v']?.isNotEmpty == true) ||
         (segments.length == 2 && ['shorts', 'embed', 'live'].contains(segments.first)))) {
      return SocialLink('YouTube', link.uri);
    }
    if (host == 'youtu.be' && segments.length == 1) {
      return SocialLink('YouTube', link.uri);
    }
    if ((host == 'tiktok.com' || host == 'www.tiktok.com' || host == 'm.tiktok.com') &&
        segments.length >= 3 && segments.first.startsWith('@') &&
        segments[1] == 'video' && segments[2].isNotEmpty) {
      return SocialLink('TikTok', link.uri);
    }
    if ((host == 'instagram.com' || host == 'www.instagram.com') &&
        segments.length >= 2 && ['p', 'reel'].contains(segments.first) &&
        segments[1].isNotEmpty) {
      return SocialLink('Instagram', link.uri);
    }
  }
  return null;
}

class SocialLinkCard extends StatelessWidget {
  const SocialLinkCard({super.key, required this.link});
  final SocialLink link;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: OutlinedButton(
      onPressed: () => launchUrl(link.uri, mode: LaunchMode.externalApplication),
      child: Row(children: [
        const Icon(Icons.open_in_new, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
            Text(link.provider),
            Text(link.uri.host, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
          ],
        )),
        const SizedBox(width: 8),
        const Text('Abrir'),
      ]),
    ),
  );
}
