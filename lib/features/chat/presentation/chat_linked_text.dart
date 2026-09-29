import 'package:flutter/material.dart';

import '../../../core/widgets/linked_text.dart';

/// Plain chat text with clickable HTTP(S) URLs. No metadata is fetched.
class ChatLinkedText extends StatelessWidget {
  const ChatLinkedText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LinkedText(text, style: style);
}
