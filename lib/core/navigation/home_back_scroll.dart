import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Only the currently visible Home list participates in root Back handling.
final homeBackScrollProvider =
    NotifierProvider<HomeBackScroll, bool>(HomeBackScroll.new);

class HomeBackScroll extends Notifier<bool> {
  static const double threshold = 96;
  ScrollController? _active;

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
    state = false;
  }

  void _update() {
    final controller = _active;
    final scrolled = controller != null &&
        controller.hasClients &&
        controller.offset > threshold;
    if (state != scrolled) state = scrolled;
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
