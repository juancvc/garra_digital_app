import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/crema_point_model.dart';

/// Selected crema point sheet for check-in (testable surface).
class GarraCheckInPointCard extends StatelessWidget {
  const GarraCheckInPointCard({
    super.key,
    required this.point,
    this.distanceMeters,
    this.matchContext = false,
    this.checkingIn = false,
    this.onCheckIn,
  });

  final CremaPointModel point;
  final double? distanceMeters;
  final bool matchContext;
  final bool checkingIn;
  final VoidCallback? onCheckIn;

  bool get isInRange {
    final distance = distanceMeters;
    return distance != null && distance <= point.checkinRadiusMeters;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              point.name,
              style: const TextStyle(
                color: AppTheme.cream,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              distanceMeters == null
                  ? 'Ubicación no disponible'
                  : 'Estás a ${distanceMeters!.round()} m',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Radio de check-in: ${point.checkinRadiusMeters} m',
              style: const TextStyle(color: Colors.white70),
            ),
            if (matchContext) ...[
              const SizedBox(height: 6),
              const Text(
                'Check-in de fecha activa',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: isInRange && !checkingIn ? onCheckIn : null,
              child: Text(isInRange ? 'Check-in' : 'Fuera de rango'),
            ),
          ],
        ),
      ),
    );
  }
}
