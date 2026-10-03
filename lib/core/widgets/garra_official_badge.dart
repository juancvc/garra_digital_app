import 'package:flutter/material.dart';

import '../theme/garra_semantic_colors.dart';

/// Backend `accountType` value of the official platform account (Garra Digital).
const String kPlatformOfficialAccountType = 'PLATFORM_OFFICIAL';

/// The only source of truth for "is this the official account": the backend
/// `accountType` field. Never derive it from a name, username or email.
bool isPlatformOfficialAccount(String? accountType) =>
    accountType == kPlatformOfficialAccountType;

/// Sober "Garra Oficial" marker: small outlined pill with the theme's
/// prestige (cream/gold) accent. Works in Noche and Crema.
class GarraOfficialBadge extends StatelessWidget {
  const GarraOfficialBadge({super.key, this.compact = false});

  /// Icon-only variant for very tight rows (still exposes the semantic label).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final accent = colors.brandPrestige;
    return Semantics(
      label: 'Cuenta oficial de Garra Digital',
      child: Container(
        key: const ValueKey('garra_official_badge'),
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 1),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          border: Border.all(color: accent.withValues(alpha: 0.7), width: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 11, color: accent),
            if (!compact) ...[
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  'Garra Oficial',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
