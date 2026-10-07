import 'package:flutter/material.dart';

import '../data/garra_football_models.dart';
import 'football_match_card.dart';
import 'football_team_crest.dart';

/// SONIC_04/06A Standings: Competition → Stage → Group → Rows.
/// Stage selector when multiple stages; group selector when the selected stage has multiple groups.
/// Provider names only (never invent "Grupo A/B"); never concatenate distinct groups.
class FootballStandingsView extends StatelessWidget {
  const FootballStandingsView({super.key, required this.rows, required this.competitionName,
    required this.selectedStage, required this.onStageChanged, this.selectedGroup,
    this.onGroupChanged, this.featuredTeamId, this.footer, this.onTeamTap});
  final List<Map<String, dynamic>> rows;
  final String competitionName;
  final String? selectedStage;
  final ValueChanged<String> onStageChanged;
  final String? selectedGroup;
  final ValueChanged<String>? onGroupChanged;
  final int? featuredTeamId;
  final Widget? footer;
  final FootballTeamTap? onTeamTap;

  bool _featured(Map<String, dynamic> row) {
    if (row['featured'] == true) return true;
    final id = (row['teamId'] as num?)?.toInt();
    return featuredTeamId != null && id != null && id == featuredTeamId;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stages = FootballStandingStage.fromRows(rows);
    final stage = stages.firstWhere((s) => s.name == selectedStage, orElse: () => stages.first);
    final groups = stage.groups;
    final multiGroup = groups.length > 1;
    final groupKey = multiGroup
        ? (groups.any((g) => g.key == selectedGroup) ? selectedGroup : groups.first.key)
        : null;
    final visible = stage.rowsFor(groupKey);
    final labelStyle = text.labelSmall?.copyWith(fontWeight: FontWeight.w800);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(competitionName, key: const ValueKey('standings_competition'),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ),
        if (stages.length > 1 && stages.length <= 4)
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final s in stages)
              ChoiceChip(
                key: ValueKey('stage_${s.name}'),
                label: Text(footballStageLabel(s.name)),
                visualDensity: VisualDensity.compact,
                selected: s.name == stage.name,
                onSelected: (_) => onStageChanged(s.name),
              ),
          ]),
        if (stages.length > 4)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('stage_selector'),
              icon: const Icon(Icons.expand_more),
              label: Text(footballStageLabel(stage.name)),
              onPressed: () => _pickStage(context, stages, stage.name),
            ),
          ),
        if (stages.length == 1 && footballStageLabel(stage.name) != 'Tabla' && !multiGroup)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(footballStageLabel(stage.name), style: text.titleSmall),
          ),
        if (multiGroup && groups.length <= 4) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final g in groups)
              ChoiceChip(
                key: ValueKey('group_${g.key}'),
                label: Text(footballStageLabel(g.key)),
                visualDensity: VisualDensity.compact,
                selected: g.key == groupKey,
                onSelected: onGroupChanged == null ? null : (_) => onGroupChanged!(g.key),
              ),
          ]),
        ],
        if (multiGroup && groups.length > 4)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('group_selector'),
              icon: const Icon(Icons.expand_more),
              label: Text(footballStageLabel(groupKey)),
              onPressed: onGroupChanged == null
                  ? null
                  : () => _pickGroup(context, groups, groupKey!),
            ),
          ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Row(children: [
            SizedBox(width: 30, child: Text('POS', style: labelStyle)),
            const SizedBox(width: 34),
            Expanded(child: Text('EQUIPO', style: labelStyle)),
            SizedBox(width: 30, child: Text('PJ', textAlign: TextAlign.center, style: labelStyle)),
            SizedBox(width: 40, child: Text('DG', textAlign: TextAlign.center, style: labelStyle)),
            SizedBox(width: 36, child: Text('PTS', textAlign: TextAlign.end, style: labelStyle)),
          ]),
        ),
        for (final row in visible)
          _StandingRow(row: row, featured: _featured(row), onTeamTap: onTeamTap),
        ?footer,
      ],
    );
  }

  Future<void> _pickStage(BuildContext context, List<FootballStandingStage> stages, String current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final s in stages)
            ListTile(
              key: ValueKey('stage_option_${s.name}'),
              title: Text(footballStageLabel(s.name)),
              trailing: s.name == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(s.name),
            ),
        ]),
      ),
    );
    if (picked != null) onStageChanged(picked);
  }

  Future<void> _pickGroup(BuildContext context, List<FootballStandingGroup> groups, String current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final g in groups)
            ListTile(
              key: ValueKey('group_option_${g.key}'),
              title: Text(footballStageLabel(g.key)),
              trailing: g.key == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(g.key),
            ),
        ]),
      ),
    );
    if (picked != null) onGroupChanged?.call(picked);
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.row, required this.featured, this.onTeamTap});
  final Map<String, dynamic> row;
  final bool featured;
  final FootballTeamTap? onTeamTap;

  Color? _zone(BuildContext context) {
    final d = row['description']?.toString().toLowerCase() ?? '';
    if (d.isEmpty) return null;
    final garra = garraColors(context);
    if (d.contains('relegation') || d.contains('descenso')) return garra.danger;
    if (d.contains('libertadores') || d.contains('champions') || d.contains('promotion')) return garra.success;
    if (d.contains('sudamericana') || d.contains('europa')) return garra.brandPrestige;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final garra = garraColors(context);
    final scheme = Theme.of(context).colorScheme;
    final diff = row['goalDifference'];
    final dg = diff is num ? '${diff > 0 ? '+' : ''}$diff' : '–';
    final zone = _zone(context);
    final team = row['team']?.toString() ?? 'Equipo';
    final crest = footballCrestUrl(row['crestUrl'] ?? row['logoUrl']);
    final teamId = (row['teamId'] as num?)?.toInt();
    final identity = Row(children: [
      FootballTeamCrest(key: ValueKey('standing_crest_${teamId ?? team}'), name: team, url: crest, size: 24),
      const SizedBox(width: 10),
      Expanded(child: Text(team, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: featured ? FontWeight.w900 : FontWeight.w600))),
    ]);
    return Container(
      key: featured ? const ValueKey('standing_featured_row') : null,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: featured
            ? garra.brandPrimary.withValues(alpha: 0.07)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(10),
        border: featured ? Border.all(color: garra.brandPrestige.withValues(alpha: 0.55)) : null,
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 3, decoration: BoxDecoration(color: zone ?? Colors.transparent,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 7, 8, 7),
              child: Row(children: [
                SizedBox(width: 30, child: Text('${row['rank'] ?? '–'}',
                    style: const TextStyle(fontWeight: FontWeight.w800))),
                Expanded(
                  child: teamId == null || onTeamTap == null ? identity : InkWell(
                    key: ValueKey('standing_team_$teamId'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onTeamTap!(teamId, team, crest),
                    child: identity,
                  ),
                ),
                SizedBox(width: 30, child: Text('${row['played'] ?? '–'}', textAlign: TextAlign.center)),
                SizedBox(width: 40, child: Text(dg, textAlign: TextAlign.center)),
                SizedBox(width: 36, child: Text('${row['points'] ?? '–'}', textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w900))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
