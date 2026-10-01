import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/design/garra_spacing.dart';
import '../data/crema_business_application_service.dart';
import '../data/business_social_links.dart';

class MiNegocioCremaPage extends StatefulWidget {
  const MiNegocioCremaPage({super.key});

  @override
  State<MiNegocioCremaPage> createState() => _MiNegocioCremaPageState();
}

class _MiNegocioCremaPageState extends State<MiNegocioCremaPage> {
  final _service = CremaBusinessApplicationService();
  List<CremaBusinessApplication> _items = const [];
  bool _loading = true;
  String? _error;

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
      final items = await _service.listMine();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos cargar tus solicitudes';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Negocio Crema')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await context.push<bool>('/negocios/mi-negocio/nuevo');
          if (ok == true) _load();
        },
        backgroundColor: const Color(GarraColors.garnet),
        foregroundColor: const Color(GarraColors.cream),
        label: const Text('Registrar mi negocio'),
        icon: const Icon(Icons.add_business_outlined),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: context.garraColors.brandPrestige,
              ),
            )
          : _error != null
          ? Center(child: Text(_error!))
          : _items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(GarraSpacing.xl),
              child: Text(
                '¿Tienes un negocio?\nRegístralo para aparecer en Puntos Crema tras revisión de Garra.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              itemCount: _items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: GarraSpacing.md),
              itemBuilder: (context, i) {
                final item = _items[i];
                return Material(
                  color: context.garraColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(GarraSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.businessName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(item.status.label),
                        if (item.status ==
                            CremaBusinessApplicationStatus.verified)
                          Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              '✓ Verificado por Garra',
                              style: TextStyle(
                                color: context.garraColors.brandPrestige,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (item.rejectionReason != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.rejectionReason!,
                            style: const TextStyle(
                              color: Color(GarraColors.danger),
                            ),
                          ),
                        ],
                        if (item.status ==
                                CremaBusinessApplicationStatus.rejected ||
                            item.status == CremaBusinessApplicationStatus.draft)
                          TextButton(
                            onPressed: () async {
                              await context.push(
                                '/negocios/mi-negocio/nuevo',
                                extra: item,
                              );
                              _load();
                            },
                            child: const Text('Corregir / reenviar'),
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

class RegistrarNegocioCremaPage extends StatefulWidget {
  const RegistrarNegocioCremaPage({
    super.key,
    this.existing,
    this.categoryService,
  });

  final CremaBusinessApplication? existing;
  final CremaBusinessApplicationService? categoryService;

  @override
  State<RegistrarNegocioCremaPage> createState() =>
      _RegistrarNegocioCremaPageState();
}

class _RegistrarNegocioCremaPageState extends State<RegistrarNegocioCremaPage> {
  late final CremaBusinessApplicationService _service =
      widget.categoryService ?? CremaBusinessApplicationService();
  List<String> _categories = const [];
  bool _loadingCategories = true;
  String? _categoryError;
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _tiktok = TextEditingController();
  double _lat = -12.0553;
  double _lng = -77.0379;
  bool _authorized = false;
  bool _submitting = false;
  bool _locationSelected = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.businessName;
      _category.text = e.category;
      _description.text = e.description ?? '';
      _address.text = e.address;
      _phone.text = e.phone ?? '';
      _whatsapp.text = e.whatsapp ?? '';
      _instagram.text = e.instagram ?? '';
      _facebook.text = e.facebook ?? '';
      _tiktok.text = e.tiktok ?? '';
      _lat = e.latitude;
      _lng = e.longitude;
      _locationSelected = true;
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });
    try {
      final categories = await _service.listCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _categoryError = 'No pudimos cargar las categorías';
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _address.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _instagram.dispose();
    _facebook.dispose();
    _tiktok.dispose();
    super.dispose();
  }

  Map<String, dynamic> _body() => {
    'businessName': _name.text.trim(),
    'category': _category.text.trim(),
    'description': _description.text.trim().isEmpty
        ? null
        : _description.text.trim(),
    'address': _address.text.trim(),
    'latitude': _lat,
    'longitude': _lng,
    'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    'whatsapp': _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
    'instagram': businessSocialUri(
      BusinessSocialNetwork.instagram,
      _instagram.text,
    )?.toString(),
    'facebook': businessSocialUri(
      BusinessSocialNetwork.facebook,
      _facebook.text,
    )?.toString(),
    'tiktok': businessSocialUri(
      BusinessSocialNetwork.tiktok,
      _tiktok.text,
    )?.toString(),
  };

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        _category.text.trim().isEmpty ||
        !_locationSelected ||
        (!_categories.contains(_category.text.trim()) &&
            _category.text.trim() != widget.existing?.category)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa nombre, categoría y ubicación en el mapa'),
        ),
      );
      return;
    }
    for (final entry in <(BusinessSocialNetwork, String)>[
      (BusinessSocialNetwork.instagram, _instagram.text),
      (BusinessSocialNetwork.facebook, _facebook.text),
      (BusinessSocialNetwork.tiktok, _tiktok.text),
    ]) {
      if (entry.$2.trim().isNotEmpty &&
          businessSocialUri(entry.$1, entry.$2) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Revisa el usuario o enlace de ${socialNetworkLabel(entry.$1)}',
            ),
          ),
        );
        return;
      }
    }
    if (!_authorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirma que puedes registrar este negocio'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      CremaBusinessApplication app;
      final existing = widget.existing;
      if (existing != null) {
        app = await _service.update(existing.id, _body());
      } else {
        app = await _service.create(_body());
      }
      app = await _service.submit(app.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada a revisión')),
      );
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos enviar la solicitud')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar mi negocio')),
      resizeToAvoidBottomInset: true,
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.md,
          GarraSpacing.lg,
          GarraSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          const GarraFormIntro(
            title: 'Registrar negocio crema',
            subtitle:
                'Un negocio registrado en el directorio. El Marketplace sigue siendo el lugar de los anuncios.',
          ),
          GarraFormSection(
            title: 'TU NEGOCIO',
            children: [
              GarraTextField(label: 'Nombre', controller: _name),
              if (_loadingCategories) const LinearProgressIndicator(),
              if (_categoryError != null)
                Row(
                  children: [
                    Expanded(child: Text(_categoryError!)),
                    TextButton(
                      onPressed: _loadCategories,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              DropdownMenu<String>(
                controller: _category,
                enabled: _categories.isNotEmpty || widget.existing != null,
                label: const Text('Categoría'),
                enableFilter: true,
                enableSearch: true,
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries:
                    {
                          ..._categories,
                          if (widget.existing != null &&
                              !_categories.contains(widget.existing!.category))
                            widget.existing!.category,
                        }
                        .map(
                          (value) =>
                              DropdownMenuEntry(value: value, label: value),
                        )
                        .toList(),
              ),
              GarraTextArea(
                label: 'Descripción',
                controller: _description,
                minLines: 3,
              ),
            ],
          ),
          GarraFormSection(
            title: 'UBICACIÓN',
            children: [
              TextField(
                controller: _address,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Ubicación seleccionada',
                  hintText: 'Elige un punto en el mapa',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await context.push<Map<String, dynamic>>(
                      '/negocios/mi-negocio/ubicacion',
                      extra: {'lat': _lat, 'lng': _lng},
                    );
                    if (picked != null) {
                      setState(() {
                        _lat = picked['lat'] ?? _lat;
                        _lng = picked['lng'] ?? _lng;
                        _address.text =
                            picked['label']?.toString() ??
                            'Zona seleccionada en mapa';
                        _locationSelected = true;
                      });
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    _locationSelected
                        ? 'Cambiar ubicación'
                        : 'Elegir ubicación en mapa',
                  ),
                ),
              ),
            ],
          ),
          GarraFormSection(
            title: 'CONTACTO',
            children: [
              GarraTextField(
                label: 'Teléfono',
                controller: _phone,
                keyboardType: TextInputType.phone,
              ),
              GarraTextField(
                label: 'WhatsApp (si es diferente)',
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
              ),
              const Text('Redes sociales · opcional'),
              GarraTextField(
                label: 'Instagram · @usuario o URL',
                controller: _instagram,
              ),
              GarraTextField(
                label: 'Facebook · usuario o URL',
                controller: _facebook,
              ),
              GarraTextField(
                label: 'TikTok · @usuario o URL',
                controller: _tiktok,
              ),
            ],
          ),
          GarraFormSection(
            title: 'LEGAL',
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _authorized,
                onChanged: (value) =>
                    setState(() => _authorized = value ?? false),
                title: const Text(
                  'Confirmo que puedo publicar este negocio y que la información es real.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          GarraFormActionBar(
            label: 'Enviar solicitud',
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
