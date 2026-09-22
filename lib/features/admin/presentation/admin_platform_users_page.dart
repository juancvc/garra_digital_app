import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../auth/data/auth_service.dart';

/// SUPERADMIN-only platform role management.
class AdminPlatformUsersPage extends StatefulWidget {
  const AdminPlatformUsersPage({super.key});

  @override
  State<AdminPlatformUsersPage> createState() => _AdminPlatformUsersPageState();
}

class _AdminPlatformUsersPageState extends State<AdminPlatformUsersPage> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _allowed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gateAndLoad();
  }

  Future<void> _gateAndLoad() async {
    try {
      final me = await _auth.me();
      if (!mounted) return;
      if (me?.isSuperAdmin != true) {
        setState(() {
          _allowed = false;
          _loading = false;
          _error = 'Solo SUPERADMIN puede gestionar roles.';
        });
        return;
      }
      setState(() => _allowed = true);
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _allowed = false;
        _error = 'No pudimos verificar tu rol';
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await DioClient.instance.get('/admin/platform/users');
      final data = res.data['data'];
      final list = <Map<String, dynamic>>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map) list.add(Map<String, dynamic>.from(item));
        }
      }
      if (!mounted) return;
      setState(() {
        _users = list;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.response?.statusCode == 403
            ? 'Acceso denegado'
            : 'No pudimos cargar usuarios';
      });
    }
  }

  Future<void> _setRole(String id, String role) async {
    await DioClient.instance.patch(
      '/admin/platform/users/$id/role',
      queryParameters: {'role': role},
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.background),
      appBar: AppBar(title: const Text('Usuarios y roles')),
      body: !_allowed
          ? GarraEmptyState(
              title: 'Sin acceso',
              message: _error ?? 'No autorizado',
              actionLabel: 'Volver',
              onAction: () => context.pop(),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(GarraSpacing.lg),
                  itemCount: _users.length,
                  itemBuilder: (context, i) {
                    final u = _users[i];
                    final id = u['id']?.toString() ?? '';
                    final role = u['role']?.toString() ?? 'USER';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
                      child: GarraCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['displayName']?.toString() ?? ''),
                            Text('@${u['username']} · $role'),
                            if (role != 'SUPERADMIN')
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final r in ['USER', 'MODERATOR', 'ADMIN'])
                                    TextButton(
                                      onPressed: role == r
                                          ? null
                                          : () => _setRole(id, r),
                                      child: Text(r),
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
