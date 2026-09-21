import 'package:flutter/material.dart';

import '../../../../core/design/garra_colors.dart';
import '../../../../core/design/garra_spacing.dart';
import '../../../../core/widgets/garra_card.dart';
import '../../data/retention_models.dart';
import '../../data/retention_service.dart';
import '../season_progress_page.dart';

class DailyGarraCard extends StatefulWidget {
  const DailyGarraCard({super.key});

  @override
  State<DailyGarraCard> createState() => _DailyGarraCardState();
}

class _DailyGarraCardState extends State<DailyGarraCard> {
  final _service = RetentionService();
  DailyGarraModel? _daily;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final daily = await _service.dailySummary();
      if (!mounted) return;
      setState(() {
        _daily = daily;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _daily == null) return const SizedBox.shrink();
    final d = _daily!;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: GarraCard(
        onTap: () => openRetentionDestination(context, d.destination),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hoy en Garra',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(GarraColors.gold),
                  ),
            ),
            const SizedBox(height: 6),
            Text(d.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(d.message, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              d.ctaLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(GarraColors.gold),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
