import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/history_models.dart';
import '../widgets/garra_history_card.dart';
import 'providers/history_provider.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final List<FanHistoryEntry> _items = [];
  final Set<String> _seenIds = {};
  String? _nextCursor;
  bool _hasNext = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _fetching = false;
  Object? _error;
  HistoryFilter _filter = HistoryFilter.all;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasNext || _loadingMore || _loading || _fetching) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (_fetching) return;
    if (!reset && (!_hasNext || _loadingMore)) return;

    setState(() {
      _fetching = true;
      if (reset) {
        _loading = true;
        _error = null;
        _items.clear();
        _seenIds.clear();
        _nextCursor = null;
        _hasNext = false;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final page = await ref.read(historyServiceProvider).getMyHistory(
            cursor: reset ? null : _nextCursor,
            type: _filter.backendType,
          );
      if (!mounted) return;

      final fresh = <FanHistoryEntry>[];
      for (final entry in page.items) {
        if (entry.id.isEmpty || _seenIds.contains(entry.id)) continue;
        _seenIds.add(entry.id);
        fresh.add(entry);
      }

      setState(() {
        _items.addAll(fresh);
        _nextCursor = page.nextCursor;
        _hasNext = page.hasNext;
        _loading = false;
        _loadingMore = false;
        _fetching = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
        _fetching = false;
      });
    }
  }

  void _onFilterChanged(HistoryFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(historyYearsProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Mi Historia Crema'),
      ),
      body: Column(
        children: [
          _FilterChips(
            selected: _filter,
            onSelected: _onFilterChanged,
          ),
          yearsAsync.maybeWhen(
            data: (years) {
              if (years.isEmpty) return const SizedBox.shrink();
              return _YearShortcuts(years: years);
            },
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(GarraSpacing.lg),
        child: Column(
          children: [
            GarraSkeleton(height: 88),
            SizedBox(height: GarraSpacing.md),
            GarraSkeleton(height: 88),
            SizedBox(height: GarraSpacing.md),
            GarraSkeleton(height: 88),
          ],
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return GarraErrorState(onRetry: () => _load(reset: true));
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        color: const Color(GarraColors.gold),
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            GarraEmptyState(
              title: 'Tu historia recién comienza.',
              message:
                  'Cuando vivas fechas, predicciones y misiones, aparecerán aquí.',
            ),
          ],
        ),
      );
    }

    final sections = _groupByMonth(_items);
    final showFooter = _hasNext || _loadingMore;

    return RefreshIndicator(
      color: const Color(GarraColors.gold),
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.sm,
          GarraSpacing.lg,
          GarraSpacing.section,
        ),
        itemCount: sections.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= sections.length) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.all(GarraSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: GarraSpacing.md),
              child: TextButton(
                onPressed: () => _load(reset: false),
                child: const Text('Cargar más'),
              ),
            );
          }
          final section = sections[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: GarraSpacing.md,
                  bottom: GarraSpacing.sm,
                ),
                child: Text(
                  section.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(GarraColors.gold),
                      ),
                ),
              ),
              ...section.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
                  child: GarraHistoryCard(entry: entry),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_MonthSection> _groupByMonth(List<FanHistoryEntry> entries) {
    final map = <String, List<FanHistoryEntry>>{};
    final order = <String>[];
    final formatter = DateFormat('MMMM yyyy');

    for (final entry in entries) {
      final key = formatter.format(entry.occurredAt.toLocal());
      if (!map.containsKey(key)) {
        map[key] = [];
        order.add(key);
      }
      map[key]!.add(entry);
    }

    return order
        .map(
          (key) => _MonthSection(
            label: _capitalize(key),
            entries: map[key]!,
          ),
        )
        .toList();
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _MonthSection {
  const _MonthSection({required this.label, required this.entries});

  final String label;
  final List<FanHistoryEntry> entries;
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onSelected,
  });

  final HistoryFilter selected;
  final ValueChanged<HistoryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.lg),
        itemCount: HistoryFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: GarraSpacing.sm),
        itemBuilder: (context, index) {
          final filter = HistoryFilter.values[index];
          final isSelected = filter == selected;
          return ChoiceChip(
            label: Text(filter.label),
            selected: isSelected,
            onSelected: (_) => onSelected(filter),
            selectedColor: const Color(GarraColors.garnet),
            backgroundColor: const Color(GarraColors.surface),
            labelStyle: TextStyle(
              color: isSelected
                  ? const Color(GarraColors.cream)
                  : const Color(GarraColors.textSecondary),
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: isSelected
                  ? const Color(GarraColors.gold)
                  : const Color(GarraColors.borderSubtle),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GarraRadius.pill),
            ),
          );
        },
      ),
    );
  }
}

class _YearShortcuts extends StatelessWidget {
  const _YearShortcuts({required this.years});

  final List<int> years;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarraSpacing.lg,
        GarraSpacing.sm,
        GarraSpacing.lg,
        GarraSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: years.map((year) {
            return Padding(
              padding: const EdgeInsets.only(right: GarraSpacing.sm),
              child: ActionChip(
                label: Text('Mi Año Crema $year'),
                onPressed: () => context.push('/history/year/$year'),
                backgroundColor: const Color(GarraColors.surfaceRaised),
                labelStyle: const TextStyle(
                  color: Color(GarraColors.cream),
                  fontWeight: FontWeight.w700,
                ),
                side: const BorderSide(color: Color(GarraColors.gold)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
