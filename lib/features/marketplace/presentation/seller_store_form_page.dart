import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/marketplace_models.dart';
import 'providers/marketplace_provider.dart';

/// MARKETPLACE_V2_A1: create a new business for an existing seller
/// (POST /seller/me/stores, no second seller onboarding) or edit one by id
/// (PATCH /seller/me/stores/{storeId}). Same store fields as onboarding.
class SellerStoreFormPage extends ConsumerStatefulWidget {
  const SellerStoreFormPage({super.key, this.storeId});

  final String? storeId;

  bool get isEditing => storeId != null && storeId!.isNotEmpty;

  @override
  ConsumerState<SellerStoreFormPage> createState() =>
      _SellerStoreFormPageState();
}

class _SellerStoreFormPageState extends ConsumerState<SellerStoreFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  bool _loading = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _hydrate(MarketplaceStore store) {
    if (_hydrated) return;
    _hydrated = true;
    _nameController.text = store.name;
    _descriptionController.text = store.description ?? '';
    _cityController.text = store.city ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final service = ref.read(marketplaceServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.isEditing) {
        final storeId = widget.storeId!;
        await service.updateSellerStoreById(storeId, {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'city': _cityController.text.trim(),
        });
        ref.invalidate(sellerStoreProvider(storeId));
        ref.invalidate(sellerStoresProvider);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Negocio actualizado.')),
        );
        context.pop();
      } else {
        final store = await service.createSellerStore(
          name: _nameController.text,
          description: _descriptionController.text,
          city: _cityController.text,
        );
        ref.invalidate(sellerStoresProvider);
        ref.invalidate(sellerSummaryProvider);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Negocio creado.')),
        );
        context.pushReplacement('/marketplace/seller/stores/${store.id}');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      final storeAsync = ref.watch(sellerStoreProvider(widget.storeId!));
      if (storeAsync.isLoading && !_hydrated) {
        return Scaffold(
          appBar: AppBar(title: const Text('Editar negocio')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (storeAsync.hasError && !_hydrated) {
        return Scaffold(
          appBar: AppBar(title: const Text('Editar negocio')),
          body: GarraErrorState(
            onRetry: () => ref.invalidate(sellerStoreProvider(widget.storeId!)),
          ),
        );
      }
      storeAsync.whenData(_hydrate);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar negocio' : 'Nuevo negocio'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GarraSpacing.lg,
            GarraSpacing.md,
            GarraSpacing.lg,
            GarraSpacing.section,
          ),
          children: [
            GarraFormSection(
              title: 'NEGOCIO',
              children: [
                GarraTextField(
                  label: 'Nombre del negocio',
                  controller: _nameController,
                  fieldKey: const Key('store-form-name'),
                  maxLength: 120,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el nombre del negocio';
                    }
                    return null;
                  },
                ),
                GarraTextArea(
                  label: 'Descripci\u00f3n',
                  controller: _descriptionController,
                  minLines: 3,
                ),
                GarraTextField(
                  label: 'Ciudad',
                  controller: _cityController,
                  fieldKey: const Key('store-form-city'),
                  maxLength: 80,
                ),
              ],
            ),
            const SizedBox(height: GarraSpacing.xxl),
            GarraPrimaryButton(
              key: const Key('store-form-save'),
              label: widget.isEditing ? 'Guardar' : 'Crear negocio',
              loading: _loading,
              onPressed: _loading ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
