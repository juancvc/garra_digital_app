import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialProfileLinks extends StatelessWidget {
  const SocialProfileLinks({super.key, this.instagramUrl, this.tiktokUrl, this.youtubeUrl});

  final String? instagramUrl;
  final String? tiktokUrl;
  final String? youtubeUrl;

  static bool _safe(String? value, String host) {
    if (value == null || value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty &&
        !uri.hasPort && (uri.host == host || uri.host == 'www.$host');
  }

  @override
  Widget build(BuildContext context) {
    final links = <(String, String)>[
      if (_safe(instagramUrl, 'instagram.com')) ('Instagram', instagramUrl!),
      if (_safe(tiktokUrl, 'tiktok.com')) ('TikTok', tiktokUrl!),
      if (_safe(youtubeUrl, 'youtube.com')) ('YouTube', youtubeUrl!),
    ];
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        for (final (name, url) in links)
          ActionChip(
            label: Text(name),
            onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
      ],
    );
  }
}
