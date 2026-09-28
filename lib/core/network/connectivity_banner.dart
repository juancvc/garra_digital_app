import 'package:flutter/material.dart';

import 'connectivity_status.dart';

/// A non-interactive overlay: it never replaces or blocks the current route.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({
    super.key,
    required this.status,
    required this.child,
  });

  final NetworkConnectivity status;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (status == NetworkConnectivity.online) return child;

    final offline = status == NetworkConnectivity.offline;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 4,
          left: 12,
          right: 12,
          child: IgnorePointer(
            child: SafeArea(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: offline
                        ? const Color(0xFF6A2730)
                        : const Color(0xFF755414),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      offline
                          ? 'Sin conexión a internet'
                          : 'Conexión inestable',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
