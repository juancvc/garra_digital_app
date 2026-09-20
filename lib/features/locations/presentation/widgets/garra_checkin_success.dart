import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/checkin_model.dart';

/// Success panel after a valid check-in (check-in 2.0).
class GarraCheckInSuccess extends StatelessWidget {
  const GarraCheckInSuccess({
    super.key,
    required this.checkIn,
    this.onDismiss,
  });

  final CheckInModel checkIn;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final points = checkIn.displayPoints;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHECK-IN COMPLETADO',
          style: TextStyle(
            color: AppTheme.cream,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          checkIn.cremaPointName,
          style: const TextStyle(
            color: AppTheme.gold,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '+$points Puntos Garra',
          style: const TextStyle(
            color: AppTheme.cream,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        if (checkIn.matchLinked) ...[
          const SizedBox(height: 10),
          const Text(
            'Cuenta para la fecha de hoy',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (onDismiss != null) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onDismiss,
              child: const Text('Listo'),
            ),
          ),
        ],
      ],
    );
  }
}
