import 'dart:async';

import 'package:flutter/widgets.dart';

/// ANALYTICS_12: fires [onVisible] once when [child] has been at least
/// [threshold] visible (area fraction) for an uninterrupted [dwell].
///
/// Lightweight, no extra packages: it listens to the enclosing
/// [ScrollPosition] (checking after the next layout, so geometry is fresh)
/// and measures the child's [RenderBox] against the
/// scrollable viewport (and the screen). A timer starts when the fraction
/// crosses the threshold and is cancelled if it drops below it before the
/// dwell elapses; on fire the geometry is re-checked. Building a card never
/// counts by itself. Hidden routes/tabs (not current, TickerMode off) never
/// count.
class GarraViewportTracker extends StatefulWidget {
  const GarraViewportTracker({
    super.key,
    required this.id,
    required this.onVisible,
    required this.child,
    this.enabled = true,
    this.threshold = 0.5,
    this.dwell = const Duration(seconds: 1),
  });

  /// Identity of the tracked item; changing it re-arms the tracker.
  final String id;
  final VoidCallback onVisible;
  final Widget child;
  final bool enabled;
  final double threshold;
  final Duration dwell;

  @override
  State<GarraViewportTracker> createState() => _GarraViewportTrackerState();
}

class _GarraViewportTrackerState extends State<GarraViewportTracker> {
  ScrollPosition? _position;
  Timer? _timer;
  bool _fired = false;
  bool _checkScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_scheduleCheck);
      _position = position;
      _position?.addListener(_scheduleCheck);
    }
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(covariant GarraViewportTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _fired = false;
      _cancel();
    }
    _scheduleCheck();
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleCheck);
    _cancel();
    super.dispose();
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      _check();
    });
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _check() {
    if (!mounted || _fired || !widget.enabled) {
      _cancel();
      return;
    }
    if (_isVisibleEnough()) {
      _timer ??= Timer(widget.dwell, _onDwellElapsed);
    } else {
      _cancel();
    }
  }

  void _onDwellElapsed() {
    _timer = null;
    if (!mounted || _fired || !widget.enabled) return;
    if (!_isVisibleEnough()) return;
    _fired = true;
    widget.onVisible();
  }

  bool _isVisibleEnough() {
    if (!TickerMode.valuesOf(context).enabled) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return visibleFraction() >= widget.threshold;
  }

  /// Visible area fraction (0..1) of the child inside viewport and screen.
  double visibleFraction() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return 0;
    final size = box.size;
    if (size.isEmpty) return 0;
    final rect = box.localToGlobal(Offset.zero) & size;

    final screenSize = MediaQuery.maybeSizeOf(context);
    var visible = screenSize == null
        ? rect
        : rect.intersect(Offset.zero & screenSize);

    final scrollBox = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (scrollBox is RenderBox && scrollBox.attached && scrollBox.hasSize) {
      visible = visible.intersect(
        scrollBox.localToGlobal(Offset.zero) & scrollBox.size,
      );
    }
    if (visible.width <= 0 || visible.height <= 0) return 0;
    return (visible.width * visible.height) / (size.width * size.height);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
