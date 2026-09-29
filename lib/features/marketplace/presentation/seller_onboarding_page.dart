import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/network/garra_error.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_single_photo_field.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/marketplace_models.dart';
import '../data/marketplace_service.dart';
import 'providers/marketplace_provider.dart';

class SellerOnboardingPage extends ConsumerStatefulWidget {
  const SellerOnboardingPage({super.key, this.media});

  final MediaUploadService? media;

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
  late final MediaUploadService _media = widget.media ?? MediaUploadService();
  XFile? _photo;

  Future<void> _pickPhoto() async {
    final file = await _media.pickImage();
    if (file == null || !mounted) return;
    setState(() => _photo = file);
  }

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

    if (!allowNetworkAction(context)) return;

    setState(() => _submitting = true);
    try {
      String? logoAssetId;
      final photo = _photo;
      if (photo != null) {
        logoAssetId = await uploadSinglePhoto(
          _media,
          photo,
          MediaUploadPurpose.storeLogo,
        );
      }
      if (!mounted || !allowNetworkAction(context)) return;
      await ref
          .read(marketplaceServiceProvider)
          .submitSeller(
            SellerOnboardingRequest(
              whatsapp: _whatsappController.text,
              storeName: _storeNameController.text,
              city: _cityController.text,
              storeDescription: _descriptionController.text,
              ipAcknowledged: _ipAck,
              logoMediaAssetId: logoAssetId,
            ),
          );
      ref.invalidate(sellerMeProvider);
      ref.invalidate(sellerSummaryProvider);
      if (!mounted) return;
      context.go('/marketplace/seller/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_sellerErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _sellerErrorMessage(Object error) {
    if (error is SinglePhotoUploadException) return error.message;
    if (error is MarketplaceServiceException) {
      final msg = error.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    final classified = classifyDioError(error).message;
    if (classified.isNotEmpty &&
        classified != 'No pudimos completar la acción.') {
      return classified;
    }
    return 'No pudimos registrar tu tienda. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final sellerAsync = ref.watch(sellerMeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Publica tu emprendimiento')),
      body: sellerAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(GarraColors.gold)),
        ),
        error: (_, _) =>
            GarraErrorState(onRetry: () => ref.invalidate(sellerMeProvider)),
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
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.lg,
                GarraSpacing.md,
                GarraSpacing.lg,
                GarraSpacing.section,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Registra tu emprendimiento crema',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: GarraSpacing.sm),
                  Text(
                    'Compra crema, apoya crema.',
                    key: const ValueKey('seller_onboarding_claim'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.garraColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.xs),
                  Text(
                    'Garra ayuda a que la comunidad de hinchas descubra tu '
                    'negocio. Los hinchas te contactan por WhatsApp y la compra '
                    'se coordina directamente contigo: Garra no procesa pagos '
                    'y no hay carrito en la app. Es un espacio de emprendimientos '
                    'de hinchas, no de tiendas oficiales del club.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.garraColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: GarraSpacing.lg),
                  GarraFormSection(
                    title: 'TU EMPRENDIMIENTO',
                    children: [
                      GarraTextField(
                        label: 'WhatsApp',
                        controller: _whatsappController,
                        keyboardType: TextInputType.phone,
                        helper: 'Ejemplo: 51999999999',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa tu WhatsApp';
                          }
                          return null;
                        },
                      ),
                      GarraTextField(
                        label: 'Nombre de la tienda',
                        controller: _storeNameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa el nombre de tu tienda';
                          }
                          return null;
                        },
                      ),
                      GarraTextField(
                        label: 'Ciudad',
                        controller: _cityController,
                        helper: 'Opcional',
                      ),
                      GarraTextArea(
                        label: 'Descripción',
                        controller: _descriptionController,
                        helper: 'Opcional',
                        minLines: 3,
                      ),
                      GarraSinglePhotoField(
                        key: const ValueKey('business_photo_field'),
                        file: _photo,
                        enabled: !_submitting,
                        label: 'Foto del negocio (opcional)',
                        helper:
                            'Una sola imagen: tu logo, tu local o tu producto principal.',
                        onPick: _pickPhoto,
                        onRemove: () => setState(() => _photo = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: GarraSpacing.lg),
                  GarraFormSection(
                    title: 'DECLARACIÓN',
                    children: [
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
                    ],
                  ),
                  const SizedBox(height: GarraSpacing.lg),
                  GarraPrimaryButton(
                    label: 'Enviar solicitud',
                    loading: _submitting,
                    onPressed: _submit,
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
