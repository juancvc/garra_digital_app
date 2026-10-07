import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_cached_network_image.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/crema_business_application_service.dart';
import '../data/business_social_links.dart';

/// SONIC_01: "Mis negocios". Approved businesses (verified, with their Crema
/// point) live in "Negocios activos" and open the owner's business page;
/// drafts, pending and rejected applications live in "Solicitudes".
class MiNegocioCremaPage extends StatefulWidget {
  const MiNegocioCremaPage({super.key, this.service});

  final CremaBusinessApplicationService? service;

  @override
  State<MiNegocioCremaPage> createState() => _MiNegocioCremaPageState();
}

class _MiNegocioCremaPageState extends State<MiNegocioCremaPage> {
  late final CremaBusinessApplicationService _service =
      widget.service ?? CremaBusinessApplicationService();
  List<CremaBusinessApplication> _items = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _failed = false;
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
        _failed = true;
      });
    }
  }

  Future<void> _register([CremaBusinessApplication? existing]) async {
    final ok = await context.push<bool>(
      '/negocios/mi-negocio/nuevo',
      extra: existing,
    );
    if (ok == true || existing != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = _items.where((a) => a.isApprovedBusiness).toList();
    final requests = _items.where((a) => !a.isApprovedBusiness).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Mis negocios')),
      floatingActionButton: _loading || (_failed && _items.isEmpty)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _register(),
              backgroundColor: const Color(GarraColors.garnet),
              foregroundColor: const Color(GarraColors.cream),
              label: const Text('Registrar negocio'),
              icon: const Icon(Icons.add_business_outlined),
            ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: context.garraColors.brandPrestige,
              ),
            )
          : _failed && _items.isEmpty
          ? GarraErrorState(
              title: 'No pudimos cargar tus negocios',
              onRetry: _load,
            )
          : _items.isEmpty
          ? GarraEmptyState(
              title: '¿Tienes un negocio?',
              message:
                  'Regístralo para aparecer en Negocios Crema tras la revisión de Garra.',
              hint:
                  'Sin negocio verificado no puedes publicar ofertas ni aparecer en el mapa.',
              actionLabel: 'Registrar mi negocio',
              onAction: () => _register(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  GarraSpacing.lg,
                  GarraSpacing.lg,
                  GarraSpacing.lg,
                  96,
                ),
                children: [
                  if (_failed)
                    const Padding(
                      padding: EdgeInsets.only(bottom: GarraSpacing.md),
                      child: Text(
                        'No pudimos actualizar · mostramos lo anterior',
                      ),
                    ),
                  if (active.isNotEmpty) ...[
                    const _SectionTitle('NEGOCIOS ACTIVOS'),
                    for (final item in active)
                      _ActiveBusinessCard(
                        item: item,
                        onTap: () async {
                          await context.push(
                            '/negocios/mi-negocio/activo/${item.id}',
                            extra: item,
                          );
                          if (mounted) _load();
                        },
                      ),
                  ],
                  if (requests.isNotEmpty) ...[
                    if (active.isNotEmpty)
                      const SizedBox(height: GarraSpacing.lg),
                    const _SectionTitle('SOLICITUDES'),
                    for (final item in requests)
                      _RequestCard(
                        item: item,
                        onFix: () => _register(item),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: context.garraColors.brandPrestige,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    ),
  );
}

/// "Activo · Verificado por Garra" (or the honest hidden state when Garra
/// paused the point). Shared by the list and the owner business page.
class BusinessOwnerStatusChip extends StatelessWidget {
  const BusinessOwnerStatusChip({super.key, required this.item});
  final CremaBusinessApplication item;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final visible = item.isPubliclyVisible;
    final color = visible ? colors.success : colors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(GarraRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            visible ? Icons.verified_rounded : Icons.visibility_off_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          // Flexible: wraps instead of overflowing on narrow screens / large
          // text scale.
          Flexible(
            child: Text(
              visible
                  ? 'Activo · Verificado por Garra'
                  : 'Verificado · no visible por ahora',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cover photo or a neutral storefront fallback (businesses without photo
/// keep working, e.g. older records).
class BusinessCoverThumb extends StatelessWidget {
  const BusinessCoverThumb({super.key, required this.url, this.size = 56});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final fallback = ColoredBox(
      color: colors.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.storefront_outlined,
          color: colors.textSecondary,
          size: size * 0.5,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(GarraRadius.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: (url ?? '').isEmpty
            ? fallback
            : GarraCachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: fallback,
              ),
      ),
    );
  }
}

class _ActiveBusinessCard extends StatelessWidget {
  const _ActiveBusinessCard({required this.item, required this.onTap});
  final CremaBusinessApplication item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(GarraRadius.sm),
        child: InkWell(
          key: ValueKey('active_business_${item.id}'),
          borderRadius: BorderRadius.circular(GarraRadius.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(GarraSpacing.md),
            child: Row(
              children: [
                BusinessCoverThumb(url: item.coverImageUrl),
                const SizedBox(width: GarraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.businessName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (item.category.isNotEmpty)
                        Text(
                          item.category,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      const SizedBox(height: 6),
                      BusinessOwnerStatusChip(item: item),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item, required this.onFix});
  final CremaBusinessApplication item;
  final VoidCallback onFix;

  String get _hint => switch (item.status) {
    CremaBusinessApplicationStatus.pending =>
      'Garra está revisando tu solicitud. Te avisaremos cuando termine.',
    CremaBusinessApplicationStatus.draft =>
      'Aún no la envías a revisión.',
    CremaBusinessApplicationStatus.rejected =>
      'Corrige los datos y vuelve a enviarla.',
    CremaBusinessApplicationStatus.verified =>
      'Verificado por Garra.',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final rejected = item.status == CremaBusinessApplicationStatus.rejected;
    final canFix = rejected || item.status == CremaBusinessApplicationStatus.draft;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(GarraRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(GarraSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.businessName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    item.status == CremaBusinessApplicationStatus.rejected
                        ? 'Rechazada'
                        : item.status.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: rejected ? colors.danger : colors.brandPrestige,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_hint, style: TextStyle(color: colors.textSecondary)),
              if (rejected && (item.rejectionReason ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Motivo: ${item.rejectionReason!.trim()}',
                  style: TextStyle(color: colors.danger),
                ),
              ],
              if (canFix)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onFix,
                    child: Text(rejected ? 'Corregir y reenviar' : 'Completar y enviar'),
                  ),
                ),
            ],
          ),
        ),
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
