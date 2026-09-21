import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/marketplace_models.dart';
import 'providers/marketplace_provider.dart';

class SellerOnboardingPage extends ConsumerStatefulWidget {
  const SellerOnboardingPage({super.key});

  @override
  ConsumerState<SellerOnboardingPage> createState() =>
      _SellerOnboardingPageState();
}

class _SellerOnboardingPageState extends ConsumerState<SellerOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _whatsappController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _ipAck = false;
  bool _submitting = false;

  @override
  void dispose() {
    _whatsappController.dispose();
    _storeNameController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_ipAck) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes aceptar la declaración de propiedad intelectual.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(marketplaceServiceProvider).submitSeller(
            SellerOnboardingRequest(
              whatsapp: _whatsappController.text,
              storeName: _storeNameController.text,
              city: _cityController.text,
              storeDescription: _descriptionController.text,
              ipAcknowledged: _ipAck,
            ),
          );
      ref.invalidate(sellerMeProvider);
      ref.invalidate(sellerSummaryProvider);
      if (!mounted) return;
      context.go('/marketplace/seller/dashboard');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos registrar tu tienda. Inténtalo de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerAsync = ref.watch(sellerMeProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Publica tu emprendimiento')),
      body: sellerAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (_, _) => GarraErrorState(
          onRetry: () => ref.invalidate(sellerMeProvider),
        ),
        data: (seller) {
          if (seller != null &&
              (seller.isApproved || seller.isPending) &&
              !seller.isNone) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go('/marketplace/seller/dashboard');
            });
            return const Center(
              child: CircularProgressIndicator(color: Color(GarraColors.gold)),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.lg,
                GarraSpacing.md,
                GarraSpacing.lg,
                GarraSpacing.section,
              ),
              children: [
                Text(
                  'Registra tu emprendimiento crema',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: GarraSpacing.sm),
                Text(
                  'Los hinchas te contactarán por WhatsApp. No hay carrito ni pagos en la app.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: GarraSpacing.xxl),
                TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    hintText: '51999999999',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa tu WhatsApp';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: GarraSpacing.lg),
                TextFormField(
                  controller: _storeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la tienda',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el nombre de tu tienda';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: GarraSpacing.lg),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad (opcional)',
                  ),
                ),
                const SizedBox(height: GarraSpacing.lg),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                ),
                const SizedBox(height: GarraSpacing.xxl),
                CheckboxListTile(
                  value: _ipAck,
                  onChanged: (value) =>
                      setState(() => _ipAck = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(GarraColors.gold),
                  title: Text(
                    'Declaro que soy titular o tengo autorización para usar '
                    'las marcas, imágenes y contenidos que publique. '
                    'Acepto que Garra Digital puede retirar publicaciones '
                    'que infrinjan derechos de propiedad intelectual.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: GarraSpacing.xxl),
                GarraPrimaryButton(
                  label: 'Enviar solicitud',
                  loading: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
