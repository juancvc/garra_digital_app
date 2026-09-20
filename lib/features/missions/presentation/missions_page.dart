import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/mission_models.dart';
import 'providers/missions_provider.dart';
import 'widgets/garra_mission_card.dart';

class MissionsPage extends ConsumerWidget {
  const MissionsPage({super.key, this.matchId});

  final String? matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = MissionsQuery(matchId: matchId);
    final missionsAsync = ref.watch(myMissionsProvider(query));

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Misiones'),
      ),
      body: missionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Color(GarraColors.gold),
          ),
        ),
        error: (error, stackTrace) => GarraErrorState(
          onRetry: () => ref.invalidate(myMissionsProvider(query)),
        ),
        data: (missions) => RefreshIndicator(
          color: const Color(GarraColors.gold),
          onRefresh: () async {
            ref.invalidate(myMissionsProvider(query));
            await ref.read(myMissionsProvider(query).future);
          },
          child: _MissionsBody(missions: missions),
        ),
      ),
    );
  }
}

class _MissionsBody extends StatelessWidget {
  const _MissionsBody({required this.missions});

  final List<MissionModel> missions;

  @override
  Widget build(BuildContext context) {
    if (missions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: const [
          SizedBox(height: 80),
          GarraEmptyState(
            title: 'Sin misiones activas',
            message:
                'Cuando haya misiones para ti, aparecerán aquí con tu progreso.',
          ),
        ],
      );
    }

    final active = missions.where((m) => !m.completed).toList();
    final completed = missions.where((m) => m.completed).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.md,
        GarraSpacing.lg,
        GarraSpacing.section,
      ),
      children: [
        if (active.isNotEmpty) ...[
          Text(
            'Activas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: GarraSpacing.md),
          ...active.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.md),
              child: GarraMissionCard(mission: m, showSteps: true),
            ),
          ),
        ],
        if (completed.isNotEmpty) ...[
          const SizedBox(height: GarraSpacing.sm),
          Text(
            'Completadas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: GarraSpacing.md),
          ...completed.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.md),
              child: GarraMissionCard(mission: m, showSteps: true),
            ),
          ),
        ],
      ],
    );
  }
}
