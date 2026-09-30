import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/garra_semantic_colors.dart';
import '../../data/post_location.dart';

class PostLocationLabel extends StatelessWidget {
  const PostLocationLabel({super.key, required this.location, this.openExternal});
  final PostLocation location;
  final Future<bool> Function(Uri)? openExternal;

  Future<void> _openMap(BuildContext context, String label) async {
    final uri = Uri.https('www.google.com', '/maps/search/',
        {'api': '1', 'query': label});
    try {
      final opened = await (openExternal?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(const SnackBar(
        content: Text('No se pudo abrir el mapa')));
  }

  @override
  Widget build(BuildContext context) {
    final label = location.name.trim();
    final canOpen = label.isNotEmpty &&
        label.toLowerCase() != 'zona aproximada';
    final content = Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.place_outlined, size: 15),
      const SizedBox(width: 3),
      Flexible(child: Text(location.name, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: canOpen ? context.garraColors.brandPrimary : null,
              decoration: canOpen ? TextDecoration.underline : null))),
      if (canOpen) const Padding(
          padding: EdgeInsets.only(left: 3),
          child: Icon(Icons.open_in_new, size: 12)),
    ]);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: canOpen ? Tooltip(message: 'Abrir en Maps', child: InkWell(
          onTap: () => _openMap(context, label), child: content)) : content,
    );
  }
}
