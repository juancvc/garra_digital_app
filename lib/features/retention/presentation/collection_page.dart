import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/retention_models.dart';
import '../data/retention_service.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final _service = RetentionService();
  List<CollectionItemModel> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';

  static const _filters = [
    ('ALL', 'Todo'),
    ('LOGROS', 'Logros'),
    ('PARTIDOS', 'Partidos'),
    ('LUGARES', 'Lugares'),
    ('SOLIDARIA', 'Solidaria'),
  ];

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
      final items = await _service.myCollection(filter: _filter);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tu colección';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Mi Colección')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: GarraSpacing.lg),
              children: _filters
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: _filter == f.$1,
                        onSelected: (_) {
                          setState(() => _filter = f.$1);
                          _load();
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? GarraErrorState(onRetry: _load)
                    : _items.isEmpty
                        ? const GarraEmptyState(
                            title: 'Colección vacía',
                            message:
                                'Tus momentos Garra aparecerán aquí a medida que participes.',
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(GarraSpacing.lg),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              return GarraCard(
                                onTap: () => _openDetail(item),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _iconFor(item.kind),
                                      color: const Color(GarraColors.gold),
                                    ),
                                    const Spacer(),
                                    Text(
                                      item.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.category,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                    if (item.detail != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        item.detail!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'ACHIEVEMENT':
        return Icons.emoji_events_outlined;
      case 'MATCHDAY':
        return Icons.sports_soccer_outlined;
      case 'PLACE':
        return Icons.place_outlined;
      case 'EVENT':
        return Icons.event_outlined;
      default:
        return Icons.collections_bookmark_outlined;
    }
  }

  void _openDetail(CollectionItemModel item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(item.category),
            if (item.detail != null) ...[
              const SizedBox(height: 8),
              Text(item.detail!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Share.share(
                  'Mi colección Garra: ${item.name}${item.detail != null ? ' — ${item.detail}' : ''}',
                );
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('Compartir'),
            ),
          ],
        ),
      ),
    );
  }
}
