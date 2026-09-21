import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_motion.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/retention_models.dart';
import '../data/retention_service.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final _service = RetentionService();
  List<AchievementModel> _items = [];
  bool _loading = true;
  String? _error;
  String? _celebrateId;

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
      final items = await _service.myAchievements();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tus logros';
        _loading = false;
      });
    }
  }

  List<AchievementModel> get _unlocked =>
      _items.where((e) => e.unlocked).toList();
  List<AchievementModel> get _lockedVisible =>
      _items.where((e) => !e.unlocked && !e.secret).toList();
  List<AchievementModel> get _hidden =>
      _items.where((e) => !e.unlocked && e.secret).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Mis Logros')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? GarraErrorState(onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(GarraSpacing.lg),
                    children: [
                      _Section(
                        title: 'Desbloqueados',
                        children: _unlocked.isEmpty
                            ? [
                                Text('Aún no desbloqueas logros.',
                                    style: Theme.of(context).textTheme.bodyMedium)
                              ]
                            : _unlocked
                                .map((a) => _AchievementCard(
                                      achievement: a,
                                      celebrating: _celebrateId == a.id,
                                      onShare: () => _share(a),
                                      onTap: () => _microCelebrate(a),
                                    ))
                                .toList(),
                      ),
                      const SizedBox(height: GarraSpacing.xl),
                      _Section(
                        title: 'Por conseguir',
                        children: _lockedVisible
                            .map((a) => _AchievementCard(achievement: a))
                            .toList(),
                      ),
                      if (_hidden.isNotEmpty) ...[
                        const SizedBox(height: GarraSpacing.xl),
                        _Section(
                          title: 'Ocultos',
                          children: _hidden
                              .map((a) => _AchievementCard(achievement: a))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  void _microCelebrate(AchievementModel a) {
    if (!a.unlocked) return;
    setState(() => _celebrateId = a.id);
    Future.delayed(GarraMotion.normal, () {
      if (mounted && _celebrateId == a.id) {
        setState(() => _celebrateId = null);
      }
    });
  }

  Future<void> _share(AchievementModel a) async {
    await Share.share(
      'Desbloqueé «${a.name}» en Garra Digital',
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: GarraSpacing.md),
        ...children.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.md),
              child: c,
            )),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    this.celebrating = false,
    this.onShare,
    this.onTap,
  });

  final AchievementModel achievement;
  final bool celebrating;
  final VoidCallback? onShare;
  final VoidCallback? onTap;

  Color get _rarityColor {
    switch (achievement.rarity) {
      case 'UNCOMMON':
        return const Color(0xFF6FA8DC);
      case 'RARE':
        return const Color(0xFF9B7EBD);
      case 'EPIC':
        return const Color(GarraColors.gold);
      default:
        return const Color(GarraColors.creamMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return AnimatedScale(
      scale: celebrating ? 1.03 : 1,
      duration: GarraMotion.fast,
      child: GarraCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _rarityColor, width: 1.4),
              ),
              child: Icon(
                a.unlocked ? Icons.emoji_events_outlined : Icons.lock_outline,
                color: _rarityColor,
              ),
            ),
            const SizedBox(width: GarraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(a.description,
                      style: Theme.of(context).textTheme.bodySmall),
                  if (!a.unlocked &&
                      !a.secret &&
                      a.progress != null &&
                      a.target != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (a.progress! / a.target!).clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFF2A2A2A),
                      color: _rarityColor,
                    ),
                    const SizedBox(height: 4),
                    Text('${a.progress}/${a.target}',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                  if (a.nearUnlock) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Casi lo tienes',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(GarraColors.gold),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (a.unlocked && onShare != null)
              IconButton(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share, color: Color(GarraColors.gold)),
              ),
          ],
        ),
      ),
    );
  }
}
