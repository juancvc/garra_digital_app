import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/status_utils.dart';
import '../../matches/data/match_model.dart';
import '../../matches/presentation/providers/matches_provider.dart';
import '../../ranking/presentation/providers/ranking_provider.dart';
import '../data/create_prediction_request.dart';
import '../data/prediction_model.dart';
import 'providers/prediction_provider.dart';

class PollaPage extends ConsumerWidget {
  const PollaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(upcomingMatchesProvider);
    final predictionsAsync = ref.watch(myPredictionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'La Polla',
          style: TextStyle(
            color: AppTheme.cream,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isMobile = width < 600;
            final horizontalPadding = isMobile ? 16.0 : (width < 1024 ? 20.0 : 24.0);

            return RefreshIndicator(
              color: AppTheme.gold,
              backgroundColor: const Color(0xFF1A1A1A),
              onRefresh: () async {
                ref.invalidate(upcomingMatchesProvider);
                ref.invalidate(myPredictionsProvider);
                ref.invalidate(rankingProvider);

                await Future.wait([
                  ref.read(upcomingMatchesProvider.future),
                  ref.read(myPredictionsProvider.future),
                ]);
              },
              child: matchesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.gold),
                ),
                error: (error, _) => _ErrorState(
                  message: 'No se pudieron cargar los partidos.',
                  detail: error.toString(),
                  horizontalPadding: horizontalPadding,
                ),
                data: (matches) {
                  return predictionsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    ),
                    error: (error, _) => _ErrorState(
                      message: 'No se pudieron cargar tus predicciones.',
                      detail: error.toString(),
                      horizontalPadding: horizontalPadding,
                    ),
                    data: (predictions) {
                      if (matches.isEmpty) {
                        return _EmptyState(horizontalPadding: horizontalPadding);
                      }

                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          0,
                        ),
                        itemCount: matches.length + 2,
                        separatorBuilder: (_, __) => SizedBox(
                          height: isMobile ? 12 : 16,
                        ),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _Header(isMobile: isMobile);
                          }

                          if (index == matches.length + 1) {
                            return const SizedBox(height: 130);
                          }

                          final match = matches[index - 1];
                          final prediction = _findPredictionForMatch(
                            predictions,
                            match.id,
                          );

                          return _MatchPredictionCard(
                            match: match,
                            prediction: prediction,
                            isMobile: isMobile,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  PredictionModel? _findPredictionForMatch(
      List<PredictionModel> predictions,
      String matchId,
      ) {
    for (final prediction in predictions) {
      if (prediction.matchId == matchId) {
        return prediction;
      }
    }

    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isMobile,
  });

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.burgundy,
            Color(0xFF2A0B0F),
          ],
        ),
        border: Border.all(
          color: AppTheme.cream.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 42 : 48,
            height: isMobile ? 42 : 48,
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.fact_check_rounded,
              color: AppTheme.gold,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pronostica con garra',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.cream,
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Registra tu marcador y suma puntos.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: isMobile ? 12 : 14,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchPredictionCard extends StatelessWidget {
  const _MatchPredictionCard({
    required this.match,
    required this.prediction,
    required this.isMobile,
  });

  final MatchModel match;
  final PredictionModel? prediction;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final hasPrediction = prediction != null;
    final closeInfo = _closeInfo(match.predictionClosesAt);
    final isClosed = closeInfo.isClosed || match.status == 'CLOSED';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusBadge(status: translateMatchStatus(match.status)),
                if (isClosed)
                  const _StatusBadge(
                    status: 'Predicción cerrada',
                    color: Colors.orange,
                  ),
              ],
            ),
            SizedBox(height: isMobile ? 10 : 12),
            Text(
              '${match.homeTeam} vs ${match.awayTeam}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.cream,
                fontSize: isMobile ? 17 : 20,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: isMobile ? 12 : 14),
            _InfoRow(
              icon: Icons.calendar_month_rounded,
              label: 'Fecha',
              value: _safeFormatDateTime(match.matchDateTime),
              isMobile: isMobile,
            ),
            const SizedBox(height: 7),
            _InfoRow(
              icon: Icons.stadium_rounded,
              label: 'Estadio',
              value: match.stadium,
              isMobile: isMobile,
            ),
            const SizedBox(height: 7),
            _InfoRow(
              icon: Icons.lock_clock_rounded,
              label: 'Cierre',
              value: closeInfo.text,
              isMobile: isMobile,
            ),
            SizedBox(height: isMobile ? 12 : 16),
            if (hasPrediction)
              _RegisteredPrediction(
                prediction: prediction!,
                isMobile: isMobile,
              )
            else if (isClosed)
              const _ClosedPredictionBox()
            else
              _PredictionForm(
                matchId: match.id,
                isMobile: isMobile,
              ),
          ],
        ),
      ),
    );
  }

  _CloseInfo _closeInfo(String? predictionClosesAt) {
    if (predictionClosesAt == null || predictionClosesAt.isEmpty) {
      return const _CloseInfo(
        text: 'Por confirmar',
        isClosed: false,
      );
    }

    try {
      final closeDate = DateTime.parse(predictionClosesAt);
      final remaining = closeDate.difference(DateTime.now());

      if (remaining.isNegative) {
        return _CloseInfo(
          text: 'Cerró ${_safeFormatDateTime(predictionClosesAt)}',
          isClosed: true,
        );
      }

      return _CloseInfo(
        text: 'Cierra en ${remaining.inHours}h ${remaining.inMinutes % 60}m',
        isClosed: false,
      );
    } catch (_) {
      return _CloseInfo(
        text: predictionClosesAt,
        isClosed: false,
      );
    }
  }
}

class _CloseInfo {
  const _CloseInfo({
    required this.text,
    required this.isClosed,
  });

  final String text;
  final bool isClosed;
}

class _RegisteredPrediction extends StatelessWidget {
  const _RegisteredPrediction({
    required this.prediction,
    required this.isMobile,
  });

  final PredictionModel prediction;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.green.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 42 : 48,
            height: isMobile ? 42 : 48,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.greenAccent,
            ),
          ),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu predicción',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${prediction.predictedHomeScore} - ${prediction.predictedAwayScore}',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: isMobile ? 24 : 28,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MiniTextChip(
                  text: translatePredictionStatus(prediction.predictionStatus),
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 7),
                Text(
                  '${prediction.pointsEarned} pts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosedPredictionBox extends StatelessWidget {
  const _ClosedPredictionBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.orange.withOpacity(0.35),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.lock_clock_rounded,
            color: Colors.orange,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Predicción cerrada',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionForm extends ConsumerStatefulWidget {
  const _PredictionForm({
    required this.matchId,
    required this.isMobile,
  });

  final String matchId;
  final bool isMobile;

  @override
  ConsumerState<_PredictionForm> createState() => _PredictionFormState();
}

class _PredictionFormState extends ConsumerState<_PredictionForm> {
  final _homeScoreController = TextEditingController();
  final _awayScoreController = TextEditingController();
  final _firstScorerController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    _firstScorerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final homeText = _homeScoreController.text.trim();
    final awayText = _awayScoreController.text.trim();

    if (homeText.isEmpty || awayText.isEmpty) {
      _showSnackBar(
        message: 'Ingresa los goles de ambos equipos.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    final homeScore = int.tryParse(homeText);
    final awayScore = int.tryParse(awayText);

    if (homeScore == null || awayScore == null) {
      _showSnackBar(
        message: 'Ingresa goles numéricos válidos.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (homeScore < 0 || awayScore < 0) {
      _showSnackBar(
        message: 'Los goles no pueden ser negativos.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final service = ref.read(predictionServiceProvider);

      final result = await service.createPrediction(
        CreatePredictionRequest(
          matchId: widget.matchId,
          predictedHomeScore: homeScore,
          predictedAwayScore: awayScore,
          predictedFirstScorer: _firstScorerController.text.trim().isEmpty
              ? null
              : _firstScorerController.text.trim(),
        ),
      );

      if (!mounted) return;

      if (result.success) {
        _showSnackBar(
          message: result.message,
          backgroundColor: Colors.green,
        );

        ref.invalidate(myPredictionsProvider);
        ref.invalidate(rankingProvider);
      } else {
        _showSnackBar(
          message: _normalizePredictionError(result.message),
          backgroundColor: Colors.orange,
        );

        ref.invalidate(myPredictionsProvider);
      }
    } on DioException catch (e) {
      if (!mounted) return;

      final backendMessage = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;

      _showSnackBar(
        message: _normalizePredictionError(
          backendMessage ?? 'No se pudo registrar la predicción.',
        ),
        backgroundColor: Colors.orange,
      );
    } catch (_) {
      if (!mounted) return;

      _showSnackBar(
        message: 'Ocurrió un error inesperado.',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _normalizePredictionError(String message) {
    if (message.contains('User already has a prediction for this match')) {
      return 'Ya registraste una predicción para este partido';
    }

    return message;
  }

  void _showSnackBar({
    required String message,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.cream.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ScoreField(
                  controller: _homeScoreController,
                  label: 'Local',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScoreField(
                  controller: _awayScoreController,
                  label: 'Visita',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _firstScorerController,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Primer goleador opcional',
              prefixIcon: Icon(Icons.person_search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.burgundy,
              ),
            )
                : const Text('Registrar predicción'),
          ),
        ],
      ),
    );
  }
}

class _ScoreField extends StatelessWidget {
  const _ScoreField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        isDense: true,
        prefixIcon: const Icon(Icons.sports_soccer_rounded),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    this.color = AppTheme.gold,
  });

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.22),
        ),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniTextChip extends StatelessWidget {
  const _MiniTextChip({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.22),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isMobile,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppTheme.gold,
          size: isMobile ? 16 : 18,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                height: 1.25,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.52),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.horizontalPadding,
  });

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 96),
      children: [
        const SizedBox(height: 70),
        Icon(
          Icons.sports_soccer_rounded,
          color: AppTheme.gold.withOpacity(0.9),
          size: 54,
        ),
        const SizedBox(height: 18),
        const Text(
          'No hay partidos disponibles',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.cream,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Cuando existan partidos abiertos para predicción, aparecerán aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.62),
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.detail,
    required this.horizontalPadding,
  });

  final String message;
  final String detail;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 96),
      children: [
        const SizedBox(height: 70),
        Icon(
          Icons.error_outline_rounded,
          color: Colors.redAccent.withOpacity(0.9),
          size: 54,
        ),
        const SizedBox(height: 18),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.cream,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

String _safeFormatDateTime(String isoDate) {
  try {
    return formatDateTime(isoDate);
  } catch (_) {
    return isoDate;
  }
}