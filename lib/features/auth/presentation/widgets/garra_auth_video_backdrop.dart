import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// One video session shared by all mounted Auth routes. The still image stays
/// beneath it so initialization and playback failure never blank the stadium.
class GarraAuthVideoBackdrop extends StatefulWidget {
  const GarraAuthVideoBackdrop({super.key});

  static const asset = 'assets/images/auth/garra_stadium_alive.mp4';

  @override
  State<GarraAuthVideoBackdrop> createState() => _GarraAuthVideoBackdropState();
}

class _GarraAuthVideoBackdropState extends State<GarraAuthVideoBackdrop> {
  static final _session = _AuthVideoSession();
  bool _attached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = !MediaQuery.disableAnimationsOf(context);
    if (enabled && !_attached) {
      _session.attach(_changed);
      _attached = true;
    } else if (!enabled && _attached) {
      _session.detach(_changed);
      _attached = false;
    }
    if (_attached) {
      _session.setVisible(_changed, ModalRoute.of(context)?.isCurrent ?? true);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_attached) _session.detach(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _attached ? _session.readyController : null;
    if (controller == null) return const SizedBox.expand();
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) return const SizedBox.expand();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

class _AuthVideoSession with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  final Set<VoidCallback> _listeners = {};
  final Set<Object> _visible = {};
  bool _ready = false;
  bool _failed = false;
  bool _foreground = true;

  VideoPlayerController? get readyController =>
      _ready && !_failed ? _controller : null;

  void attach(VoidCallback listener) {
    _listeners.add(listener);
    if (_controller != null || _failed) return;
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void detach(VoidCallback listener) {
    _listeners.remove(listener);
    _visible.remove(listener);
    if (_listeners.isNotEmpty) {
      _syncPlayback();
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    _ready = false;
    _failed = false;
    _visible.clear();
    if (controller != null) unawaited(controller.dispose());
  }

  void setVisible(Object listener, bool visible) {
    if (visible) {
      _visible.add(listener);
    } else {
      _visible.remove(listener);
    }
    _syncPlayback();
  }

  Future<void> _start() async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.asset(GarraAuthVideoBackdrop.asset);
      _controller = controller;
      controller.addListener(_onVideoChanged);
      await controller.initialize();
      if (_controller != controller) return;
      await controller.setLooping(true);
      if (_controller != controller) return;
      await controller.setVolume(0);
      if (_controller != controller) return;
      _ready = true;
      _notify();
      _syncPlayback();
    } catch (_) {
      if (_controller != controller) return;
      _failed = true;
      _ready = false;
      _notify();
    }
  }

  void _onVideoChanged() {
    if (_controller?.value.hasError == true && !_failed) {
      _failed = true;
      _ready = false;
      _notify();
    }
  }

  void _syncPlayback() {
    final controller = readyController;
    if (controller == null) return;
    if (_foreground && _visible.isNotEmpty) {
      if (!controller.value.isPlaying) unawaited(_safely(controller.play));
    } else if (controller.value.isPlaying) {
      unawaited(_safely(controller.pause));
    }
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      _failed = true;
      _ready = false;
      _notify();
    }
  }

  void _notify() {
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }
}
