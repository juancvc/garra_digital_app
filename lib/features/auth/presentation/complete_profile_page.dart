import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garra_digital_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:garra_digital_app/features/matches/presentation/providers/matches_provider.dart';
import 'package:garra_digital_app/features/predictions/presentation/providers/prediction_provider.dart';
import 'package:garra_digital_app/features/ranking/presentation/providers/ranking_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../notifications/data/push_session_coordinator.dart';
import '../data/google_auth_service.dart';

class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  String? _tribuna;
  bool _isCrema = false;
  bool _loading = false;

  final List<String> tribunas = ['Norte', 'Oriente', 'Occidente', 'Sur'];

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await GoogleAuthService().signOut();
    await SecureStorageService().clearAll();

    if (mounted) {
      context.go('/login');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isCrema) {
      _showSnack('Debes aceptar la declaración crema 🔥');
      return;
    }

    setState(() => _loading = true);

    try {
      final authService = ref.read(authServiceProvider);

      final result = await authService.completeProfile(
        username: _usernameController.text,
        favoriteStand: _tribuna!,
        cremaDeclarationAccepted: _isCrema,
      );

      if (!result.success) {
        _showSnack(result.message);
        return;
      }

      _showSnack('Perfil crema completado correctamente 🔥');

      ref.invalidate(currentUserProvider);
      ref.invalidate(rankingProvider);
      ref.invalidate(upcomingMatchesProvider);
      ref.invalidate(myPredictionsProvider);

      await Future.wait([
        ref.read(currentUserProvider.future),
        ref.read(rankingProvider.future),
        ref.read(upcomingMatchesProvider.future),
        ref.read(myPredictionsProvider.future),
      ]);

      if (mounted) {
        await pushSessionCoordinator.afterAuthenticated();
        if (!mounted) return;
        context.go('/home');
      }
    } catch (e) {
      _showSnack('Error al completar perfil');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Perfil Crema'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.amber,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Salir',
              icon: const Icon(Icons.logout_rounded),
              onPressed: _loading ? null : _logout,
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Completa tu identidad crema 🏟️',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Antes de entrar a la tribuna digital, cuéntanos cómo vives tu pasión por la U.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),

                  _buildInput(
                    controller: _usernameController,
                    label: 'Nombre de usuario',
                    icon: Icons.person_rounded,
                  ),

                  _buildDropdown(
                    label: 'Tribuna favorita',
                    value: _tribuna,
                    items: tribunas,
                    icon: Icons.stadium_rounded,
                    onChanged: (value) => setState(() => _tribuna = value),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isCrema,
                          activeColor: Colors.amber,
                          onChanged: _loading
                              ? null
                              : (value) {
                                  setState(() => _isCrema = value ?? false);
                                },
                        ),
                        const Expanded(
                          child: Text(
                            'Declaro ser hincha crema y quiero formar parte de GarraDigital.',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Entrar a la tribuna',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.amber),
          prefixIcon: Icon(icon, color: Colors.amber),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.amber.withOpacity(0.45)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';

          if (text.isEmpty) return 'Campo requerido';
          if (text.length < 3) return 'Debe tener al menos 3 caracteres';

          return null;
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: const Color(0xFF1A1A1A),
        style: const TextStyle(color: Colors.white),
        iconEnabledColor: Colors.amber,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.amber),
          prefixIcon: Icon(icon, color: Colors.amber),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.amber.withOpacity(0.45)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
        items: items
            .map(
              (item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: _loading ? null : onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Selecciona una opción';
          }
          return null;
        },
      ),
    );
  }
}
