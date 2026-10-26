import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../football/data/garra_football_models.dart';
import '../../football/presentation/football_team_crest.dart';
import 'providers/home_provider.dart';

const _cream = Color(0xFFF3E9D2);
const _gold = Color(0xFFC7A45B);
const _muted = Color(0xFFD3C5B0);

/// One featured fixture above the feed. Build does not start any request.
class HomeFeaturedMatchCard extends ConsumerStatefulWidget {
  const HomeFeaturedMatchCard({
    super.key,
    required this.result,
    this.now,
    this.embedded = false,
  });

  final AsyncValue<FootballFeaturedResult> result;
  final DateTime? now;
  final bool embedded;

  @override
  ConsumerState<HomeFeaturedMatchCard> createState() => _HomeFeaturedMatchCardState();
}

class _HomeFeaturedMatchCardState extends ConsumerState<HomeFeaturedMatchCard> {
  Timer? _clockTimer;
  DateTime _clock = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _clock = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final data = result.asData?.value;
    final featured = data?.featured;
    final match = featured?.live ?? featured?.next ?? featured?.last;
    final usable = match != null && data?.unavailable != true;
    final instant = widget.now ?? _clock;
    final envelopeStale = data?.stale == true;
    final status = usable
        ? homeFeaturedStatus(match, stale: envelopeStale, now: instant)
        : null;

    final inner = usable
        ? _matchContent(context, match, status!, instant, envelopeStale: envelopeStale)
        : _unavailableContent(ref);

    if (widget.embedded) {
      return Semantics(
        container: true,
        child: Padding(
          key: const ValueKey('home_featured_match'),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 2),
          child: inner,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Semantics(
        container: true,
        child: Container(
          key: const ValueKey('home_featured_match'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _gold.withValues(alpha: 0.58)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF351019), Color(0xFF180D10)],
            ),
          ),
          child: Padding(padding: const EdgeInsets.all(14), child: inner),
        ),
      ),
    );
  }

  Widget _unavailableContent(WidgetRef ref) {
    final loading = widget.result.isLoading && !widget.result.hasValue;
    final failed = widget.result.hasError && !widget.result.hasValue;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Eyebrow('DESTACADO'),
      const SizedBox(height: 8),
      Text(
        loading
            ? 'Cargando partido de la U'
            : failed
                ? 'Partido de la U no disponible'
                : 'Partido de la U por confirmar',
        style: const TextStyle(color: _cream, fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        failed
            ? 'El feed sigue disponible.'
            : 'Consulta Centro Garra para ver el calendario disponible.',
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      if (loading) ...[
        const SizedBox(height: 10),
        const LinearProgressIndicator(color: _gold, backgroundColor: Color(0x44C7A45B)),
      ],
      if (failed)
        TextButton(
          onPressed: () => ref.invalidate(homeFeaturedProvider),
          child: const Text('Reintentar', style: TextStyle(color: _gold)),
        ),
    ]);
  }

  Widget _matchContent(
    BuildContext context,
    FootballMatch match,
    String status,
    DateTime instant, {
    required bool envelopeStale,
  }) {
    final isLive = status == 'En vivo';
    final isFinished = status == 'Finalizado';
    final confirmedSchedule = match.isScheduled &&
        match.kickoffConfirmed == true &&
        match.kickoff != null &&
        match.status != 'POSTPONED' &&
        match.status != 'SUSPENDED' &&
        !match.isUnconfirmed;
    final today = confirmedSchedule && _sameLimaDay(match.kickoff!, instant);
    final headline = today
        ? 'HOY JUEGA LA U'
        : isLive
            ? 'LA U EN JUEGO'
            : isFinished
                ? 'RESULTADO'
                : 'PARTIDO FIJADO';
    final competition = [match.competition, ?match.roundLabel]
        .where((part) => part.isNotEmpty)
        .join(' · ');
    final showScore =
        (isLive || isFinished) && match.homeScore != null && match.awayScore != null;
    final center = showScore ? '${match.homeScore} - ${match.awayScore}' : 'VS';
    final countdown = confirmedSchedule ? homeMatchCountdown(match, now: instant) : null;
    final canOpen = match.id > 0 && match.competitionId.isNotEmpty;
    final crestSize = widget.embedded ? 28.0 : 44.0;
    final scheduleLine = confirmedSchedule
        ? '${match.scheduleVerified ? 'Horario verificado · ' : ''}${footballKickoffLine(match)}'
        : (!isLive && !isFinished)
            ? (match.status == 'POSTPONED'
                ? 'Nueva fecha por confirmar'
                : match.status == 'SUSPENDED'
                    ? 'Partido suspendido'
                    : 'Horario por confirmar')
            : null;
    final metaTail = [
      ?countdown,
      if (envelopeStale && confirmedSchedule) 'Actualizando',
    ].join(' · ');

    if (widget.embedded) {
      return _embeddedMatchContent(
        context,
        match: match,
        competition: competition,
        status: status,
        today: today,
        isLive: isLive,
        isFinished: isFinished,
        showScore: showScore,
        center: center,
        scheduleLine: scheduleLine,
        metaTail: metaTail,
        canOpen: canOpen,
        crestSize: crestSize,
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: _Eyebrow('FIJADO · $headline')),
        Flexible(
          child: _StatusPill(
            status: today ? 'Por jugar' : status,
            live: isLive,
          ),
        ),
      ]),
      if (competition.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          competition,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: _Team(name: match.home, crest: match.homeCrestUrl, size: crestSize)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(children: [
            Text(
              center,
              key: const ValueKey('home_match_center'),
              style: TextStyle(
                color: _cream,
                fontSize: showScore ? 20 : 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (isLive && match.liveMinuteLabel != null)
              Text(
                match.liveMinuteLabel!,
                style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w800),
              ),
          ]),
        ),
        Expanded(child: _Team(name: match.away, crest: match.awayCrestUrl, size: crestSize)),
      ]),
      const SizedBox(height: 8),
      if (confirmedSchedule)
        _InfoLine(Icons.schedule_rounded, footballKickoffLine(match))
      else if (!isLive && !isFinished)
        _InfoLine(
          Icons.event_busy_outlined,
          match.status == 'POSTPONED'
              ? 'Nueva fecha por confirmar'
              : match.status == 'SUSPENDED'
                  ? 'Partido suspendido'
                  : 'Horario por confirmar',
        ),
      if (countdown != null) ...[
        const SizedBox(height: 2),
        _InfoLine(
          Icons.hourglass_bottom_rounded,
          countdown,
          key: const ValueKey('home_match_countdown'),
        ),
      ],
      if (envelopeStale && confirmedSchedule) ...[
        const SizedBox(height: 2),
        _InfoLine(Icons.sync_rounded, 'Datos en actualización'),
      ],
      if (canOpen) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('home_featured_open'),
            onPressed: () => context.push(
              '/centro-garra/partido/${match.id}'
              '?competition=${Uri.encodeQueryComponent(match.competitionId)}',
              extra: match,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF211416),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Detalles del partido', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    ]);
  }

  /// PRODUCT-10A.2D: compact Home variant. One status (the pill), one
  /// competition line, teams side by side, a single schedule line with the
  /// existing Lima-time rule, and the detail action on the same row.
  Widget _embeddedMatchContent(
    BuildContext context, {
    required FootballMatch match,
    required String competition,
    required String status,
    required bool today,
    required bool isLive,
    required bool isFinished,
    required bool showScore,
    required String center,
    required String? scheduleLine,
    required String metaTail,
    required bool canOpen,
    required double crestSize,
  }) {
    final schedule = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (scheduleLine != null)
          Text(scheduleLine, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _cream, fontSize: 11,
              fontWeight: FontWeight.w700, height: 1.2)),
        if (metaTail.isNotEmpty)
          Text(metaTail, key: const ValueKey('home_match_countdown'),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _gold, fontSize: 10,
              fontWeight: FontWeight.w700, height: 1.3)),
      ],
    );
    final open = canOpen
        ? TextButton.icon(
            key: const ValueKey('home_featured_open'),
            onPressed: () => context.push(
              '/centro-garra/partido/${match.id}'
              '?competition=${Uri.encodeQueryComponent(match.competitionId)}',
              extra: match,
            ),
            style: TextButton.styleFrom(
              foregroundColor: _gold,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(48, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Detalles del partido', maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                competition.isEmpty ? 'Centro Garra' : competition,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.3),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: _StatusPill(status: status, live: isLive)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _InlineTeam(name: match.home,
              crest: match.homeCrestUrl, size: crestSize)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    center,
                    key: const ValueKey('home_match_center'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: showScore ? _cream : _gold,
                      fontSize: showScore ? 18 : 13,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  if (isLive && match.liveMinuteLabel != null)
                    Text(
                      match.liveMinuteLabel!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(color: _gold, fontSize: 10,
                        fontWeight: FontWeight.w800),
                    ),
                ],
              ),
            ),
            Expanded(child: _InlineTeam(name: match.away,
              crest: match.awayCrestUrl, size: crestSize, alignEnd: true)),
          ],
        ),
        if (scheduleLine != null || metaTail.isNotEmpty || open != null)
          const SizedBox(height: 6),
        LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.15;
          if (open == null) return schedule;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                schedule,
                Align(alignment: Alignment.centerRight, child: open),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: schedule),
              const SizedBox(width: 4),
              open,
            ],
          );
        }),
      ],
    );
  }
}

class _InlineTeam extends StatelessWidget {
  const _InlineTeam({
    required this.name,
    required this.crest,
    required this.size,
    this.alignEnd = false,
  });
  final String name;
  final String? crest;
  final double size;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final label = Flexible(
      child: Text(
        name,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _cream, fontSize: 12,
          fontWeight: FontWeight.w800, height: 1.1),
      ),
    );
    final logo = FootballTeamCrest(name: name, url: crest, size: size);
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [label, const SizedBox(width: 6), logo]
          : [logo, const SizedBox(width: 6), label],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _gold,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.live});
  final String status;
  final bool live;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: live ? const Color(0xFF922A35) : const Color(0x333D2C24),
          border: Border.all(
            color: live ? const Color(0xFFFF928F) : _gold.withValues(alpha: 0.45),
          ),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          status,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _cream, fontSize: 10, fontWeight: FontWeight.w800),
        ),
      );
}

class _Team extends StatelessWidget {
  const _Team({required this.name, required this.crest, required this.size});
  final String name;
  final String? crest;
  final double size;
  @override
  Widget build(BuildContext context) => Column(children: [
        FootballTeamCrest(name: name, url: crest, size: size),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _cream,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ]);
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: _gold),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ]);
}

bool _sameLimaDay(DateTime kickoff, DateTime now) {
  final lima = limaWallClock(now);
  return kickoff.year == lima.year && kickoff.month == lima.month && kickoff.day == lima.day;
}

/// Absolute instant of a confirmed scheduled kickoff (`kickoff` is Lima wall
/// clock, UTC-5), or null when the schedule is not confirmed. Shared by the
/// Home countdown line and the match-detail countdown (PRODUCT-10A.2E).
DateTime? footballConfirmedKickoffUtc(FootballMatch match) {
  final kickoff = match.kickoff;
  if (!match.isScheduled || match.kickoffConfirmed != true || kickoff == null) return null;
  return DateTime.utc(kickoff.year, kickoff.month, kickoff.day, kickoff.hour,
          kickoff.minute)
      .add(const Duration(hours: 5));
}

/// Calculated on build; no timer or provider polling is added.
String? homeMatchCountdown(FootballMatch match, {required DateTime now}) {
  final utcKickoff = footballConfirmedKickoffUtc(match);
  if (utcKickoff == null) return null;
  final remaining = utcKickoff.difference(now.toUtc());
  if (remaining <= Duration.zero) return null;
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  return 'Faltan ${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

String homeFeaturedStatus(FootballMatch match, {required bool stale, DateTime? now}) {
  if (match.status == 'POSTPONED') return 'Postergado';
  if (match.status == 'SUSPENDED') return 'Suspendido';
  if (match.status == 'CANCELLED') return 'Cancelado';
  if (match.isUnconfirmed) return 'Información por confirmar';
  final instant = now ?? DateTime.now();
  if (stale) {
    if (match.isLive) return 'Información por confirmar';
    if (match.isScheduled && match.kickoffConfirmed == true && match.kickoff != null) {
      return _sameLimaDay(match.kickoff!, instant) ? 'Hoy juega la U' : 'Próximo partido';
    }
    return 'Información por confirmar';
  }
  if (match.isLive &&
      match.dataState == 'LIVE_SNAPSHOT' &&
      match.snapshotAt != null &&
      instant.toUtc().difference(match.snapshotAt!).inMinutes < 3) {
    return 'En vivo';
  }
  if (match.isFinished) return 'Finalizado';
  if (match.isScheduled && match.kickoffConfirmed == true && match.kickoff != null) {
    return _sameLimaDay(match.kickoff!, instant) ? 'Hoy juega la U' : 'Próximo partido';
  }
  return 'Información por confirmar';
}
