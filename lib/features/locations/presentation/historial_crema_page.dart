import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/gamification_utils.dart';
import '../data/checkin_model.dart';
import 'providers/location_provider.dart';

class HistorialCremaPage extends ConsumerWidget {
  const HistorialCremaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkInsAsync = ref.watch(myCheckInsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Historial Crema',
          style: TextStyle(
            color: AppTheme.cream,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: checkInsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.gold),
          ),
          error: (error, _) => _ErrorState(detail: error.toString()),
          data: (checkIns) {
            final totalPoints = checkIns
                .where((e) => e.status == 'VALID')
                .fold<int>(0, (sum, e) => sum + e.pointsEarned);

            return RefreshIndicator(
              color: AppTheme.gold,
              backgroundColor: const Color(0xFF1A1A1A),
              onRefresh: () async {
                ref.invalidate(myCheckInsProvider);
                await ref.read(myCheckInsProvider.future);
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 130),
                itemCount: checkIns.length + 2,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _SummaryCard(
                      totalPoints: totalPoints,
                      totalCheckIns: checkIns.length,
                      validCheckIns: checkIns.where((e) => e.status == 'VALID').length,
                    );
                  }

                  if (index == 1) {
                    return _HistoryLevelProgressCard(points: totalPoints);
                  }

                  final checkIn = checkIns[index - 2];
                  return _CheckInHistoryCard(checkIn: checkIn);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalPoints,
    required this.totalCheckIns,
    required this.validCheckIns,
  });

  final int totalPoints;
  final int totalCheckIns;
  final int validCheckIns;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [
            AppTheme.burgundy,
            Color(0xFF2A0B0F),
          ],
        ),
        border: Border.all(color: AppTheme.cream.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history_rounded, color: AppTheme.gold, size: 32),
          const SizedBox(height: 14),
          const Text(
            'Puntos por check-ins',
            style: TextStyle(
              color: AppTheme.cream,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$totalPoints pts',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$validCheckIns check-ins válidos de $totalCheckIns intentos',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInHistoryCard extends StatelessWidget {
  const _CheckInHistoryCard({required this.checkIn});

  final CheckInModel checkIn;

  @override
  Widget build(BuildContext context) {
    final isValid = checkIn.status == 'VALID';
    final color = isValid ? Colors.greenAccent : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(
                  isValid
                      ? Icons.check_circle_rounded
                      : Icons.warning_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  checkIn.cremaPointName,
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '+${checkIn.pointsEarned} pts',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            checkIn.cremaPointAddress ?? 'Dirección no registrada',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Distancia: ${formatDistance(checkIn.distanceMeters)}',
            style: TextStyle(color: Colors.white.withOpacity(0.58)),
          ),
          const SizedBox(height: 6),
          Text(
            'Estado: ${isValid ? 'Válido' : 'Rechazado'}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            formatDateTime(checkIn.createdAt),
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

String formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.toStringAsFixed(0)} m';
}

class _HistoryLevelProgressCard extends StatelessWidget {
  const _HistoryLevelProgressCard({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final level = GamificationUtils.levelForPoints(points);
    final progress = GamificationUtils.progressToNextLevel(points);
    final message = GamificationUtils.progressMessage(points);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.gold.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(level.icon, color: AppTheme.gold, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(level.name,
                    style: const TextStyle(
                      color: AppTheme.cream,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 6),
                Text(message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontSize: 12,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No se pudo cargar tu historial.\n$detail',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.cream),
        ),
      ),
    );
  }
}