import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/register_request.dart';
import 'providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _favoriteStand;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static const _stands = ['Norte', 'Oriente', 'Occidente', 'Sur'];

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    if (_favoriteStand == null) {
      _showSnackBar(
        message: 'Selecciona tu tribuna favorita',
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() => _loading = true);

    final authService = ref.read(authServiceProvider);

    final result = await authService.register(
      RegisterRequest(
        email: _emailController.text.trim().toLowerCase(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        favoriteStand: _favoriteStand!,
      ),
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (result.success) {
      _showSnackBar(
        message: 'Cuenta creada correctamente',
        backgroundColor: Colors.green,
      );

      context.go('/login');
    } else {
      _showSnackBar(
        message: result.message,
        backgroundColor: Colors.orange,
      );
    }
  }

  void _showSnackBar({
    required String message,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              Color(0xFF1B070A),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Logo(),
                      const SizedBox(height: 26),
                      const Text(
                        'Únete a la tribuna crema',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.cream,
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea tu cuenta y empieza a participar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.62),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _fullNameController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre completo',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';

                                  if (text.length < 3) {
                                    return 'Ingresa al menos 3 caracteres';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _usernameController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre de usuario',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';

                                  if (text.length < 4) {
                                    return 'Ingresa al menos 4 caracteres';
                                  }

                                  if (text.contains(' ')) {
                                    return 'El usuario no debe tener espacios';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  final isValid = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(text);

                                  if (!isValid) {
                                    return 'Ingresa un email válido';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  final text = value ?? '';

                                  if (text.length < 8) {
                                    return 'La contraseña debe tener mínimo 8 caracteres';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Confirmar contraseña',
                                  prefixIcon: const Icon(Icons.lock_reset),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  final text = value ?? '';

                                  if (text != _passwordController.text) {
                                    return 'Las contraseñas no coinciden';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Tribuna favorita',
                                style: TextStyle(
                                  color: AppTheme.gold,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _stands.map((stand) {
                                  final selected = _favoriteStand == stand;

                                  return ChoiceChip(
                                    label: Text(stand),
                                    selected: selected,
                                    selectedColor: AppTheme.gold,
                                    backgroundColor: const Color(0xFF242424),
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? AppTheme.background
                                          : AppTheme.cream,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    side: BorderSide(
                                      color: selected
                                          ? AppTheme.gold
                                          : AppTheme.cream.withOpacity(0.12),
                                    ),
                                    onSelected: (_) {
                                      setState(() => _favoriteStand = stand);
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: _loading ? null : _register,
                                child: _loading
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.burgundy,
                                  ),
                                )
                                    : const Text('Crear cuenta'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'Ya tengo cuenta',
                          style: TextStyle(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cream,
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withOpacity(0.28),
              blurRadius: 28,
              spreadRadius: 3,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'GD',
            style: TextStyle(
              color: AppTheme.burgundy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}