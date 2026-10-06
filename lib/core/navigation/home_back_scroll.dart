import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Only the currently visible Home list participates in root Back handling.
final homeBackScrollProvider =
    NotifierProvider<HomeBackScroll, bool>(HomeBackScroll.new);

class HomeBackScroll extends Notifier<bool> {
  static const double threshold = 96;
  ScrollController? _active;
  bool _publishScheduled = false;

  @override
  bool build() => false;

  void attach(ScrollController controller) {
    if (identical(_active, controller)) return;
    _active?.removeListener(_update);
    _active = controller;
    controller.addListener(_update);
    _update();
  }

  void detach(ScrollController controller) {
    if (!identical(_active, controller)) return;
    controller.removeListener(_update);
    _active = null;
    _publish(false);
  }

  void _update() {
    final controller = _active;
    final scrolled = controller != null &&
        controller.hasClients &&
        controller.offset > threshold;
    _publish(scrolled);
  }

  /// SONIC_01: lists attach/detach from initState/dispose, i.e. while the
  /// widget tree is being built or finalized, and MainShell watches this
  /// provider. Riverpod forbids modifying a provider at that moment ("Tried to
  /// modify a provider while the widget tree was building"), so a change
  /// requested during the build phase is recomputed right after the frame.
  void _publish(bool scrolled) {
    if (state == scrolled) return;
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      state = scrolled;
      return;
    }
    if (_publishScheduled) return;
    _publishScheduled = true;
    binding.addPostFrameCallback((_) {
      _publishScheduled = false;
      if (ref.mounted) _update();
    });
    binding.ensureVisualUpdate();
  }

  void scrollToTop() {
    final controller = _active;
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }
}
