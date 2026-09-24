import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config_service.dart';
import '../design/garra_colors.dart';
import '../design/garra_spacing.dart';
import 'garra_ui.dart';

class MaintenanceGatePage extends StatelessWidget {
  const MaintenanceGatePage({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(GarraSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Estamos preparando la tribuna',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(GarraColors.gold),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: GarraSpacing.md),
              Text(
                message.isEmpty
                    ? 'Vuelve en unos minutos. Tu sesión se mantiene.'
                    : message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(GarraColors.creamMuted),
                ),
              ),
              const Spacer(),
              GarraPrimaryButton(label: 'Reintentar', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({super.key, required this.config});

  final AppConfigModel config;

  @override
  Widget build(BuildContext context) {
    final store = config.storeUrl;
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(GarraSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Actualización requerida',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(GarraColors.gold),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: GarraSpacing.md),
              Text(
                'Esta versión de Garra ya no es compatible. '
                'Actualiza para continuar (mínimo ${config.minimumSupportedVersion}).',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(GarraColors.creamMuted),
                ),
              ),
              const Spacer(),
              if (store != null && store.isNotEmpty)
                GarraPrimaryButton(
                  label: 'Actualizar',
                  onPressed: () => launchUrl(
                    Uri.parse(store),
                    mode: LaunchMode.externalApplication,
                  ),
                )
              else
                GarraSecondaryButton(
                  label: 'Entendido (staging)',
                  onPressed: () {},
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureDisabledPage extends StatelessWidget {
  const FeatureDisabledPage({super.key, this.featureName});

  final String? featureName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Garra')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(GarraSpacing.xl),
          child: Text(
            'Esta función está temporalmente no disponible.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(GarraColors.cream),
            ),
          ),
        ),
      ),
    );
  }
}

class OptionalUpdateBanner extends StatelessWidget {
  const OptionalUpdateBanner({
    super.key,
    required this.latestVersion,
    required this.onDismiss,
    this.storeUrl,
  });

  final String latestVersion;
  final VoidCallback onDismiss;
  final String? storeUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A1518),
      elevation: 5,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.only(left: GarraSpacing.md, right: 4),
          child: Row(
            children: [
              const Icon(
                Icons.system_update_alt_rounded,
                size: 16,
                color: Color(GarraColors.gold),
              ),
              const SizedBox(width: GarraSpacing.sm),
              Expanded(
                child: Text(
                  'Nueva versión $latestVersion',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(GarraColors.cream),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (storeUrl != null && storeUrl!.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => launchUrl(
                    Uri.parse(storeUrl!),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Actualizar'),
                ),
              Semantics(
                button: true,
                label: 'Cerrar',
                child: IconButton(
                  onPressed: onDismiss,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
