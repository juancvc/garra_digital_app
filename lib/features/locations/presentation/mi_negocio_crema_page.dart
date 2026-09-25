import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/design/garra_spacing.dart';
import '../data/crema_business_application_service.dart';

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
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Mi Negocio Crema'),
        backgroundColor: const Color(GarraColors.charcoal),
      ),
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(GarraColors.gold)),
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
              separatorBuilder: (_, __) =>
                  const SizedBox(height: GarraSpacing.md),
              itemBuilder: (context, i) {
                final item = _items[i];
                return Material(
                  color: const Color(GarraColors.surface),
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
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              '✓ Verificado por Garra',
                              style: TextStyle(
                                color: Color(GarraColors.gold),
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
  const RegistrarNegocioCremaPage({super.key, this.existing});

  final CremaBusinessApplication? existing;

  @override
  State<RegistrarNegocioCremaPage> createState() =>
      _RegistrarNegocioCremaPageState();
}

class _RegistrarNegocioCremaPageState extends State<RegistrarNegocioCremaPage> {
  final _service = CremaBusinessApplicationService();
  final _name = TextEditingController();
  final _category = TextEditingController(text: 'Comida');
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _instagram = TextEditingController();
  double _lat = -12.0553;
  double _lng = -77.0379;
  bool _authorized = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.businessName;
      _category.text = e.category;
      _description.text = e.description ?? '';
      _address.text = e.address;
      _phone.text = e.phone ?? '';
      _whatsapp.text = e.whatsapp ?? '';
      _instagram.text = e.instagram ?? '';
      _lat = e.latitude;
      _lng = e.longitude;
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
    'instagram': _instagram.text.trim().isEmpty ? null : _instagram.text.trim(),
  };

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y ciudad son obligatorios')),
      );
      return;
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
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Registrar mi negocio'),
        backgroundColor: const Color(GarraColors.charcoal),
      ),
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
              GarraTextField(label: 'Categoría', controller: _category),
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
              GarraTextField(label: 'Ciudad', controller: _address),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await context.push<Map<String, double>>(
                      '/negocios/mi-negocio/ubicacion',
                      extra: {'lat': _lat, 'lng': _lng},
                    );
                    if (picked != null) {
                      setState(() {
                        _lat = picked['lat'] ?? _lat;
                        _lng = picked['lng'] ?? _lng;
                      });
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Elegir en mapa'),
                ),
              ),
            ],
          ),
          GarraFormSection(
            title: 'CONTACTO',
            children: [
              GarraTextField(
                label: 'WhatsApp',
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
              ),
              GarraTextField(
                label: 'Teléfono',
                controller: _phone,
                keyboardType: TextInputType.phone,
              ),
              GarraTextField(label: 'Instagram', controller: _instagram),
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
