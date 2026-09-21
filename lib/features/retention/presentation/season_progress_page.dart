import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/retention_models.dart';
import '../data/retention_service.dart';

class SeasonProgressPage extends StatefulWidget {
  const SeasonProgressPage({super.key});

  @override
  State<SeasonProgressPage> createState() => _SeasonProgressPageState();
}

class _SeasonProgressPageState extends State<SeasonProgressPage> {
  final _service = RetentionService();
  SeasonProgressModel? _progress;
  SeasonRecapModel? _recap;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final progress = await _service.mySeasonProgress();
      SeasonRecapModel? recap;
      if (progress != null) {
        try {
          recap = await _service.seasonRecap(progress.seasonId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _recap = recap;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tu temporada';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Mi Temporada')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? GarraErrorState(onRetry: _load)
              : _progress == null
                  ? const GarraEmptyState(
                      title: 'Sin temporada activa',
                      message: 'Cuando Garra abra una temporada, tu progreso aparecerá aquí.',
                    )
                  : ListView(
                      padding: const EdgeInsets.all(GarraSpacing.lg),
                      children: [
                        _SeasonHero(progress: _progress!),
                        const SizedBox(height: GarraSpacing.lg),
                        Text('Progreso completo',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: GarraSpacing.md),
                        _MetricGrid(progress: _progress!),
                        if (_recap != null) ...[
                          const SizedBox(height: GarraSpacing.xl),
                          GarraCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Recap',
                                    style:
                                        Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(_recap!.highlight),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    Share.share(
                                      'Mi Temporada ${_recap!.seasonName} en Garra Digital: ${_recap!.highlight}',
                                    );
                                  },
                                  icon: const Icon(Icons.ios_share),
                                  label: const Text('Compartir recap'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
    );
  }
}

class SeasonHeroCard extends StatelessWidget {
  const SeasonHeroCard({
    super.key,
    required this.progress,
    this.levelLabel,
    this.onOpen,
  });

  final SeasonProgressModel progress;
  final String? levelLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return GarraCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mi Temporada', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            progress.seasonName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(GarraColors.cream),
                ),
          ),
          if (levelLabel != null) ...[
            const SizedBox(height: 4),
            Text(levelLabel!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(GarraColors.gold),
                    )),
          ],
          const SizedBox(height: GarraSpacing.md),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _MiniStat(label: 'Puntos', value: '${progress.pointsEarned}'),
              _MiniStat(label: 'Logros', value: '${progress.achievementsUnlocked}'),
              _MiniStat(label: 'Racha', value: '${progress.streakBest}'),
              _MiniStat(label: 'Check-ins', value: '${progress.checkIns}'),
              _MiniStat(label: 'Posts', value: '${progress.globalPosts}'),
              _MiniStat(
                  label: 'Matchday', value: '${progress.matchdayParticipations}'),
            ],
          ),
          const SizedBox(height: GarraSpacing.md),
          Text(
            'Ver progreso completo',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(GarraColors.gold),
                ),
          ),
        ],
      ),
    );
  }
}

class _SeasonHero extends StatelessWidget {
  const _SeasonHero({required this.progress});
  final SeasonProgressModel progress;

  @override
  Widget build(BuildContext context) => SeasonHeroCard(progress: progress);
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.progress});
  final SeasonProgressModel progress;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('es');
    final rows = [
      ('Puntos Garra', fmt.format(progress.pointsEarned)),
      ('Misiones', fmt.format(progress.missionsCompleted)),
      ('Check-ins', fmt.format(progress.checkIns)),
      ('Publicaciones', fmt.format(progress.globalPosts)),
      ('Comentarios', fmt.format(progress.comments)),
      ('Comunidades', fmt.format(progress.communitiesJoined)),
      ('Negocios', fmt.format(progress.businessesFollowed)),
      ('Solidaria', fmt.format(progress.solidarityParticipations)),
      ('Matchday', fmt.format(progress.matchdayParticipations)),
      ('Mejor racha', fmt.format(progress.streakBest)),
      ('Referidos', fmt.format(progress.referralsCompleted)),
      ('Logros', fmt.format(progress.achievementsUnlocked)),
      ('Event check-ins', fmt.format(progress.eventCheckins)),
    ];
    return Column(
      children: rows
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GarraCard(
                child: Row(
                  children: [
                    Expanded(child: Text(r.$1)),
                    Text(r.$2,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: const Color(GarraColors.gold),
                            )),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(GarraColors.gold),
                  )),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Navigate helper used by daily card destinations.
void openRetentionDestination(BuildContext context, String destination) {
  switch (destination) {
    case '/logros':
      context.push('/logros');
    case '/missions':
      context.push('/missions');
    case '/eventos':
      context.push('/eventos');
    case '/passport/temporada':
      context.push('/passport/temporada');
    case '/solidaria':
      context.push('/solidaria');
    case '/comunidad':
      context.push('/comunidad');
    default:
      if (destination.startsWith('/')) {
        context.push(destination);
      }
  }
}
