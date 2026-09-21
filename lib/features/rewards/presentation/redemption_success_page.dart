import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/reward_models.dart';

/// Success screen after redeeming. QR payload is only the redemption code.
class RedemptionSuccessPage extends StatelessWidget {
  const RedemptionSuccessPage({super.key, required this.redemption});

  final RewardRedemption redemption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Canje realizado')),
      body: ListView(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: [
          Text(
            redemption.rewardTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: GarraSpacing.sm),
          Text(
            redemption.providerLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(GarraColors.gold),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: GarraSpacing.xl),
          GarraCard(
            child: Column(
              children: [
                QrImageView(
                  data: redemption.redemptionCode,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: GarraSpacing.lg),
                Text(
                  redemption.redemptionCode,
                  style: GarraTypography.numeric(size: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  '${redemption.pointsSpent} Puntos Garra · ${redemption.statusLabelEs}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: GarraSpacing.xl),
          GarraPrimaryButton(
            label: 'Listo',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
