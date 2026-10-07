import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_single_photo_field.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/crema_business_engagement_service.dart';
import '../data/crema_business_offer_models.dart';

/// DEMO_HARDENING_02: owner create (DRAFT) + optional publish. Fields match UpsertCremaBusinessOfferRequest.
class CreateBusinessOfferPage extends StatefulWidget {
  const CreateBusinessOfferPage({
    super.key,
    required this.pointId,
    required this.businessName,
    this.engagement,
    this.media,
    this.initial,
  });

  final String pointId;
  final String businessName;
  final CremaBusinessEngagementService? engagement;
  final MediaUploadService? media;
  final CremaBusinessOffer? initial;

  @override
  State<CreateBusinessOfferPage> createState() => _CreateBusinessOfferPageState();
}

class _CreateBusinessOfferPageState extends State<CreateBusinessOfferPage> {
  late final CremaBusinessEngagementService _service =
      widget.engagement ?? CremaBusinessEngagementService();
  MediaUploadService? _mediaInstance;
  MediaUploadService get _media =>
      _mediaInstance ??= widget.media ?? MediaUploadService();

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime? _startsAt;
  DateTime? _endsAt;
  XFile? _photo;
  bool _submitting = false;
  bool _publishAfter = true;

  bool get _editingDraft =>
      widget.initial != null && widget.initial!.isDraft;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _title.text = initial.title;
      _description.text = initial.description;
      _startsAt = initial.startsAt?.toLocal();
      _endsAt = initial.endsAt?.toLocal();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _req(String? v, {int max = 160}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Completa este campo';
    if (t.length > max) return 'Máximo $max caracteres';
    return null;
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final initial = start
        ? (_startsAt ?? now)
        : (_endsAt ?? _startsAt ?? now.add(const Duration(days: 7)));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startsAt = value;
      } else {
        _endsAt = value;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startsAt != null && _endsAt != null && _endsAt!.isBefore(_startsAt!)) {
      _snack('La vigencia debe terminar después de iniciar');
      return;
    }
    if (!allowNetworkAction(context)) return;
    setState(() => _submitting = true);
    try {
      String? mediaAssetId;
      final photo = _photo;
      if (photo != null) {
        try {
          mediaAssetId = await uploadSinglePhoto(
            _media,
            photo,
            MediaUploadPurpose.businessMedia,
            canStartRemote: () => mounted && allowNetworkAction(context),
          );
        } on SinglePhotoUploadException catch (e) {
          if (mounted) _snack(e.message);
          return;
        }
      }

      CremaBusinessOffer offer;
      if (_editingDraft) {
        offer = await _service.updateDraftOffer(
          offerId: widget.initial!.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          startsAt: _startsAt?.toUtc(),
          endsAt: _endsAt?.toUtc(),
          mediaAssetId: mediaAssetId,
        );
      } else {
        offer = await _service.createOffer(
          pointId: widget.pointId,
          title: _title.text.trim(),
          description: _description.text.trim(),
          startsAt: _startsAt?.toUtc(),
          endsAt: _endsAt?.toUtc(),
          mediaAssetId: mediaAssetId,
        );
      }

      if (_publishAfter && offer.isDraft) {
        offer = await _service.publishOffer(offer.id);
      }
      if (!mounted) return;
      _snack(offer.isActive ? 'Oferta publicada' : 'Borrador guardado');
      Navigator.of(context).pop(offer);
    } catch (_) {
      if (mounted) {
        _snack('No pudimos guardar la oferta. Revisa los datos e inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingDraft ? 'Editar borrador' : 'Crear oferta'),
      ),
      resizeToAvoidBottomInset: true,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GarraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(
              widget.businessName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.garraColors.brandPrestige,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: GarraSpacing.md),
            GarraTextField(
              controller: _title,
              label: 'Título',
              maxLength: 160,
              validator: (v) => _req(v, max: 160),
            ),
            const SizedBox(height: GarraSpacing.md),
            GarraTextArea(
              controller: _description,
              label: 'Descripción / beneficio',
              maxLength: 2000,
              minLines: 4,
              validator: (v) => _req(v, max: 2000),
            ),
            const SizedBox(height: GarraSpacing.lg),
            Text('VIGENCIA (opcional)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: GarraSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('offer_starts_at'),
                    onPressed: _submitting ? null : () => _pickDate(start: true),
                    child: Text(_startsAt == null
                        ? 'Inicio'
                        : _fmt(_startsAt)),
                  ),
                ),
                const SizedBox(width: GarraSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('offer_ends_at'),
                    onPressed: _submitting ? null : () => _pickDate(start: false),
                    child: Text(
                        _endsAt == null ? 'Fin' : _fmt(_endsAt)),
                  ),
                ),
              ],
            ),
            if (_startsAt != null || _endsAt != null)
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _startsAt = null;
                          _endsAt = null;
                        }),
                child: const Text('Quitar vigencia'),
              ),
            const SizedBox(height: GarraSpacing.lg),
            Text('IMAGEN (opcional)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: GarraSpacing.sm),
            GarraSinglePhotoField(
              file: _photo,
              currentUrl: widget.initial?.imageUrl,
              enabled: !_submitting,
              label: 'Foto de la oferta',
              helper: 'Si la carga falla, la oferta se guarda sin imagen.',
              onPick: () async {
                final file = await _media.pickImage();
                if (file == null || !mounted) return;
                setState(() => _photo = file);
              },
              onRemove: () => setState(() => _photo = null),
            ),
            const SizedBox(height: GarraSpacing.md),
            SwitchListTile.adaptive(
              key: const ValueKey('offer_publish_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicar al guardar'),
              subtitle: const Text(
                'Si lo desactivas, queda en borrador hasta que la publiques.',
              ),
              value: _publishAfter,
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _publishAfter = v),
            ),
            const SizedBox(height: GarraSpacing.xl),
            GarraPrimaryButton(
              key: const ValueKey('offer_submit'),
              label: _publishAfter ? 'Publicar oferta' : 'Guardar borrador',
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: GarraSpacing.section),
          ],
          ),
        ),
      ),
    );
  }
}
