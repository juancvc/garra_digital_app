import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Plain chat text with clickable HTTP(S) URLs. No metadata is fetched.
class ChatLinkedText extends StatefulWidget {
  const ChatLinkedText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<ChatLinkedText> createState() => _ChatLinkedTextState();
}

class _ChatLinkedTextState extends State<ChatLinkedText> {
  final _recognizers = <int, TapGestureRecognizer>{};
  static final _url = RegExp(r'https?://[^\s<>]+', caseSensitive: false);

  @override
  void didUpdateWidget(covariant ChatLinkedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
    }
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
    for (final match in _url.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final raw = match.group(0)!;
      final link = raw.replaceFirst(RegExp(r'[.,!?;:]+$'), '');
      final suffix = raw.substring(link.length);
      final uri = Uri.tryParse(link);
      if (uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        final recognizer = _recognizers.putIfAbsent(
          match.start,
          () => TapGestureRecognizer(),
        )..onTap = () => launchUrl(uri, mode: LaunchMode.externalApplication);
        spans.add(
          TextSpan(
            text: link,
            style: widget.style.copyWith(decoration: TextDecoration.underline),
            recognizer: recognizer,
          ),
        );
      } else {
        spans.add(TextSpan(text: link));
      }
      if (suffix.isNotEmpty) spans.add(TextSpan(text: suffix));
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return Text.rich(
      TextSpan(children: spans),
      style: widget.style,
      softWrap: true,
    );
  }
}
