import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/community_service.dart';

/// Global search across fans, communities, businesses, marketplace, Solidaria.
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final _service = CommunityService();
  final _controller = TextEditingController();
  Timer? _debounce;
  String _type = 'ALL';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _results;
  List<String> _recent = [];

  static const _chips = [
    ('ALL', 'Todo'),
    ('FANS', 'Personas'),
    ('COMMUNITIES', 'Comunidades'),
    ('BUSINESSES', 'Negocios'),
    ('MARKETPLACE', 'Marketplace'),
    ('SOLIDARITY', 'Solidaria'),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<File> _recentFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/garra_recent_searches.json');
  }

  Future<void> _loadRecent() async {
    try {
      final file = await _recentFile();
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is List) {
        setState(() => _recent = raw.map((e) => e.toString()).toList());
      }
    } catch (_) {}
  }

  Future<void> _persistRecent(String q) async {
    final next = [q, ..._recent.where((e) => e != q)].take(8).toList();
    setState(() => _recent = next);
    try {
      final file = await _recentFile();
      await file.writeAsString(jsonEncode(next));
    } catch (_) {}
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (value.trim().length >= 2) {
        _search(value.trim());
      } else {
        setState(() {
          _results = null;
          _error = null;
        });
      }
    });
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await _service.globalSearch(q, type: _type == 'ALL' ? null : _type);
      await _persistRecent(q);
      if (!mounted) return;
      setState(() {
        _results = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos buscar ahora';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Buscar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(
                color: Color(GarraColors.cream),
                fontSize: 18,
              ),
              decoration: InputDecoration(
                hintText: 'Personas, comunidades, negocios…',
                hintStyle: const TextStyle(color: Color(GarraColors.creamMuted)),
                prefixIcon:
                    const Icon(Icons.search, color: Color(GarraColors.gold)),
                filled: true,
                fillColor: const Color(GarraColors.garnetDeep),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: (v) {
                if (v.trim().length >= 2) _search(v.trim());
              },
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _chips
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(c.$2),
                        selected: _type == c.$1,
                        onSelected: (_) {
                          setState(() => _type = c.$1);
                          final q = _controller.text.trim();
                          if (q.length >= 2) _search(q);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return GarraErrorState(
        message: _error!,
        onRetry: () => _search(_controller.text.trim()),
      );
    }
    if (_results == null) {
      if (_recent.isEmpty) {
        return const GarraEmptyState(
          title: 'Busca en Garra',
          message: 'Encuentra hinchas, comunidades Cremas, negocios y más.',
        );
      }
      return ListView(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: [
          Text('Recientes', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._recent.map(
            (q) => ListTile(
              leading:
                  const Icon(Icons.history, color: Color(GarraColors.gold)),
              title: Text(q),
              onTap: () {
                _controller.text = q;
                _search(q);
              },
            ),
          ),
        ],
      );
    }

    final fans = (_results!['fans'] as List?) ?? [];
    final communities = (_results!['communities'] as List?) ?? [];
    final businesses = (_results!['businesses'] as List?) ?? [];
    final marketplace = (_results!['marketplace'] as List?) ?? [];
    final solidarity = (_results!['solidarity'] as List?) ?? [];

    final empty = fans.isEmpty &&
        communities.isEmpty &&
        businesses.isEmpty &&
        marketplace.isEmpty &&
        solidarity.isEmpty;
    if (empty) {
      return const GarraEmptyState(
        title: 'Sin resultados',
        message: 'Prueba otro término o cambia el filtro.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: [
        if (fans.isNotEmpty) ...[
          Text('Personas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...fans.map((raw) {
            final e = Map<String, dynamic>.from(raw as Map);
            final id = e['id']?.toString() ?? '';
            final name =
                e['displayName']?.toString() ?? e['fullName']?.toString() ?? '';
            final username = e['username']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GarraCard(
                onTap: id.isEmpty ? null : () => context.push('/comunidad/u/$id'),
                child: Row(
                  children: [
                    GarraAvatar(
                      displayName: name.isEmpty ? username : name,
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: Theme.of(context).textTheme.titleSmall),
                          Text(
                            '@$username',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        if (communities.isNotEmpty) ...[
          Text('Comunidades', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...communities.map((raw) {
            final e = Map<String, dynamic>.from(raw as Map);
            final slug = e['slug']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GarraCard(
                onTap: slug.isEmpty ? null : () => context.push('/clans/$slug'),
                child: Text(e['title']?.toString() ?? e['name']?.toString() ?? ''),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        if (businesses.isNotEmpty) ...[
          Text('Negocios', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...businesses.map((raw) {
            final e = Map<String, dynamic>.from(raw as Map);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GarraCard(
                onTap: () => context.push('/ruta-templo'),
                child: Text(e['title']?.toString() ?? e['name']?.toString() ?? ''),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        if (marketplace.isNotEmpty) ...[
          Text('Marketplace', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...marketplace.map((raw) {
            final e = Map<String, dynamic>.from(raw as Map);
            final slug = e['slug']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GarraCard(
                onTap: slug.isEmpty
                    ? null
                    : () => context.push('/marketplace/stores/$slug'),
                child: Text(e['title']?.toString() ?? e['name']?.toString() ?? ''),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        if (solidarity.isNotEmpty) ...[
          Text('Solidaria', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...solidarity.map((raw) {
            final e = Map<String, dynamic>.from(raw as Map);
            final id = e['id']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GarraCard(
                onTap: id.isEmpty ? null : () => context.push('/solidaria/$id'),
                child: Text(
                  e['name']?.toString() ?? e['title']?.toString() ?? '',
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
