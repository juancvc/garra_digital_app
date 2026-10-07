import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_cached_network_image.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_single_photo_field.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/solidarity_service.dart';
import 'solidaria_shared.dart';

/// Opens an external URI (WhatsApp / phone). Injectable for tests.
typedef SolidarityLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLauncher(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class SolidariaPage extends StatefulWidget {
  const SolidariaPage({super.key, this.service});

  final SolidarityService? service;

  @override
  State<SolidariaPage> createState() => _SolidariaPageState();
}

class _SolidariaPageState extends State<SolidariaPage> {
  late final SolidarityService _service =
      widget.service ?? SolidarityService();
  String? _type;
  List<SolidarityCampaign> _items = [];
  bool _loading = true;
  Object? _error;
  int _request = 0;

  static const _filters = <(String?, String)>[
    (null, 'Todas'),
    ('BLOOD', 'Sangre'),
    ('FOOD', 'Alimentos'),
    ('SCHOOL_SUPPLIES', '\u00datiles'),
    ('VOLUNTEER', 'Voluntariado'),
    ('EMERGENCY', 'Emergencia'),
    ('OTHER', 'Otras'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    final request = ++_request;
    setState(() {
      if (!refresh) _loading = true;
      _error = null;
    });
    try {
      final items = await _service.listPublic(type: _type);
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _selectType(String? type) {
    setState(() => _type = type);
    _load();
  }

  Future<void> _propose() async {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final ok = await router.push<bool>('/solidaria/nueva');
    if (ok == true && mounted) _load(refresh: true);
  }

  void _openMine() => GoRouter.maybeOf(context)?.push('/solidaria/mias');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Garra Solidaria')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('solidaria_propose_fab'),
        onPressed: _propose,
        backgroundColor: context.garraColors.brandPrimary,
        foregroundColor: context.garraColors.onBrand,
        label: const Text('Proponer iniciativa'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: _type == f.$1,
                        onSelected: (_) => _selectType(f.$1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GarraSpacing.lg,
              0,
              GarraSpacing.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Iniciativas de hinchas para ayudar a otros, revisadas por Garra. '
                  'No procesamos dinero.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.garraColors.textSecondary,
                  ),
                ),
                Wrap(
                  spacing: GarraSpacing.sm,
                  children: [
                    TextButton.icon(
                      key: const ValueKey('solidaria_how_it_works_link'),
                      onPressed: () => showSolidariaHowItWorks(context),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('\u00bfC\u00f3mo funciona?'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('solidaria_mine_link'),
                      onPressed: _openMine,
                      icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                      label: const Text('Mis iniciativas'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          GarraErrorState(
            title: 'No pudimos cargar las iniciativas',
            onRetry: _load,
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: _items.isEmpty
          ? ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                if (_type == null)
                  GarraEmptyState(
                    title: 'A\u00fan no hay iniciativas publicadas',
                    message:
                        'Garra Solidaria conecta a la comunidad para apoyar iniciativas '
                        'y casos que necesitan ayuda. Prop\u00f3n una: Garra la revisa y, '
                        'si la aprueba, aparece aqu\u00ed para que otros hinchas te contacten.',
                    hint: 'No procesamos dinero, donaciones ni pagos.',
                    actionLabel: 'Proponer iniciativa',
                    onAction: _propose,
                  )
                else
                  GarraEmptyState(
                    title: 'No hay iniciativas de este tipo',
                    message:
                        'Prueba con otra categor\u00eda o mira todas las iniciativas publicadas.',
                    actionLabel: 'Ver todas',
                    onAction: () => _selectType(null),
                  ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _items.length,
              itemBuilder: (_, i) => _PublicCard(campaign: _items[i]),
            ),
    );
  }
}

class _PublicCard extends StatelessWidget {
  const _PublicCard({required this.campaign});

  final SolidarityCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GarraCard(
        key: ValueKey('solidarity_card_${c.id}'),
        onTap: () => GoRouter.maybeOf(context)?.push('/solidaria/${c.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.evidenceImageUrl != null &&
                c.evidenceImageUrl!.isNotEmpty) ...[
              ClipRRect(
                key: ValueKey('solidarity_photo_${c.id}'),
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: GarraCachedNetworkImage(
                    imageUrl: c.evidenceImageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              solidarityTypeLabel(c.type),
              style: TextStyle(
                color: context.garraColors.brandPrestige,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(c.title, style: Theme.of(context).textTheme.titleMedium),
            Text(
              [c.city, if (c.district != null) c.district!].join(' \u00b7 '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (c.isVerified) ...[
              const SizedBox(height: 8),
              const SolidarityVerifiedChip(),
            ],
          ],
        ),
      ),
    );
  }
}

class SolidariaDetailPage extends StatefulWidget {
  const SolidariaDetailPage({
    super.key,
    required this.campaignId,
    this.service,
    this.launcher,
  });

  final String campaignId;
  final SolidarityService? service;
  final SolidarityLauncher? launcher;

  @override
  State<SolidariaDetailPage> createState() => _SolidariaDetailPageState();
}

class _SolidariaDetailPageState extends State<SolidariaDetailPage> {
  late final SolidarityService _service =
      widget.service ?? SolidarityService();
  SolidarityCampaign? _campaign;
  Object? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final c = await _service.get(widget.campaignId);
      if (!mounted) return;
      setState(() => _campaign = c);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _campaign = null;
        _error = e;
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _launch(Uri uri, String failure) async {
    final launcher = widget.launcher ?? _defaultLauncher;
    var ok = false;
    try {
      ok = await launcher(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) _snack(failure);
  }

  Future<void> _contactWhatsapp() async {
    final wa = _campaign?.contactWhatsapp ?? '';
    final digits = wa.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _snack('Este n\u00famero de WhatsApp no es v\u00e1lido.');
      return;
    }
    await _launch(
      Uri.parse('https://wa.me/$digits'),
      'No pudimos abrir WhatsApp. Escribe al $wa.',
    );
  }

  Future<void> _call() async {
    final phone = _campaign?.contactPhone ?? '';
    final dial = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (dial.isEmpty) {
      _snack('Este tel\u00e9fono no es v\u00e1lido.');
      return;
    }
    await _launch(
      Uri(scheme: 'tel', path: dial),
      'No pudimos abrir el tel\u00e9fono. Llama al $phone.',
    );
  }

  Future<void> _edit(SolidarityCampaign c) async {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final ok = await router.push<bool>('/solidaria/${c.id}/editar');
    if (ok == true && mounted) _load();
  }

  Future<void> _submitDraft(SolidarityCampaign c) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await submitSolidarityForReview(_service, c.id);
      if (!mounted) return;
      _snack('Enviada a revisi\u00f3n. Garra la revisar\u00e1 antes de publicarla.');
      await _load();
    } catch (e) {
      if (mounted) _snack(solidarityActionErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goList() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/solidaria');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _campaign;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciativa'),
        actions: [
          if (c != null && c.isPublic)
            IconButton(
              tooltip: 'Compartir',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => Share.share(
                '${c.title} \u00b7 ${c.city}\nGarra Solidaria \u2014 comunidad independiente de hinchas.',
              ),
            ),
        ],
      ),
      body: _body(context, c),
    );
  }

  Widget _body(BuildContext context, SolidarityCampaign? c) {
    final error = _error;
    if (error != null) {
      if (isSolidarityNotFound(error)) {
        return ListView(
          children: [
            GarraEmptyState(
              title: 'Esta iniciativa no est\u00e1 disponible',
              message:
                  'Puede que todav\u00eda est\u00e9 en revisi\u00f3n o que ya no est\u00e9 publicada.',
              actionLabel: 'Ver Garra Solidaria',
              onAction: _goList,
            ),
          ],
        );
      }
      return ListView(
        children: [
          GarraErrorState(
            title: 'No pudimos cargar la iniciativa',
            onRetry: _load,
          ),
        ],
      );
    }
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final colors = context.garraColors;
    final text = Theme.of(context).textTheme;
    final location = [
      c.city,
      if (c.district != null) c.district!,
    ].join(' \u00b7 ');
    return ListView(
      padding: const EdgeInsets.all(GarraSpacing.lg),
      children: [
        if (c.isPublic) const SolidarityVerifiedChip() else SolidarityStateChip(c),
        if (!c.isPublic) ...[
          const SizedBox(height: GarraSpacing.sm),
          _OwnerStatePanel(
            campaign: c,
            submitting: _submitting,
            onEdit: () => _edit(c),
            onSubmit: () => _submitDraft(c),
          ),
        ],
        const SizedBox(height: 8),
        Text(c.title, style: text.headlineSmall),
        const SizedBox(height: 4),
        Text(
          solidarityTypeLabel(c.type),
          style: text.labelLarge?.copyWith(color: colors.brandPrestige),
        ),
        const SizedBox(height: 8),
        Text(c.description),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.place_outlined, size: 18, color: colors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                c.address == null ? location : '$location\n${c.address}',
              ),
            ),
          ],
        ),
        if (c.isPublic && c.createdByUsername != null) ...[
          const SizedBox(height: 6),
          Text(
            'Publicada por @${c.createdByUsername}',
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
        if (c.evidenceImageUrl != null && c.evidenceImageUrl!.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            key: const ValueKey('solidarity_detail_photo'),
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: GarraCachedNetworkImage(
                imageUrl: c.evidenceImageUrl!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
        if (c.isPublic) ...[
          const SizedBox(height: 20),
          Text(
            'C\u00d3MO AYUDAR',
            key: const ValueKey('solidarity_how_to_help'),
            style: text.labelLarge?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            c.hasContactChannel
                ? 'Coordina directamente con ${c.contactName ?? 'quien publica'}.'
                : 'Esta iniciativa no tiene un contacto publicado.',
          ),
          const SizedBox(height: 12),
          if (c.contactWhatsapp != null)
            GarraPrimaryButton(
              label: 'Contactar por WhatsApp',
              onPressed: _contactWhatsapp,
            ),
          if (c.contactPhone != null) ...[
            const SizedBox(height: 8),
            GarraSecondaryButton(
              label: 'Llamar',
              onPressed: _call,
            ),
          ],
        ],
        const SizedBox(height: 12),
        Text(
          'Garra no procesa dinero ni pagos. Coordina directamente con '
          'quien publica la iniciativa y cuida tus datos personales.',
          style: text.bodySmall?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Owner/staff view of a non-public campaign: what its state means and the
/// only actions the backend accepts (edit + resubmit for drafts/rejected).
class _OwnerStatePanel extends StatelessWidget {
  const _OwnerStatePanel({
    required this.campaign,
    required this.submitting,
    required this.onEdit,
    required this.onSubmit,
  });

  final SolidarityCampaign campaign;
  final bool submitting;
  final VoidCallback onEdit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final text = Theme.of(context).textTheme;
    final state = campaign.ownerState;
    final reason = state == SolidarityOwnerState.rejected
        ? campaign.rejectionReason
        : null;
    return GarraCard(
      key: const ValueKey('solidarity_owner_panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(solidarityStateDescription(state), style: text.bodyMedium),
          if (reason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo de Garra: $reason',
              key: const ValueKey('solidarity_rejection_reason'),
              style: text.bodyMedium?.copyWith(color: colors.danger),
            ),
          ],
          if (campaign.canEdit) ...[
            const SizedBox(height: 12),
            GarraPrimaryButton(
              label: state == SolidarityOwnerState.rejected
                  ? 'Corregir y reenviar'
                  : 'Editar',
              onPressed: submitting ? null : onEdit,
            ),
            if (state == SolidarityOwnerState.draft) ...[
              const SizedBox(height: 8),
              GarraSecondaryButton(
                label: 'Enviar a revisi\u00f3n',
                onPressed: submitting ? null : onSubmit,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Submits for review. A lost response followed by a retry answers
/// "Already pending review": the campaign IS in review, so that is success.
Future<void> submitSolidarityForReview(
  SolidarityService service,
  String id,
) async {
  try {
    await service.submit(id);
  } on DioException catch (e) {
    final data = e.response?.data;
    final message = data is Map ? data['message']?.toString() ?? '' : '';
    if (message.toLowerCase().contains('already pending review')) return;
    rethrow;
  }
}

class SolidariaCreatePage extends StatefulWidget {
  const SolidariaCreatePage({
    super.key,
    this.service,
    this.media,
    this.campaignId,
  });

  final SolidarityService? service;
  final MediaUploadService? media;

  /// When set, edits an owned draft/rejected campaign and resubmits it.
  final String? campaignId;

  @override
  State<SolidariaCreatePage> createState() => _SolidariaCreatePageState();
}

class _SolidariaCreatePageState extends State<SolidariaCreatePage> {
  late final SolidarityService _service =
      widget.service ?? SolidarityService();
  late final MediaUploadService _media = widget.media ?? MediaUploadService();
  final _formKey = GlobalKey<FormState>();
  XFile? _photo;
  XFile? _uploadedPhoto;
  String? _uploadedAssetId;
  String? _savedPhotoUrl;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _contact = TextEditingController();
  final _whatsapp = TextEditingController();
  final _phone = TextEditingController();
  String _type = 'OTHER';
  bool _busy = false;
  String? _error;

  /// Id of the draft this form writes to: the edited campaign, or the draft
  /// created by a previous attempt whose submit failed (no duplicates).
  String? _campaignId;
  bool _loadingExisting = false;
  Object? _loadError;
  SolidarityCampaign? _existing;

  bool get _editing => widget.campaignId != null;

  @override
  void initState() {
    super.initState();
    _campaignId = widget.campaignId;
    if (_editing) _loadExisting();
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _city,
      _district,
      _contact,
      _whatsapp,
      _phone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() {
      _loadingExisting = true;
      _loadError = null;
    });
    try {
      final c = await _service.get(widget.campaignId!);
      if (!mounted) return;
      setState(() {
        _existing = c;
        _loadingExisting = false;
        _title.text = c.title;
        _description.text = c.description;
        _type = const {
          'BLOOD',
          'FOOD',
          'SCHOOL_SUPPLIES',
          'VOLUNTEER',
          'EMERGENCY',
          'OTHER',
        }.contains(c.type)
            ? c.type
            : 'OTHER';
        _city.text = c.city;
        _district.text = c.district ?? '';
        _contact.text = c.contactName ?? '';
        _whatsapp.text = c.contactWhatsapp ?? '';
        _phone.text = c.contactPhone ?? '';
        _savedPhotoUrl = c.evidenceImageUrl;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingExisting = false;
        _loadError = e;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _media.pickImage();
    if (file == null || !mounted) return;
    setState(() => _photo = file);
  }

  void _removePhoto() {
    if (_photo != null) {
      setState(() => _photo = null);
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'La foto ya enviada no se puede quitar; puedes cambiarla por otra.',
        ),
      ),
    );
  }

  String? _requiredText(String? value, String what, int max) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Completa $what.';
    if (t.length > max) return 'M\u00e1ximo $max caracteres.';
    return null;
  }

  static int _digits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '').length;

  String? _validateWhatsapp(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) {
      return _phone.text.trim().isEmpty
          ? 'Agrega un WhatsApp o un tel\u00e9fono para que puedan ayudarte.'
          : null;
    }
    if (t.length > 40 || _digits(t) < 8 || _digits(t) > 15) {
      return 'Ingresa un n\u00famero v\u00e1lido con c\u00f3digo de pa\u00eds (ej. 51987654321).';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t.length > 40 || _digits(t) < 6 || _digits(t) > 15) {
      return 'Ingresa un tel\u00e9fono v\u00e1lido.';
    }
    return null;
  }

  String? _optional(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = 'Revisa los campos marcados.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? evidenceAssetId;
      final photo = _photo;
      if (photo != null) {
        if (identical(photo, _uploadedPhoto) && _uploadedAssetId != null) {
          evidenceAssetId = _uploadedAssetId;
        } else {
          evidenceAssetId = await uploadSinglePhoto(
            _media,
            photo,
            MediaUploadPurpose.solidarity,
            canStartRemote: () => mounted && allowNetworkAction(context),
          );
          _uploadedPhoto = photo;
          _uploadedAssetId = evidenceAssetId;
        }
      }
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'type': _type,
        'city': _city.text.trim(),
        'district': _optional(_district),
        'contactName': _contact.text.trim(),
        'contactWhatsapp': _optional(_whatsapp),
        'contactPhone': _optional(_phone),
        'evidenceMediaAssetId': ?evidenceAssetId,
      };
      final existingId = _campaignId;
      if (existingId == null) {
        final created = await _service.create(body);
        _campaignId = created.id;
      } else {
        await _service.update(existingId, body);
      }
      await submitSolidarityForReview(_service, _campaignId!);
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text(
            'Enviada a revisi\u00f3n. Garra la revisar\u00e1 antes de publicarla.',
          ),
          action: router == null
              ? null
              : SnackBarAction(
                  label: 'Mis iniciativas',
                  onPressed: () => router.go('/solidaria/mias'),
                ),
        ),
      );
      if (router == null) {
        Navigator.of(context).maybePop(true);
      } else if (router.canPop()) {
        router.pop(true);
      } else {
        // Opened directly (deep link): land where the state is visible.
        router.go('/solidaria/mias');
      }
    } on SinglePhotoUploadException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = solidarityActionErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_editing ? 'Corregir iniciativa' : 'Nueva iniciativa'),
        actions: [
          IconButton(
            tooltip: '\u00bfC\u00f3mo funciona?',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showSolidariaHowItWorks(context),
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loadingExisting) {
      return const Center(child: CircularProgressIndicator());
    }
    final loadError = _loadError;
    if (loadError != null) {
      return ListView(
        children: [
          isSolidarityNotFound(loadError)
              ? const GarraEmptyState(
                  title: 'Esta iniciativa no est\u00e1 disponible',
                  message: 'Puede que ya no exista o que no sea tuya.',
                )
              : GarraErrorState(
                  title: 'No pudimos cargar la iniciativa',
                  onRetry: _loadExisting,
                ),
        ],
      );
    }
    final existing = _existing;
    if (existing != null && !existing.canEdit) {
      return ListView(
        children: [
          GarraEmptyState(
            title: 'Esta iniciativa ya no se puede editar',
            message: solidarityStateDescription(existing.ownerState),
          ),
        ],
      );
    }
    final colors = context.garraColors;
    final rejection = existing?.ownerState == SolidarityOwnerState.rejected
        ? existing?.rejectionReason
        : null;
    return Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          GarraSpacing.lg,
          GarraSpacing.md,
          GarraSpacing.lg,
          GarraSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          GarraFormIntro(
            title: _editing ? 'Corrige tu iniciativa' : 'Solicitud solidaria',
            subtitle: _editing
                ? 'Ajusta los datos y vuelve a enviarla a revisi\u00f3n.'
                : 'Cu\u00e9ntanos brevemente qu\u00e9 apoyo necesitas.',
          ),
          if (rejection != null)
            Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.md),
              child: Text(
                'Motivo de Garra: $rejection',
                key: const ValueKey('solidarity_edit_rejection_reason'),
                style: TextStyle(color: colors.danger),
              ),
            ),
          if (!_editing)
            Padding(
              padding: const EdgeInsets.only(bottom: GarraSpacing.md),
              child: Text(
                'Garra revisa cada iniciativa antes de publicarla. Mientras tanto '
                'podr\u00e1s seguir su estado en \u201cMis iniciativas\u201d.',
                key: const ValueKey('solidarity_create_review_note'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          GarraFormSection(
            title: 'TIPO',
            children: [
              GarraSelectField<String>(
                label: 'Tipo',
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'BLOOD', child: Text('Sangre')),
                  DropdownMenuItem(value: 'FOOD', child: Text('Alimentos')),
                  DropdownMenuItem(
                    value: 'SCHOOL_SUPPLIES',
                    child: Text('\u00datiles'),
                  ),
                  DropdownMenuItem(
                    value: 'VOLUNTEER',
                    child: Text('Voluntariado'),
                  ),
                  DropdownMenuItem(
                    value: 'EMERGENCY',
                    child: Text('Emergencia'),
                  ),
                  DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'OTHER'),
              ),
            ],
          ),
          GarraFormSection(
            title: 'DETALLE',
            children: [
              GarraTextField(
                label: 'T\u00edtulo',
                controller: _title,
                fieldKey: const ValueKey('solidarity_title'),
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => _requiredText(v, 'el t\u00edtulo', 160),
              ),
              KeyedSubtree(
                key: const ValueKey('solidarity_description'),
                child: GarraTextArea(
                  label: 'Descripci\u00f3n',
                  controller: _description,
                  minLines: 4,
                  maxLength: 2000,
                  helper:
                      'Qu\u00e9 se necesita, para qui\u00e9n y hasta cu\u00e1ndo.',
                  validator: (v) =>
                      _requiredText(v, 'la descripci\u00f3n', 2000),
                ),
              ),
              GarraSinglePhotoField(
                key: const ValueKey('solidarity_photo_field'),
                file: _photo,
                currentUrl: _photo == null ? _savedPhotoUrl : null,
                enabled: !_busy,
                onPick: _pickPhoto,
                onRemove: _removePhoto,
              ),
            ],
          ),
          GarraFormSection(
            title: 'UBICACI\u00d3N Y CONTACTO',
            children: [
              GarraTextField(
                label: 'Ciudad',
                controller: _city,
                fieldKey: const ValueKey('solidarity_city'),
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                validator: (v) => _requiredText(v, 'la ciudad', 80),
              ),
              GarraTextField(
                label: 'Distrito (opcional)',
                controller: _district,
                fieldKey: const ValueKey('solidarity_district'),
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
              ),
              GarraTextField(
                label: 'Nombre de contacto',
                controller: _contact,
                fieldKey: const ValueKey('solidarity_contact'),
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                helper:
                    'Se mostrar\u00e1 con tu WhatsApp o tel\u00e9fono cuando Garra apruebe la iniciativa.',
                validator: (v) =>
                    _requiredText(v, 'el nombre de contacto', 120),
              ),
              GarraTextField(
                label: 'WhatsApp',
                controller: _whatsapp,
                fieldKey: const ValueKey('solidarity_whatsapp'),
                keyboardType: TextInputType.phone,
                helper: 'Con c\u00f3digo de pa\u00eds, ej. 51987654321.',
                validator: _validateWhatsapp,
              ),
              GarraTextField(
                label: 'Tel\u00e9fono (opcional)',
                controller: _phone,
                fieldKey: const ValueKey('solidarity_phone'),
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                key: const ValueKey('solidarity_form_error'),
                style: TextStyle(color: colors.danger),
              ),
            ),
          GarraFormActionBar(
            label: _editing ? 'Reenviar a revisi\u00f3n' : 'Enviar a revisi\u00f3n',
            loading: _busy,
            onPressed: _submit,
            footnote:
                'No procesamos dinero. Garra solo facilita el contacto entre hinchas.',
          ),
        ],
      ),
    );
  }
}
