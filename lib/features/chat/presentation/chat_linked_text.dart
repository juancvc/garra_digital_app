import 'package:flutter/material.dart';

import '../../../core/widgets/linked_text.dart';
import '../../../core/widgets/mention_span.dart';

/// Plain chat text with clickable HTTP(S) URLs. No metadata is fetched.
class ChatLinkedText extends StatelessWidget {
  const ChatLinkedText(this.text, {super.key, required this.style,
    this.mentions = const [], this.onOpenMention});
  final String text;
  final TextStyle style;
  final List<MentionSpan> mentions;
  final ValueChanged<String>? onOpenMention;

  @override
  Widget build(BuildContext context) => LinkedText(text, style: style,
    mentions: mentions, onOpenMention: onOpenMention);
}
