import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// HTTP(S) links in otherwise plain text. No metadata is requested.
class LinkedText extends StatefulWidget {
  const LinkedText(this.text, {super.key, required this.style, this.maxLines,
    this.overflow, this.onOpenLink});

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final ValueChanged<Uri>? onOpenLink;

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
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in httpLinks(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final recognizer = _recognizers.putIfAbsent(match.start,
          () => TapGestureRecognizer())
        ..onTap = () {
          if (widget.onOpenLink case final open?) {
            open(match.uri);
          } else {
            launchUrl(match.uri, mode: LaunchMode.externalApplication);
          }
        };
      spans.add(TextSpan(text: match.text,
          style: widget.style.copyWith(decoration: TextDecoration.underline),
          recognizer: recognizer));
      cursor = match.end;
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
