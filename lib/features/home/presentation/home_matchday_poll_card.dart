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
  const HomeMatchdayPollCard({super.key, required this.featured});
  final AsyncValue<FootballFeaturedResult> featured;

  @override
  ConsumerState<HomeMatchdayPollCard> createState() => _HomeMatchdayPollCardState();
}

class _HomeMatchdayPollCardState extends ConsumerState<HomeMatchdayPollCard> {
  HomeMatchdayPoll? _submitted;
  bool _changing = false;
  bool _voting = false;
  String? _error;

  @override
  void didUpdateWidget(covariant HomeMatchdayPollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_matchKey(oldWidget.featured) != _matchKey(widget.featured)) {
      _submitted = null;
      _changing = false;
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
      return _frame(child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cargando encuesta Matchday',
              style: TextStyle(color: Color(0xFFF3E9D2), fontWeight: FontWeight.w700)),
          SizedBox(height: 10),
          LinearProgressIndicator(color: Color(0xFFC7A45B)),
        ],
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
    final showResults = poll.selectedOptionId != null || !poll.isOpen;
    return _frame(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('ENCUESTA MATCHDAY', style: TextStyle(
          color: Color(0xFFC7A45B), fontSize: 11, fontWeight: FontWeight.w900,
          letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Text(poll.question, style: const TextStyle(
          color: Color(0xFFF3E9D2), fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      for (final option in poll.options) Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton(
          key: ValueKey('home_poll_option_${option.id}'),
          onPressed: poll.isOpen && (!_voting) && (!showResults || _changing)
              ? () => _vote(key, option.id) : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF3E9D2),
            disabledForegroundColor: const Color(0xFFF3E9D2),
            side: BorderSide(color: option.id == poll.selectedOptionId
                ? const Color(0xFFC7A45B) : const Color(0x997B6A59)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          child: Row(children: [
            Expanded(child: Text(option.label, maxLines: 2,
                style: const TextStyle(fontWeight: FontWeight.w700))),
            if (showResults) Text('${option.percentage} %',
                style: const TextStyle(color: Color(0xFFC7A45B),
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      if (_voting) const LinearProgressIndicator(color: Color(0xFFC7A45B)),
      if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFFFB4AB))),
      Text(poll.totalVotes == 1 ? '1 hincha participante'
          : '${poll.totalVotes} hinchas participantes',
          style: const TextStyle(color: Color(0xFFD3C5B0), fontSize: 12)),
      if (poll.isOpen && poll.selectedOptionId != null && !_changing)
        Align(alignment: Alignment.centerRight, child: TextButton(
          onPressed: _voting ? null : () => setState(() => _changing = true),
          child: const Text('Cambiar mi voto'),
        )),
      if (showResults) Align(alignment: Alignment.centerRight, child: TextButton(
        onPressed: _voting ? null : () {
          setState(() => _submitted = null);
          ref.invalidate(homeMatchdayPollProvider(key));
        },
        child: const Text('Actualizar resultados'),
      )),
      if (!poll.isOpen) const Text('Votación cerrada',
          style: TextStyle(color: Color(0xFFD3C5B0), fontWeight: FontWeight.w700)),
    ]));
  }

  Widget _frame({required Widget child}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2C121C), Color(0xFF191216)]),
        border: Border.all(color: const Color(0x66C7A45B)),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  );

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
