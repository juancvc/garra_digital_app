import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';

class AdminCommunitiesReviewPage extends StatefulWidget {
  const AdminCommunitiesReviewPage({super.key});

  @override
  State<AdminCommunitiesReviewPage> createState() =>
      _AdminCommunitiesReviewPageState();
}

class _AdminCommunitiesReviewPageState
    extends State<AdminCommunitiesReviewPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await DioClient.instance.get('/admin/communities/pending');
      final data = res.data['data'];
      final list = <Map<String, dynamic>>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map) list.add(Map<String, dynamic>.from(item));
        }
      }
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _act(String id, String action) async {
    await DioClient.instance.post('/admin/communities/$id/$action');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.background),
      appBar: AppBar(title: const Text('Comunidades pendientes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const GarraEmptyState(
                  title: 'Sin pendientes',
                  message: 'No hay comunidades en revisión.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(GarraSpacing.lg),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final id = item['id']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
                      child: GarraCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name']?.toString() ?? ''),
                            Text('@${item['slug'] ?? ''} · ${item['status']}'),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _act(id, 'approve'),
                                  child: const Text('Aprobar'),
                                ),
                                TextButton(
                                  onPressed: () => _act(id, 'reject'),
                                  child: const Text('Rechazar'),
                                ),
                                TextButton(
                                  onPressed: () => _act(id, 'suspend'),
                                  child: const Text('Suspender'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
