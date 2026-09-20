import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_motion.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/passport_models.dart';
import 'providers/passport_provider.dart';

class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passportAsync = ref.watch(myPassportProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Pasaporte Crema'),
        actions: [
          if (passportAsync.asData?.value.viewerIsOwner == true)
            TextButton(
              onPressed: () => context.push('/passport/edit'),
              child: const Text('Editar'),
            ),
        ],
      ),
      body: passportAsync.when(
        loading: () => const GarraPassportSkeleton(),
        error: (error, stackTrace) => GarraErrorState(
          onRetry: () => ref.invalidate(myPassportProvider),
        ),
        data: (PassportModel passport) => _PassportBody(passport: passport),
      ),
    );
  }
}

class _PassportBody extends StatelessWidget {
  const _PassportBody({required this.passport});

  final PassportModel passport;

  @override
  Widget build(BuildContext context) {
    final identity = passport.identity;
    final level = passport.level;
    final stats = passport.stats;
    final numberFormat = NumberFormat.decimalPattern('es');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.md,
        GarraSpacing.lg,
        GarraSpacing.section,
      ),
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: GarraMotion.normal,
          curve: GarraMotion.entrance,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Column(
            children: [
              GarraAvatar(
                displayName: identity.displayName,
                avatarUrl: identity.avatarUrl,
                size: 96,
              ),
              const SizedBox(height: GarraSpacing.lg),
              Text(
                identity.displayName,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: GarraSpacing.xs),
              Text(
                '@${identity.username}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_locationLine(identity) != null) ...[
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  _locationLine(identity)!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
              if (identity.supporterSinceYear != null) ...[
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  'Crema desde ${identity.supporterSinceYear}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(GarraColors.gold),
                      ),
                ),
              ],
              if (identity.bio != null && identity.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: GarraSpacing.md),
                Text(
                  identity.bio!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: GarraSpacing.xxl),
        GarraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GarraLevelBadge(
                levelNumber: level.number,
                levelName: level.name,
              ),
              const SizedBox(height: GarraSpacing.lg),
              Text(
                '${numberFormat.format(level.points)} Puntos Garra',
                style: GarraTypography.numeric(size: 28),
              ),
              const SizedBox(height: GarraSpacing.md),
              GarraProgressBar(progress: level.progressFraction),
              const SizedBox(height: GarraSpacing.sm),
              Text(
                level.nextLevelPoints == null
                    ? 'Nivel máximo alcanzado'
                    : '${numberFormat.format(level.pointsToNextLevel)} pts para el siguiente nivel',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (passport.globalRank != null) ...[
                const SizedBox(height: GarraSpacing.md),
                Text(
                  'Ranking global #${passport.globalRank}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(GarraColors.gold),
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: GarraSpacing.lg),
        GarraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GarraSectionHeader(title: 'Tu actividad'),
              const SizedBox(height: GarraSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: GarraStat(
                      label: 'Check-ins',
                      value: numberFormat.format(stats.checkIns),
                    ),
                  ),
                  Expanded(
                    child: GarraStat(
                      label: 'Predicciones',
                      value: numberFormat.format(stats.predictions),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GarraSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: GarraStat(
                      label: 'Puntos Polla',
                      value: numberFormat.format(stats.predictionPoints),
                    ),
                  ),
                  Expanded(
                    child: GarraStat(
                      label: 'Publicaciones',
                      value: numberFormat.format(stats.posts),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GarraSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: GarraStat(
                      label: 'Racha Garra',
                      value: numberFormat.format(stats.streakCurrent),
                    ),
                  ),
                  Expanded(
                    child: GarraStat(
                      label: 'Mejor racha',
                      value: numberFormat.format(stats.streakBest),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GarraSpacing.sm),
              Text(
                'Participación en fechas',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(GarraColors.textSecondary),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: GarraSpacing.lg),
        GarraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GarraSectionHeader(
                title: 'Perfil',
                subtitle: 'Completa tu identidad crema cuando quieras.',
              ),
              const SizedBox(height: GarraSpacing.md),
              _ProfileRow(
                label: 'Ciudad',
                value: identity.city?.trim().isNotEmpty == true
                    ? identity.city!
                    : 'Sin configurar',
                muted: identity.city == null || identity.city!.trim().isEmpty,
              ),
              _ProfileRow(
                label: 'País',
                value: identity.countryCode ?? 'Sin configurar',
                muted: identity.countryCode == null,
              ),
              _ProfileRow(
                label: 'Visibilidad',
                value: _visibilityLabel(passport.profileVisibility),
              ),
              if (passport.viewerIsOwner) ...[
                const SizedBox(height: GarraSpacing.lg),
                GarraSecondaryButton(
                  label: 'Editar perfil',
                  onPressed: () => context.push('/passport/edit'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String? _locationLine(PassportIdentity identity) {
    final city = identity.city?.trim();
    final country = identity.countryCode?.trim();
    if ((city == null || city.isEmpty) && (country == null || country.isEmpty)) {
      return null;
    }
    if (city != null && city.isNotEmpty && country != null && country.isNotEmpty) {
      return '$city · $country';
    }
    return city ?? country;
  }

  static String _visibilityLabel(String visibility) {
    switch (visibility) {
      case 'PRIVATE':
        return 'Privado';
      case 'MEMBERS_ONLY':
        return 'Solo miembros';
      default:
        return 'Público';
    }
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GarraSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: muted
                      ? const Color(GarraColors.textSecondary)
                      : const Color(GarraColors.textPrimary),
                ),
          ),
        ],
      ),
    );
  }
}
