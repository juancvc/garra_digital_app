import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/gamification_utils.dart';
import 'providers/ranking_provider.dart';
import 'package:go_router/go_router.dart';

class RankingPage extends ConsumerWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(rankingProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Ranking',
          style: TextStyle(
            color: AppTheme.cream,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.gold,
          backgroundColor: const Color(0xFF1A1A1A),
          onRefresh: () async {
            ref.invalidate(rankingProvider);
            await ref.read(rankingProvider.future);
          },
          child: rankingAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.gold),
            ),
            error: (error, _) => _ErrorState(
              message: 'No se pudo cargar el ranking.',
              detail: error.toString(),
            ),
            data: (ranking) {
              if (ranking.isEmpty) {
                return const _EmptyState();
              }

              final topOne = ranking.isNotEmpty ? ranking[0] : null;
              final topTwo = ranking.length > 1 ? ranking[1] : null;
              final topThree = ranking.length > 2 ? ranking[2] : null;
              final rest = ranking.length > 3 ? ranking.sublist(3) : [];

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _Header(),
                  const SizedBox(height: 20),
                  if (topOne != null) _TopOneCard(item: topOne),
                  if (topTwo != null || topThree != null) ...[
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 700;

                        if (isWide) {
                          return Row(
                            children: [
                              if (topTwo != null)
                                Expanded(
                                  child: _TopSmallCard(item: topTwo),
                                ),
                              if (topTwo != null && topThree != null)
                                const SizedBox(width: 14),
                              if (topThree != null)
                                Expanded(
                                  child: _TopSmallCard(item: topThree),
                                ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            if (topTwo != null) _TopSmallCard(item: topTwo),
                            if (topTwo != null && topThree != null)
                              const SizedBox(height: 14),
                            if (topThree != null) _TopSmallCard(item: topThree),
                          ],
                        );
                      },
                    ),
                  ],
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text(
                      'Tabla general',
                      style: TextStyle(
                        color: AppTheme.cream,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...rest.map(
                          (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RankingListItem(item: item),
                      ),
                    ),
                  ],
                  const SizedBox(height: 130),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
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
          color: AppTheme.cream.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppTheme.gold,
            size: 34,
          ),
          const SizedBox(height: 14),
          const Text(
            'Ranking Crema',
            style: TextStyle(
              color: AppTheme.cream,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los hinchas con más puntos',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopOneCard extends StatelessWidget {
  const _TopOneCard({
    required this.item,
  });

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gold.withOpacity(0.98),
            const Color(0xFF8C641F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withOpacity(0.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PositionBadge(
            position: 1,
            color: AppTheme.burgundy,
            foregroundColor: AppTheme.cream,
            icon: Icons.emoji_events_rounded,
          ),
          const SizedBox(height: 6),
          Text(
            '@${item.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.background.withOpacity(0.72),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DarkChip(
                icon: Icons.stadium_rounded,
                label: item.favoriteStand,
              ),
              _DarkChip(
                icon: Icons.local_fire_department_rounded,
                label: '${item.loyaltyPoints} pts',
              ),
              _DarkChip(
                icon: GamificationUtils
                    .levelForPoints(item.loyaltyPoints)
                    .icon,
                label: GamificationUtils
                    .levelForPoints(item.loyaltyPoints)
                    .name,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopSmallCard extends StatelessWidget {
  const _TopSmallCard({
    required this.item,
  });

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final isSecond = item.position == 2;
    final color = isSecond ? Colors.grey.shade300 : const Color(0xFFCD7F32);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _PositionBadge(
              position: item.position,
              color: color,
              foregroundColor: AppTheme.background,
              icon: Icons.military_tech_rounded,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '@${item.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.favoriteStand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _LevelInlineBadge(points: item.loyaltyPoints),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _PointsPill(points: item.loyaltyPoints),
          ],
        ),
      ),
    );
  }
}

class _RankingListItem extends StatelessWidget {
  const _RankingListItem({
    required this.item,
  });

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.burgundy,
              child: Text(
                '${item.position}',
                style: const TextStyle(
                  color: AppTheme.cream,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 3),
                  Text(
                    '@${item.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.stadium_rounded,
                        color: AppTheme.gold,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.favoriteStand,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _LevelInlineBadge(points: item.loyaltyPoints),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppTheme.gold,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.loyaltyPoints} pts',
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ... existing code ...

class _LevelInlineBadge extends StatelessWidget {
  const _LevelInlineBadge({
    required this.points,
  });

  final int points;

  @override
  Widget build(BuildContext context) {
    final level = GamificationUtils.levelForPoints(points);

    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.gold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.gold.withOpacity(0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            level.icon,
            color: AppTheme.gold,
            size: 13,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              level.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionBadge extends StatelessWidget {
  const _PositionBadge({
    required this.position,
    required this.color,
    required this.foregroundColor,
    required this.icon,
  });

  final int position;
  final Color color;
  final Color foregroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: foregroundColor,
            size: 22,
          ),
          Text(
            '#$position',
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.background.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppTheme.background,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.background,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsPill extends StatelessWidget {
  const _PointsPill({
    required this.points,
  });

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.gold.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$points pts',
        style: const TextStyle(
          color: AppTheme.gold,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.emoji_events_outlined,
          color: AppTheme.gold.withOpacity(0.9),
          size: 54,
        ),
        const SizedBox(height: 18),
        const Text(
          'Sin ranking aún',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.cream,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Cuando los hinchas empiecen a sumar puntos, aparecerán aquí.',
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
  });

  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
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