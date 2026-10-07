import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/garra_semantic_colors.dart';
import '../design/garra_colors.dart';

/// Independent versioned first-use flags; the guide remains available in Help.
class DiscoveryTipStore {
  const DiscoveryTipStore();

  Future<bool> hasSeen(String id) async =>
      (await SharedPreferences.getInstance()).getBool('discovery.$id') ?? false;

  Future<void> markSeen(String id) async =>
      (await SharedPreferences.getInstance()).setBool('discovery.$id', true);
}

class GarraDiscoveryTip extends StatefulWidget {
  const GarraDiscoveryTip({super.key, required this.id, required this.title,
    required this.message, this.actionLabel, this.onAction, this.store});

  final String id;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final DiscoveryTipStore? store;

  @override
  State<GarraDiscoveryTip> createState() => _GarraDiscoveryTipState();
}

class _GarraDiscoveryTipState extends State<GarraDiscoveryTip> {
  bool _visible = false;
  bool _disposing = false;
  LocalHistoryEntry? _historyEntry;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final store = widget.store ?? const DiscoveryTipStore();
    if (await store.hasSeen(widget.id)) return;
    // Count the automatic appearance once, including when the user navigates away.
    await store.markSeen(widget.id);
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null) {
      final entry = LocalHistoryEntry(onRemove: () {
        _historyEntry = null;
        if (mounted && !_disposing) setState(() => _visible = false);
      });
      _historyEntry = entry;
      route.addLocalHistoryEntry(entry);
    }
    setState(() => _visible = true);
  }

  void _close() {
    if (_historyEntry != null) {
      _historyEntry!.remove();
    } else {
      setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _historyEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final colors = context.garraColors;
    return SafeArea(
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.brandPrestige.withValues(alpha: .3)),
              gradient: const LinearGradient(colors: [
                Color(GarraColors.surfaceRaised), Color(GarraColors.burgundyDeep),
              ]),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    ExcludeSemantics(child: ClipOval(child: Image.asset(
                      'assets/brand/intro/garra_puma.png', width: 36, height: 36,
                      cacheWidth: 72, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(Icons.lightbulb_outline,
                        color: colors.brandPrestige),
                    ))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(GarraColors.cream),
                          fontWeight: FontWeight.w800))),
                    IconButton(
                      tooltip: 'Cerrar ayuda',
                      onPressed: _close,
                      icon: const Icon(Icons.close, color: Color(GarraColors.cream)),
                    ),
                  ]),
                  Text(widget.message, style: const TextStyle(
                    color: Color(GarraColors.cream), height: 1.35)),
                  if (widget.actionLabel != null && widget.onAction != null)
                    TextButton(onPressed: () {
                      _close();
                      widget.onAction!();
                    }, child: Text(widget.actionLabel!)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Places a small dismissible tip above existing page content without changing it.
class GarraDiscoverySurface extends StatelessWidget {
  const GarraDiscoverySurface({super.key, required this.child, required this.id,
    required this.title, required this.message, this.actionLabel, this.onAction});
  final Widget child;
  final String id;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Stack(children: [
    child,
    Positioned(left: 12, right: 12, bottom: 12,
      child: GarraDiscoveryTip(id: id, title: title, message: message,
        actionLabel: actionLabel, onAction: onAction)),
  ]);
}
