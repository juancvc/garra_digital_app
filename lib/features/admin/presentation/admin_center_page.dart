import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../auth/data/auth_service.dart';
import '../data/admin_center_service.dart';

/// Operational admin hub. Visibility gated by backend role (ADMIN).
class AdminCenterPage extends StatefulWidget {
  const AdminCenterPage({super.key});

  @override
  State<AdminCenterPage> createState() => _AdminCenterPageState();
}

class _AdminCenterPageState extends State<AdminCenterPage> {
  final _auth = AuthService();
  bool _checking = true;
  bool _allowed = false;
  String? _gateError;

  @override
  void initState() {
    super.initState();
    _gate();
  }

  Future<void> _gate() async {
    try {
      final me = await _auth.me();
      if (!mounted) return;
      setState(() {
        _allowed = me?.isAdmin == true;
        _checking = false;
        if (!_allowed) {
          _gateError = 'Solo administradores pueden abrir Centro Garra.';
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _allowed = false;
        _gateError = e.response?.statusCode == 403
            ? 'Acceso denegado'
            : 'No pudimos verificar tu rol';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _allowed = false;
        _gateError = 'No pudimos verificar tu rol';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Centro Garra')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : !_allowed
              ? GarraEmptyState(
                  title: 'Sin acceso',
                  message: _gateError ?? 'No autorizado',
                  actionLabel: 'Volver',
                  onAction: () => context.pop(),
                )
              : ListView(
                  padding: const EdgeInsets.all(GarraSpacing.lg),
                  children: [
                    Text(
                      'Pendientes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Operación diaria de staging y producción.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: GarraSpacing.lg),
                    _AdminTile(
                      title: 'Reportes',
                      subtitle: 'Cola de moderación de contenido',
                      icon: Icons.flag_outlined,
                      onTap: () => context.push('/admin/reportes'),
                    ),
                    _AdminTile(
                      title: 'Negocios',
                      subtitle: 'Solicitudes de negocio Crema',
                      icon: Icons.storefront_outlined,
                      onTap: () => context.push('/admin/negocios'),
                    ),
                    _AdminTile(
                      title: 'Solidaria',
                      subtitle: 'Campañas pendientes de verificación',
                      icon: Icons.volunteer_activism_outlined,
                      onTap: () => context.push('/admin/solidaria'),
                    ),
                    _AdminTile(
                      title: 'Marketplace',
                      subtitle: 'Sellers, tiendas y listings',
                      icon: Icons.shopping_bag_outlined,
                      onTap: () => context.push('/admin/marketplace'),
                    ),
                    _AdminTile(
                      title: 'Comunidades',
                      subtitle: 'Abrir directorio de Comunidades Cremas',
                      icon: Icons.groups_outlined,
                      onTap: () => context.push('/clans'),
                    ),
                  ],
                ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: GarraCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: const Color(GarraColors.gold)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(GarraColors.gold)),
          ],
        ),
      ),
    );
  }
}

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final _admin = AdminCenterService();
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
      final items = await _admin.moderationQueue();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmHide(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ocultar publicación'),
        content: const Text('La publicación quedará oculta (soft hide).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ocultar')),
        ],
      ),
    );
    if (ok != true) return;
    await _admin.hidePost(id, note: 'admin hide');
    await _load();
  }

  Future<void> _dismiss(String id) async {
    await _admin.dismissReport(id, note: 'dismissed');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Reportes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const GarraEmptyState(
                  title: 'Cola limpia',
                  message: 'No hay reportes pendientes.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(GarraSpacing.lg),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final id = item['id']?.toString() ?? '';
                      final type = item['targetType']?.toString() ?? '';
                      final reason = item['reason']?.toString() ?? '';
                      final preview = item['preview']?.toString() ?? '';
                      final count = item['reportCount']?.toString() ?? '1';
                      return GarraCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$type · $reason · $count reportes',
                                style: Theme.of(context).textTheme.titleSmall),
                            if (preview.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(preview, maxLines: 3, overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (type == 'POST')
                                  TextButton(
                                    onPressed: id.isEmpty ? null : () => _confirmHide(id),
                                    child: const Text('Ocultar'),
                                  ),
                                TextButton(
                                  onPressed: id.isEmpty ? null : () => _dismiss(id),
                                  child: const Text('Descartar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class AdminBusinessReviewPage extends StatefulWidget {
  const AdminBusinessReviewPage({super.key});

  @override
  State<AdminBusinessReviewPage> createState() => _AdminBusinessReviewPageState();
}

class _AdminBusinessReviewPageState extends State<AdminBusinessReviewPage> {
  final _admin = AdminCenterService();
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
      final items = await _admin.pendingBusinesses();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo de rechazo'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Negocios pendientes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const GarraEmptyState(
                  title: 'Sin solicitudes',
                  message: 'No hay negocios pendientes de verificar.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(GarraSpacing.lg),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final id = item['id']?.toString() ?? '';
                      final name = item['businessName']?.toString() ??
                          item['name']?.toString() ??
                          'Negocio';
                      final address = item['address']?.toString() ?? '';
                      final contact = item['contactPhone']?.toString() ??
                          item['whatsapp']?.toString() ??
                          '';
                      final status = item['status']?.toString() ?? '';
                      return GarraCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: Theme.of(context).textTheme.titleMedium),
                            if (address.isNotEmpty) Text(address),
                            if (contact.isNotEmpty) Text(contact),
                            Text('Estado: $status',
                                style: Theme.of(context).textTheme.bodySmall),
                            Row(
                              children: [
                                FilledButton(
                                  onPressed: id.isEmpty
                                      ? null
                                      : () async {
                                          await _admin.verifyBusiness(id);
                                          await _load();
                                        },
                                  child: const Text('Verificar'),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: id.isEmpty
                                      ? null
                                      : () async {
                                          final reason = await _askReason();
                                          if (reason == null || reason.isEmpty) return;
                                          await _admin.rejectBusiness(id, reason);
                                          await _load();
                                        },
                                  child: const Text('Rechazar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class AdminSolidarityReviewPage extends StatefulWidget {
  const AdminSolidarityReviewPage({super.key});

  @override
  State<AdminSolidarityReviewPage> createState() =>
      _AdminSolidarityReviewPageState();
}

class _AdminSolidarityReviewPageState extends State<AdminSolidarityReviewPage> {
  final _admin = AdminCenterService();
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
      final items = await _admin.pendingSolidarity();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Solidaria pendiente')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const GarraEmptyState(
                  title: 'Sin campañas',
                  message: 'No hay campañas Solidaria pendientes.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(GarraSpacing.lg),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final id = item['id']?.toString() ?? '';
                      final title = item['title']?.toString() ??
                          item['name']?.toString() ??
                          'Campaña';
                      final desc = item['description']?.toString() ?? '';
                      final zone = item['zone']?.toString() ??
                          item['city']?.toString() ??
                          '';
                      final type = item['type']?.toString() ??
                          item['campaignType']?.toString() ??
                          '';
                      return GarraCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: Theme.of(context).textTheme.titleMedium),
                            if (type.isNotEmpty) Text(type),
                            if (zone.isNotEmpty) Text(zone),
                            if (desc.isNotEmpty)
                              Text(desc, maxLines: 4, overflow: TextOverflow.ellipsis),
                            Row(
                              children: [
                                FilledButton(
                                  onPressed: id.isEmpty
                                      ? null
                                      : () async {
                                          await _admin.verifySolidarity(id);
                                          await _load();
                                        },
                                  child: const Text('Verificar'),
                                ),
                                TextButton(
                                  onPressed: id.isEmpty
                                      ? null
                                      : () async {
                                          await _admin.rejectSolidarity(
                                            id,
                                            'No cumple criterios',
                                          );
                                          await _load();
                                        },
                                  child: const Text('Rechazar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class AdminMarketplaceReviewPage extends StatefulWidget {
  const AdminMarketplaceReviewPage({super.key});

  @override
  State<AdminMarketplaceReviewPage> createState() =>
      _AdminMarketplaceReviewPageState();
}

class _AdminMarketplaceReviewPageState extends State<AdminMarketplaceReviewPage> {
  final _admin = AdminCenterService();
  List<Map<String, dynamic>> _sellers = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _listings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sellers = await _admin.pendingSellers();
      final stores = await _admin.pendingStores();
      final listings = await _admin.pendingListings();
      if (!mounted) return;
      setState(() {
        _sellers = sellers;
        _stores = stores;
        _listings = listings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = _sellers.isEmpty && _stores.isEmpty && _listings.isEmpty;
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Marketplace admin')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : empty
              ? const GarraEmptyState(
                  title: 'Sin pendientes',
                  message: 'No hay sellers, tiendas ni listings por revisar.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(GarraSpacing.lg),
                    children: [
                      if (_sellers.isNotEmpty) ...[
                        Text('Sellers', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ..._sellers.map((s) {
                          final id = s['id']?.toString() ?? '';
                          final name = s['displayName']?.toString() ?? 'Seller';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GarraCard(
                              child: Row(
                                children: [
                                  Expanded(child: Text(name)),
                                  TextButton(
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Aprobar seller'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Aprobar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await _admin.approveSeller(id);
                                        await _load();
                                      }
                                    },
                                    child: const Text('Aprobar'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await _admin.rejectSeller(id, 'OTHER');
                                      await _load();
                                    },
                                    child: const Text('Rechazar'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                      if (_stores.isNotEmpty) ...[
                        Text('Tiendas', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ..._stores.map((s) {
                          final id = s['id']?.toString() ?? '';
                          final name = s['name']?.toString() ?? 'Tienda';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GarraCard(
                              child: Row(
                                children: [
                                  Expanded(child: Text(name)),
                                  TextButton(
                                    onPressed: () async {
                                      await _admin.approveStore(id);
                                      await _load();
                                    },
                                    child: const Text('Aprobar'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await _admin.rejectStore(id, 'OTHER');
                                      await _load();
                                    },
                                    child: const Text('Rechazar'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                      if (_listings.isNotEmpty) ...[
                        Text('Listings', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ..._listings.map((s) {
                          final id = s['id']?.toString() ?? '';
                          final title = s['title']?.toString() ?? 'Listing';
                          final media = s['coverImageUrl']?.toString() ??
                              s['imageUrl']?.toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GarraCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (media != null && media.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        media,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  Text(title),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          await _admin.approveListing(id);
                                          await _load();
                                        },
                                        child: const Text('Aprobar'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await _admin.rejectListing(id, 'OTHER');
                                          await _load();
                                        },
                                        child: const Text('Rechazar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
    );
  }
}
