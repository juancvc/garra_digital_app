import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_action_guard.dart';
import '../../football/data/garra_football_models.dart';
import '../data/home_matchday_poll_service.dart';

final homeMatchdayPollServiceProvider = Provider<HomeMatchdayPollService>(
    (ref) => HomeMatchdayPollService());

typedef HomeMatchdayPollKey = ({int fixtureId, String competition});

final homeMatchdayPollProvider = FutureProvider.autoDispose.family<HomeMatchdayPoll?,
    HomeMatchdayPollKey>((ref, key) => ref.watch(homeMatchdayPollServiceProvider)
        .get(key.fixtureId, key.competition));

/// Optional, independent Home surface: an unavailable poll never blocks the feed.
class HomeMatchdayPollCard extends ConsumerStatefulWidget {
  const HomeMatchdayPollCard({super.key, required this.featured, this.embedded = false});
  final AsyncValue<FootballFeaturedResult> featured;
  final bool embedded;

  @override
  ConsumerState<HomeMatchdayPollCard> createState() => _HomeMatchdayPollCardState();
}

class _HomeMatchdayPollCardState extends ConsumerState<HomeMatchdayPollCard> {
  HomeMatchdayPoll? _submitted;
  bool _changing = false;
  bool _voting = false;
  /// PRODUCT-10A.2D: options stay collapsed until the fan asks for them.
  bool _expanded = false;
  String? _error;

  @override
  void didUpdateWidget(covariant HomeMatchdayPollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_matchKey(oldWidget.featured) != _matchKey(widget.featured)) {
      _submitted = null;
      _changing = false;
      _expanded = false;
      _error = null;
    }
  }

  /// Backend polls are keyed to [FootballFeatured.next], not the live hero slot.
  FootballMatch? _pollMatch(FootballFeatured? featured) =>
      featured?.next ?? featured?.live ?? featured?.last;

  HomeMatchdayPollKey? _matchKey(AsyncValue<FootballFeaturedResult> value) {
    final match = _pollMatch(value.asData?.value.featured);
    return match == null ? null : (fixtureId: match.id, competition: match.competitionId);
  }

  @override
  Widget build(BuildContext context) {
    final envelope = widget.featured.asData?.value;
    final featured = envelope?.featured;
    final match = _pollMatch(featured);
    if (envelope == null || envelope.unavailable || match == null ||
        match.id <= 0 || match.competitionId.isEmpty) {
      return const SizedBox.shrink();
    }
    final key = (fixtureId: match.id, competition: match.competitionId);
    final asyncPoll = ref.watch(homeMatchdayPollProvider(key));
    final poll = _submitted ?? asyncPoll.asData?.value;
    if (poll == null && asyncPoll.isLoading) {
      return _frame(child: const SizedBox(
        height: 3,
        child: LinearProgressIndicator(color: Color(0xFFC7A45B)),
      ));
    }
    if (poll == null && !asyncPoll.hasError) return const SizedBox.shrink();
    if (poll == null) {
      return _frame(child: Row(children: [
        const Expanded(child: Text('No se pudo cargar la encuesta.',
            style: TextStyle(color: Color(0xFFF3E9D2)))),
        TextButton(onPressed: () => ref.invalidate(homeMatchdayPollProvider(key)),
            child: const Text('Reintentar')),
      ]));
    }
    final showResults = (poll.selectedOptionId != null || !poll.isOpen) && !_changing;
    final compact = widget.embedded;
    final canVote = poll.isOpen && poll.selectedOptionId == null;
    final toggleLabel = _expanded
        ? 'Ocultar'
        : canVote
            ? 'Votar'
            : 'Ver resultados';
    final toggleSemantics = _expanded
        ? 'Ocultar opciones de la encuesta'
        : canVote
            ? 'Votar en la encuesta'
            : 'Ver resultados de la encuesta';
    return _frame(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(
        children: [
          const Icon(Icons.poll_outlined, size: 16, color: Color(0xFFC7A45B)),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: 'Encuesta Matchday',
              child: Text(
                poll.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFF3E9D2),
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            container: true,
            button: true,
            expanded: _expanded,
            label: toggleSemantics,
            excludeSemantics: true,
            child: TextButton(
              key: const ValueKey('home_poll_toggle'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC7A45B),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.standard,
              ),
              onPressed: () => setState(() {
                _expanded = !_expanded;
                if (!_expanded) _changing = false;
              }),
              child: Text(toggleLabel, style: TextStyle(
                  fontSize: compact ? 12 : 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      if (_expanded) ...[
        const SizedBox(height: 4),
        Wrap(
          spacing: compact ? 4 : 6,
          runSpacing: 0,
          children: [
            for (final option in poll.options)
              _PollChip(
                key: ValueKey('home_poll_option_${option.id}'),
                label: option.label,
                percentage: showResults ? option.percentage : null,
                selected: option.id == poll.selectedOptionId,
                enabled: poll.isOpen && !_voting && (!showResults || _changing),
                compact: compact,
                onTap: () => _vote(key, option.id),
              ),
          ],
        ),
        if (_voting) const LinearProgressIndicator(color: Color(0xFFC7A45B)),
        if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFFFB4AB))),
        // Wrap (not Row) so the actions move to a new line on narrow widths.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                poll.totalVotes == 1 ? '1 hincha' : '${poll.totalVotes} hinchas',
                style: TextStyle(color: const Color(0xFFD3C5B0), fontSize: compact ? 10 : 12),
              ),
            ),
            if (poll.isOpen && poll.selectedOptionId != null && !_changing)
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: _voting ? null : () => setState(() => _changing = true),
                child: Text('Cambiar voto', style: TextStyle(fontSize: compact ? 11 : 14)),
              ),
            if (showResults)
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: _voting ? null : () {
                  setState(() => _submitted = null);
                  ref.invalidate(homeMatchdayPollProvider(key));
                },
                child: Text('Actualizar', style: TextStyle(fontSize: compact ? 11 : 14)),
              ),
          ],
        ),
      ],
      if (!poll.isOpen) const Text('Votación cerrada',
          style: TextStyle(color: Color(0xFFD3C5B0), fontWeight: FontWeight.w700)),
    ]));
  }

  Widget _frame({required Widget child}) {
    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x55C7A45B))),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: child,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2C121C), Color(0xFF191216)]),
          border: Border.all(color: const Color(0x66C7A45B)),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  Future<void> _vote(HomeMatchdayPollKey key, String optionId) async {
    if (_voting || !allowNetworkAction(context)) return;
    setState(() { _voting = true; _error = null; });
    try {
      final updated = await ref.read(homeMatchdayPollServiceProvider)
          .vote(key.fixtureId, key.competition, optionId);
      if (!mounted) return;
      setState(() { _submitted = updated; _changing = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo guardar el voto. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }
}

class _PollChip extends StatelessWidget {
  const _PollChip({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.percentage,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final int? percentage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final border = selected ? const Color(0xFFC7A45B) : const Color(0x997B6A59);
    final text = percentage == null ? label : '$label · $percentage %';
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: selected,
      label: percentage == null
          ? label
          : '$label, $percentage por ciento${selected ? ', tu voto' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
            color: selected ? const Color(0x332A1218) : const Color(0x22191216),
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(99),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: border),
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFF3E9D2),
                      fontSize: compact ? 11 : 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ),
    );
  }
}
