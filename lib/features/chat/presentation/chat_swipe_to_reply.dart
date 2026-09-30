import 'package:flutter/material.dart';

/// Horizontal reply gesture shared by private and community message bubbles.
/// The horizontal recognizer lets the surrounding list keep vertical drags.
class ChatSwipeToReply extends StatefulWidget {
  const ChatSwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback onReply;
  final VoidCallback? onLongPress;

  @override
  State<ChatSwipeToReply> createState() => _ChatSwipeToReplyState();
}

class _ChatSwipeToReplyState extends State<ChatSwipeToReply> {
  static const double _threshold = 64;
  double _offset = 0;
  bool _dragging = false;

  void _finish() {
    if (_offset >= _threshold) widget.onReply();
    setState(() {
      _dragging = false;
      _offset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.onLongPress,
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (details) => setState(() {
        _offset = (_offset + details.primaryDelta!).clamp(0, 88);
      }),
      onHorizontalDragEnd: (_) => _finish(),
      onHorizontalDragCancel: () => setState(() {
        _dragging = false;
        _offset = 0;
      }),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Opacity(
                opacity: (_offset / _threshold).clamp(0, 1),
                child: const Icon(Icons.reply_rounded, size: 22),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _offset),
            duration: _dragging ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: widget.child,
            builder: (_, value, child) => Transform.translate(
              offset: Offset(value, 0), child: child),
          ),
        ],
      ),
    );
  }
}
