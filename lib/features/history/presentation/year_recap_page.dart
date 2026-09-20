import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_motion.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/history_models.dart';
import '../widgets/garra_year_share_card.dart';
import 'providers/history_provider.dart';

class YearRecapPage extends ConsumerStatefulWidget {
  const YearRecapPage({super.key, required this.year});

  final int year;

  @override
  ConsumerState<YearRecapPage> createState() => _YearRecapPageState();
}

class _YearRecapPageState extends ConsumerState<YearRecapPage> {
  final GlobalKey _shareBoundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareRecap(FanYearShareDto share) async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final boundary = _shareBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('share_boundary_missing');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('share_encode_failed');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mi_ano_crema_${share.year}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Mi Año Crema ${share.year} — Garra Digital',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos compartir tu Año Crema. Inténtalo de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recapAsync = ref.watch(yearRecapProvider(widget.year));

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: Text('Mi Año Crema ${widget.year}'),
        actions: [
          recapAsync.maybeWhen(
            data: (recap) => IconButton(
              tooltip: 'Compartir',
              onPressed: _sharing ? null : () => _shareRecap(recap.share),
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: recapAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(GarraSpacing.lg),
          child: Column(
            children: [
              GarraSkeleton(height: 140),
              SizedBox(height: GarraSpacing.lg),
              GarraSkeleton(height: 100),
              SizedBox(height: GarraSpacing.lg),
              GarraSkeleton(height: 100),
            ],
          ),
        ),
        error: (error, stackTrace) => GarraErrorState(
          onRetry: () => ref.invalidate(yearRecapProvider(widget.year)),
        ),
        data: (recap) => _YearRecapBody(
          recap: recap,
          shareBoundaryKey: _shareBoundaryKey,
          sharing: _sharing,
          onShare: () => _shareRecap(recap.share),
        ),
      ),
    );
  }
}

class _YearRecapBody extends StatelessWidget {
  const _YearRecapBody({
    required this.recap,
    required this.shareBoundaryKey,
    required this.sharing,
    required this.onShare,
  });

  final YearRecapModel recap;
  final GlobalKey shareBoundaryKey;
  final bool sharing;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern();
    final empty = !recap.hasMeaningfulActivity;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.md,
        GarraSpacing.lg,
        GarraSpacing.section,
      ),
      children: [
        _Reveal(
          delayMs: 0,
          child: _HeroSection(recap: recap, empty: empty),
        ),
        if (empty) ...[
          const SizedBox(height: GarraSpacing.xxl),
          const GarraEmptyState(
            title: 'Tu historia recién comienza.',
            message:
                'Sigue viviendo fechas con la U. Tu Año Crema crecerá con vos.',
          ),
        ] else ...[
          const SizedBox(height: GarraSpacing.xxl),
          _Reveal(
            delayMs: 60,
            child: _MetricBlock(
              eyebrow: 'Puntos',
              title: 'Puntos ganados',
              value: number.format(recap.stats.pointsEarned),
              subtitle: 'Actividad real del ${recap.year}',
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          _Reveal(
            delayMs: 100,
            child: _MetricBlock(
              eyebrow: 'Fechas',
              title: 'Fechas participadas',
              value: number.format(recap.matchday.participated),
              subtitle: recap.matchday.checkIns > 0
                  ? '${number.format(recap.matchday.checkIns)} check-ins'
                      '${recap.matchday.stadiumCheckIns > 0 ? ' · ${number.format(recap.matchday.stadiumCheckIns)} en estadio' : ''}'
                  : 'Matchdays con acción significativa',
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          _Reveal(
            delayMs: 140,
            child: _SectionCard(
              title: 'La Polla',
              child: Column(
                children: [
                  _StatRow(
                    label: 'Predicciones',
                    value: number.format(recap.prediction.submitted),
                  ),
                  _StatRow(
                    label: 'Marcadores exactos',
                    value: number.format(recap.prediction.exactScores),
                  ),
                  _StatRow(
                    label: 'Puntos Polla',
                    value: number.format(recap.prediction.points),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          _Reveal(
            delayMs: 180,
            child: _MetricBlock(
              eyebrow: 'Racha',
              title: 'Racha Garra',
              value: number.format(recap.streak.best),
              subtitle: 'Mejor racha del año',
              accentFlame: recap.streak.best > 0,
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          _Reveal(
            delayMs: 220,
            child: _SectionCard(
              title: 'Comunidad',
              child: Column(
                children: [
                  _StatRow(
                    label: 'Publicaciones',
                    value: number.format(recap.community.posts),
                  ),
                  _StatRow(
                    label: 'Comentarios',
                    value: number.format(recap.community.comments),
                  ),
                  _StatRow(
                    label: 'Reacciones',
                    value: number.format(recap.community.reactions),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          _Reveal(
            delayMs: 260,
            child: _MetricBlock(
              eyebrow: 'Misiones',
              title: 'Misiones completadas',
              value: number.format(recap.stats.missionsCompleted),
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          _Reveal(
            delayMs: 300,
            child: _SectionCard(
              title: 'Clan',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recap.clan.hasClan)
                    Text(
                      recap.clan.name!,
                      style: Theme.of(context).textTheme.titleMedium,
                    )
                  else
                    Text(
                      'Sin clan principal este año',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: GarraSpacing.md),
                  _StatRow(
                    label: 'Puntos aportados a Polla de clan',
                    value: number.format(recap.clan.pollaPoints),
                  ),
                ],
              ),
            ),
          ),
          if (recap.highlights.isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.lg),
            _Reveal(
              delayMs: 320,
              child: _SectionCard(
                title: 'Momentos',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: recap.highlights
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: GarraSpacing.sm,
                          ),
                          child: Text(
                            h.text,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: GarraSpacing.xxl),
        _Reveal(
          delayMs: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tu tarjeta',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: GarraSpacing.md),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: RepaintBoundary(
                    key: shareBoundaryKey,
                    child: GarraYearShareCard(share: recap.share),
                  ),
                ),
              ),
              const SizedBox(height: GarraSpacing.lg),
              FilledButton.icon(
                onPressed: sharing ? null : onShare,
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(sharing ? 'Preparando…' : 'Compartir Año Crema'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.recap, required this.empty});

  final YearRecapModel recap;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GarraSpacing.xxl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(GarraColors.garnetDeep),
            Color(GarraColors.charcoal),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(GarraColors.gold).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            empty
                ? 'Tu historia recién comienza.'
                : (recap.headline.title.isNotEmpty
                    ? recap.headline.title
                    : 'Este fue tu ${recap.year} crema'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (!empty &&
              recap.headline.subtitle != null &&
              recap.headline.subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(
              recap.headline.subtitle!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: GarraSpacing.md),
          Text(
            recap.identity.displayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(GarraColors.gold),
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.eyebrow,
    required this.title,
    required this.value,
    this.subtitle,
    this.accentFlame = false,
  });

  final String eyebrow;
  final String title;
  final String value;
  final String? subtitle;
  final bool accentFlame;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(GarraColors.gold),
                      letterSpacing: 1.1,
                    ),
              ),
              if (accentFlame) ...[
                const SizedBox(width: GarraSpacing.sm),
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(GarraColors.warning),
                  size: 18,
                ),
              ],
            ],
          ),
          const SizedBox(height: GarraSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: GarraSpacing.md),
          Text(value, style: GarraTypography.numeric(size: 44)),
          if (subtitle != null) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: GarraSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: GarraTypography.numeric(size: 22)),
        ],
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: GarraMotion.normal + Duration(milliseconds: delayMs),
      curve: GarraMotion.entrance,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
