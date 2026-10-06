import 'package:flutter/material.dart';

/// Crest from the backend (provider CDN) or initials fallback. Never invents URLs.
class FootballTeamCrest extends StatelessWidget {
  const FootballTeamCrest({super.key, required this.name, this.url, this.size = 36});
  final String name;
  final String? url;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(_initials,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.32,
              color: colors.onSurface)),
    );
    final crest = url;
    if (crest == null || crest.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(crest, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback),
    );
  }
}
