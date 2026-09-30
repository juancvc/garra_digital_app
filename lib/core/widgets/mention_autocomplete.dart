import 'dart:async';
import 'package:flutter/material.dart';

import 'garra_avatar.dart';

class MentionCandidate {
  const MentionCandidate({required this.id, required this.username,
    required this.displayName, this.avatarUrl});
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
}

bool isMentionableUsername(String username) =>
    RegExp(r'^[\p{L}\p{N}_]{3,60}$', unicode: true).hasMatch(username);

class ActiveMentionToken {
  const ActiveMentionToken(this.start, this.end, this.query);
  final int start;
  final int end;
  final String query;
}

/// TextEditingController and Java String use UTF-16 code-unit offsets.
ActiveMentionToken? activeMentionToken(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid) return null;
  final cursor = selection.extentOffset;
  if (cursor < 0 || cursor > value.text.length) return null;
  final before = value.text.substring(0, cursor);
  final currentWord = before.split(RegExp(r'\s')).last;
  if (currentWord.startsWith('http://') || currentWord.startsWith('https://')) return null;
  final match = RegExp(r'(^|[^\p{L}\p{N}_@])@([\p{L}\p{N}_]*)$',
      unicode: true).firstMatch(before);
  if (match == null) return null;
  final start = match.end - match.group(2)!.length - 1;
  var end = cursor;
  while (end < value.text.length && RegExp(r'[\p{L}\p{N}_]',
      unicode: true).hasMatch(value.text[end])) {
    end++;
  }
  return ActiveMentionToken(start, end, match.group(2)!);
}

void insertMention(TextEditingController controller, ActiveMentionToken token,
    MentionCandidate candidate) {
  final old = controller.value.text;
  final replacement = '@${candidate.username} ';
  final end = token.end < old.length && old[token.end] == ' '
      ? token.end + 1 : token.end;
  final updated = old.replaceRange(token.start, end, replacement);
  controller.value = TextEditingValue(text: updated,
      selection: TextSelection.collapsed(offset: token.start + replacement.length));
}

/// Small inline suggestion surface. The parent keeps its existing plain TextField.
class MentionAutocomplete extends StatefulWidget {
  const MentionAutocomplete({super.key, required this.controller, required this.search});
  final TextEditingController controller;
  final Future<List<MentionCandidate>> Function(String query) search;

  @override
  State<MentionAutocomplete> createState() => _MentionAutocompleteState();
}

class _MentionAutocompleteState extends State<MentionAutocomplete> {
  Timer? _timer;
  ActiveMentionToken? _token;
  List<MentionCandidate> _candidates = const [];
  int _generation = 0;

  @override
  void initState() { super.initState(); widget.controller.addListener(_changed); }

  @override
  void didUpdateWidget(covariant MentionAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  void _changed() {
    _timer?.cancel();
    final token = activeMentionToken(widget.controller.value);
    final generation = ++_generation;
    setState(() { _token = token; _candidates = const []; });
    if (token == null) return;
    _timer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final rows = await widget.search(token.query);
        if (!mounted || generation != _generation) return;
        setState(() => _candidates = rows.take(8).toList());
      } catch (_) {
        if (mounted && generation == _generation) setState(() => _candidates = const []);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null || _candidates.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.builder(shrinkWrap: true, itemCount: _candidates.length,
        itemBuilder: (context, index) {
          final candidate = _candidates[index];
          return ListTile(
            dense: true,
            leading: GarraAvatar(displayName: candidate.displayName,
                avatarUrl: candidate.avatarUrl, size: 32),
            title: Text(candidate.displayName),
            subtitle: Text('@${candidate.username}'),
            onTap: () {
              final current = activeMentionToken(widget.controller.value);
              if (current == null) return;
              insertMention(widget.controller, current, candidate);
              setState(() { _token = null; _candidates = const []; });
            },
          );
        },
      ),
    );
  }
}
