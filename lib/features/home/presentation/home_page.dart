import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../matches/presentation/providers/matches_provider.dart';
import '../../predictions/presentation/providers/prediction_provider.dart';
import '../../ranking/presentation/providers/ranking_provider.dart';
import '../../../core/utils/gamification_utils.dart';


class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static bool _isMobile(double width) => width < 600;

  static bool _isTablet(double width) => width >= 600 && width < 1024;

  static bool _isDesktop(double width) => width >= 1024;

  static int _gridColumns(double width) {
    if (_isDesktop(width)) return 4;
    if (_isTablet(width)) return 3;
    return 2;
  }

  static double _gridAspectRatio(double width) {
    if (_isDesktop(width)) return 1.6;
    if (_isTablet(width)) return 1.35;
    return 1.15;
  }

  static double _pagePadding(double width) {
    if (_isDesktop(width)) return 32;
    if (_isTablet(width)) return 24;
    return 16;
  }

  static double _maxContentWidth(double width) {
    if (_isDesktop(width)) return 1180;
    if (_isTablet(width)) return 860;
    return double.infinity;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final matchesAsync = ref.watch(upcomingMatchesProvider);
    final predictionsAsync = ref.watch(myPredictionsProvider);
    final rankingAsync = ref.watch(rankingProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'GarraDigital',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.cream,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Pasaporte Crema',
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => context.push('/passport'),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    title: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: AppTheme.cream),
                    ),
                    content: const Text(
                      '¿Estás seguro que deseas cerrar sesión?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text(
                          'Cerrar sesión',
                          style: TextStyle(color: AppTheme.gold),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (confirm != true) return;

              final authService = ref.read(authServiceProvider);
              await authService.logout();
              ref.invalidate(currentUserProvider);
              ref.invalidate(upcomingMatchesProvider);
              ref.invalidate(myPredictionsProvider);
              ref.invalidate(rankingProvider);
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final padding = _pagePadding(width);
            final isMobile = _isMobile(width);

            return RefreshIndicator(
              color: AppTheme.gold,
              backgroundColor: const Color(0xFF1A1A1A),
              onRefresh: () async {
                ref.invalidate(currentUserProvider);
                ref.invalidate(upcomingMatchesProvider);
                ref.invalidate(myPredictionsProvider);
                ref.invalidate(rankingProvider);

                await Future.wait([
                  ref.read(currentUserProvider.future),
                  ref.read(upcomingMatchesProvider.future),
                  ref.read(myPredictionsProvider.future),
                  ref.read(rankingProvider.future),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(padding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _maxContentWidth(width),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderSection(
                          userAsync: userAsync,
                          isMobile: isMobile,
                          isDesktop: _isDesktop(width),
                        ),
                        const SizedBox(height: 12),
                        _HomeLevelProgressCard(
                          rankingAsync: rankingAsync,
                          isMobile: isMobile,
                        ),
                        SizedBox(height: isMobile ? 18 : 24),
                        _NextMatchSection(
                          matchesAsync: matchesAsync,
                          predictionsAsync: predictionsAsync,
                          isMobile: isMobile,
                        ),
                        SizedBox(height: isMobile ? 22 : 30),
                        Text(
                          'Accesos rápidos',
                          style: TextStyle(
                            color: AppTheme.cream,
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: _gridColumns(width),
                          mainAxisSpacing: isMobile ? 12 : 16,
                          crossAxisSpacing: isMobile ? 12 : 16,
                          childAspectRatio: _gridAspectRatio(width),
                          children: [
                            _QuickAccessCard(
                              title: 'La Polla',
                              subtitle: 'Pronostica partidos',
                              icon: Icons.fact_check_rounded,
                              onTap: () => context.push('/polla'),
                            ),
                            _RankingAccessCard(
                              rankingAsync: rankingAsync,
                              onTap: () => context.go('/ranking'),
                            ),
                            _QuickAccessCard(
                              title: 'Ruta al Templo',
                              subtitle: 'Puntos crema',
                              icon: Icons.map_rounded,
                              onTap: () => context.push('/ruta-templo'),
                            ),
                            _QuickAccessCard(
                              title: 'Muro Crema',
                              subtitle: 'Alienta con la hinchada',
                              icon: Icons.forum_rounded,
                              onTap: () => context.push('/muro-crema'),
                            ),
                            _QuickAccessCard(
                              title: 'Historial',
                              subtitle: 'Tus puntos crema',
                              icon: Icons.history_rounded,
                              onTap: () => context.push('/historial-crema'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.userAsync,
    required this.isMobile,
    required this.isDesktop,
  });

  final AsyncValue<dynamic> userAsync;
  final bool isMobile;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return userAsync.when(
      loading: () => const _HeaderSkeleton(),
      error: (_, __) => _HeaderContent(
        fullName: 'crema',
        isMobile: isMobile,
        isDesktop: isDesktop,
      ),
      data: (user) => _HeaderContent(
        fullName: user?.username ?? 'crema',
        isMobile: isMobile,
        isDesktop: isDesktop,
      ),
    );
  }
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({
    required this.fullName,
    required this.isMobile,
    required this.isDesktop,
  });

  final String fullName;
  final bool isMobile;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final titleSize = isDesktop ? 34.0 : (isMobile ? 24.0 : 30.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/passport'),
        borderRadius: BorderRadius.circular(24),
        child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF23090D),
          ],
        ),
        border: Border.all(
          color: AppTheme.cream.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 48 : 58,
            height: isMobile ? 48 : 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cream,
            ),
            child: Center(
              child: Text(
                'GD',
                style: TextStyle(
                  color: AppTheme.burgundy,
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 14 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $fullName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: isMobile ? 13 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Bienvenido a tu tribuna digital',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.cream,
                    fontSize: titleSize,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.cream.withOpacity(0.08),
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppTheme.gold),
      ),
    );
  }
}

class _NextMatchSection extends StatelessWidget {
  const _NextMatchSection({
    required this.matchesAsync,
    required this.predictionsAsync,
    required this.isMobile,
  });

  final AsyncValue<dynamic> matchesAsync;
  final AsyncValue<dynamic> predictionsAsync;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return matchesAsync.when(
      loading: () => const _CompactLoadingCard(),
      error: (_, __) => const _CompactMessageCard(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar el partido',
        subtitle: 'Desliza hacia abajo para reintentar.',
      ),
      data: (matches) {
        if (matches.isEmpty) {
          return const _CompactMessageCard(
            icon: Icons.sports_soccer_rounded,
            title: 'No hay próximos partidos',
            subtitle: 'Cuando exista uno, aparecerá aquí.',
          );
        }

        final match = matches.first;

        return predictionsAsync.when(
          loading: () => _NextMatchCard(
            isMobile: isMobile,
            homeTeam: match.homeTeam,
            awayTeam: match.awayTeam,
            matchDateTime: match.matchDateTime,
            stadium: match.stadium,
            predictionText: null,
          ),
          error: (_, __) => _NextMatchCard(
            isMobile: isMobile,
            homeTeam: match.homeTeam,
            awayTeam: match.awayTeam,
            matchDateTime: match.matchDateTime,
            stadium: match.stadium,
            predictionText: null,
          ),
          data: (predictions) {
            String? predictionText;

            for (final prediction in predictions) {
              if (prediction.matchId == match.id) {
                predictionText =
                '⚽ ${prediction.homeScore} - ${prediction.awayScore}';
                break;
              }
            }

            return _NextMatchCard(
              isMobile: isMobile,
              homeTeam: match.homeTeam,
              awayTeam: match.awayTeam,
              matchDateTime: match.matchDateTime,
              stadium: match.stadium,
              predictionText: predictionText,
            );
          },
        );
      },
    );
  }
}

class _NextMatchCard extends StatelessWidget {
  const _NextMatchCard({
    required this.isMobile,
    required this.homeTeam,
    required this.awayTeam,
    required this.matchDateTime,
    required this.stadium,
    required this.predictionText,
  });

  final bool isMobile;
  final String homeTeam;
  final String awayTeam;
  final String matchDateTime;
  final String stadium;
  final String? predictionText;

  @override
  Widget build(BuildContext context) {
    final formattedDate = _safeFormatDateTime(matchDateTime);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.burgundy,
            Color(0xFF2A0B0F),
          ],
        ),
        border: Border.all(
          color: AppTheme.gold.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.burgundy.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _SmallBadge(
                icon: Icons.sports_soccer_rounded,
                label: 'Próximo partido',
                color: AppTheme.gold,
              ),
              if (predictionText != null)
                _SmallBadge(
                  icon: Icons.check_circle_rounded,
                  label: predictionText!,
                  color: Colors.greenAccent,
                ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            '$homeTeam vs $awayTeam',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.cream,
              fontSize: isMobile ? 18 : 22,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          _CompactInfoRow(
            icon: Icons.calendar_month_rounded,
            text: formattedDate,
          ),
          const SizedBox(height: 7),
          _CompactInfoRow(
            icon: Icons.stadium_rounded,
            text: stadium,
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.cream.withOpacity(0.08),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 125;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 38 : 44,
                    height: compact ? 38 : 44,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      icon,
                      color: AppTheme.gold,
                      size: compact ? 21 : 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.cream,
                      fontSize: compact ? 14 : 16,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.52),
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RankingAccessCard extends StatelessWidget {
  const _RankingAccessCard({
    required this.rankingAsync,
    required this.onTap,
  });

  final AsyncValue<dynamic> rankingAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.cream.withOpacity(0.08),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 125;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 38 : 44,
                    height: compact ? 38 : 44,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: AppTheme.gold,
                      size: compact ? 21 : 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Ranking',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.cream,
                      fontSize: compact ? 14 : 16,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Top hinchas crema',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.52),
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  rankingAsync.when(
                    loading: () => const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.gold,
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (ranking) {
                      if (ranking.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final leader = ranking.first;

                      if (compact) {
                        return const SizedBox.shrink();
                      }

                      return _MiniLeaderChip(
                        text: '#1 ${leader.username}',
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiniLeaderChip extends StatelessWidget {
  const _MiniLeaderChip({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.burgundy.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.gold.withOpacity(0.18),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.gold,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactInfoRow extends StatelessWidget {
  const _CompactInfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppTheme.gold,
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactLoadingCard extends StatelessWidget {
  const _CompactLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 138,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.cream.withOpacity(0.08),
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppTheme.gold),
      ),
    );
  }
}

class _CompactMessageCard extends StatelessWidget {
  const _CompactMessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.cream.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.gold,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _HomeLevelProgressCard extends StatelessWidget {
  const _HomeLevelProgressCard({
    required this.rankingAsync,
    required this.isMobile,
  });

  final AsyncValue<dynamic> rankingAsync;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final points = rankingAsync.maybeWhen(
      data: (ranking) {
        if (ranking.isEmpty) return 0;

        try {
          return ranking.first.loyaltyPoints as int;
        } catch (_) {
          return 0;
        }
      },
      orElse: () => 0,
    );

    final level = GamificationUtils.levelForPoints(points);
    final progress = GamificationUtils.progressToNextLevel(points);
    final message = GamificationUtils.progressMessage(points);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.gold.withOpacity(0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 42 : 48,
            height: isMobile ? 42 : 48,
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              level.icon,
              color: AppTheme.gold,
              size: isMobile ? 22 : 25,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.cream,
                    fontSize: isMobile ? 15 : 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$points puntos crema',
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.62),
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
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

String _safeFormatDateTime(String isoDate) {
  try {
    return formatDateTime(isoDate);
  } catch (_) {
    return isoDate;
  }
}