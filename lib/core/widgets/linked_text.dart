import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'mention_span.dart';

/// HTTP(S) links in otherwise plain text. No metadata is requested.
class LinkedText extends StatefulWidget {
  const LinkedText(this.text, {super.key, required this.style, this.maxLines,
    this.overflow, this.onOpenLink, this.mentions = const [], this.onOpenMention,
    this.prefix, this.prefixStyle});

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final ValueChanged<Uri>? onOpenLink;
  final List<MentionSpan> mentions;
  final ValueChanged<String>? onOpenMention;
  final String? prefix;
  final TextStyle? prefixStyle;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  final _recognizers = <int, TapGestureRecognizer>{};

  @override
  void didUpdateWidget(covariant LinkedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _disposeRecognizers();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[
      if (widget.prefix case final prefix?) TextSpan(text: prefix,
          style: widget.prefixStyle ?? widget.style.copyWith(fontWeight: FontWeight.w800)),
    ];
    var cursor = 0;
    final links = httpLinks(widget.text).toList();
    final spansToOpen = <(int, int, String, Uri?, String?)>[
      for (final link in links) (link.start, link.end, link.text, link.uri, null),
      for (final mention in widget.mentions)
        if (mention.validFor(widget.text) &&
            !links.any((link) => mention.start < link.end && mention.end > link.start))
          (mention.start, mention.end,
              widget.text.substring(mention.start, mention.end), null, mention.userId),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final match in spansToOpen) {
      if (match.$1 < cursor) continue;
      if (match.$1 > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.$1)));
      }
      final recognizer = _recognizers.putIfAbsent(match.$1,
          () => TapGestureRecognizer())
        ..onTap = () {
          if (match.$5 case final userId?) {
            widget.onOpenMention?.call(userId);
          } else if (widget.onOpenLink case final open?) {
            open(match.$4!);
          } else {
            launchUrl(match.$4!, mode: LaunchMode.externalApplication);
          }
        };
      spans.add(TextSpan(text: match.$3,
          style: widget.style.copyWith(decoration: match.$5 == null
              ? TextDecoration.underline : TextDecoration.none,
              fontWeight: match.$5 == null ? null : FontWeight.w700),
          recognizer: recognizer));
      cursor = match.$2;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return Text.rich(TextSpan(children: spans), style: widget.style,
        maxLines: widget.maxLines, overflow: widget.overflow,
        softWrap: true);
  }
}

class HttpLink {
  const HttpLink(this.start, this.end, this.text, this.uri);
  final int start;
  final int end;
  final String text;
  final Uri uri;
}

final _urlPattern = RegExp(r'https?://[^\s<>]+', caseSensitive: false);

Iterable<HttpLink> httpLinks(String text) sync* {
  for (final match in _urlPattern.allMatches(text)) {
    final raw = match.group(0)!;
    final link = raw.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
    final uri = Uri.tryParse(link);
    if (uri == null || !['http', 'https'].contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        uri.host.contains('..') || uri.host.startsWith('.') ||
        uri.host.endsWith('.')) {
      continue;
    }
    yield HttpLink(match.start, match.start + link.length, link, uri);
  }
}
