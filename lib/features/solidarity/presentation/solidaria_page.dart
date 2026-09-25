import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_form.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/solidarity_service.dart';

class SolidariaPage extends StatefulWidget {
  const SolidariaPage({super.key});

  @override
  State<SolidariaPage> createState() => _SolidariaPageState();
}

class _SolidariaPageState extends State<SolidariaPage> {
  final _service = SolidarityService();
  String? _type;
  List<SolidarityCampaign> _items = [];
  bool _loading = true;

  static const _filters = <(String?, String)>[
    (null, 'Todas'),
    ('BLOOD', 'Sangre'),
    ('FOOD', 'Alimentos'),
    ('VOLUNTEER', 'Voluntariado'),
    ('EMERGENCY', 'Emergencia'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.listPublic(type: _type);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Garra Solidaria')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await context.push<bool>('/solidaria/nueva');
          if (ok == true) _load();
        },
        backgroundColor: const Color(GarraColors.gold),
        foregroundColor: const Color(GarraColors.charcoal),
        label: const Text('Crear solicitud'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _type == f.$1,
                      onSelected: (_) {
                        setState(() => _type = f.$1);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            children: const [
                              GarraEmptyState(
                                title: 'Sin campañas activas',
                                message:
                                    'Cuando Garra verifique una campaña, aparecerá aquí.',
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final c = _items[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GarraCard(
                                  onTap: () =>
                                      context.push('/solidaria/${c.id}'),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.type,
                                        style: const TextStyle(
                                          color: Color(GarraColors.gold),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        c.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        [
                                          c.city,
                                          if (c.district != null) c.district!,
                                        ].join(' · '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      if (c.isVerified) ...[
                                        const SizedBox(height: 8),
                                        const Text(
                                          '✓ Verificado por Garra',
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class SolidariaDetailPage extends StatefulWidget {
  const SolidariaDetailPage({super.key, required this.campaignId});

  final String campaignId;

  @override
  State<SolidariaDetailPage> createState() => _SolidariaDetailPageState();
}

class _SolidariaDetailPageState extends State<SolidariaDetailPage> {
  final _service = SolidarityService();
  SolidarityCampaign? _campaign;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await _service.get(widget.campaignId);
      if (!mounted) return;
      setState(() => _campaign = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar la campaña');
    }
  }

  Future<void> _contact() async {
    final wa = _campaign?.contactWhatsapp;
    if (wa == null || wa.isEmpty) return;
    final digits = wa.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = _campaign;
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Campaña'),
        actions: [
          if (c != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => Share.share(
                '${c.title} · ${c.city}\nGarra Solidaria — comunidad independiente de hinchas.',
              ),
            ),
        ],
      ),
      body: c == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              children: [
                if (c.isVerified)
                  const Text(
                    '✓ Verificado por Garra',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(c.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(c.description),
                const SizedBox(height: 12),
                Text('${c.city}${c.district == null ? '' : ' · ${c.district}'}'),
                if (c.evidenceImageUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(c.evidenceImageUrl!, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 20),
                if (c.contactWhatsapp != null && c.contactWhatsapp!.isNotEmpty)
                  GarraPrimaryButton(
                    label: 'Contactar',
                    onPressed: _contact,
                  ),
              ],
            ),
    );
  }
}

class SolidariaCreatePage extends StatefulWidget {
  const SolidariaCreatePage({super.key});

  @override
  State<SolidariaCreatePage> createState() => _SolidariaCreatePageState();
}

class _SolidariaCreatePageState extends State<SolidariaCreatePage> {
  final _service = SolidarityService();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _contact = TextEditingController();
  final _whatsapp = TextEditingController();
  String _type = 'OTHER';
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await _service.create({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'type': _type,
        'city': _city.text.trim(),
        'contactName': _contact.text.trim(),
        'contactWhatsapp': _whatsapp.text.trim().isEmpty
            ? null
            : _whatsapp.text.trim(),
      });
      await _service.submit(created.id);
      if (!mounted) return;
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo enviar la solicitud');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Solicitud solidaria')),
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
            title: 'Solicitud solidaria',
            subtitle: 'Cuéntanos brevemente qué apoyo necesitas.',
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
                    child: Text('Útiles'),
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
              GarraTextField(label: 'Título', controller: _title),
              GarraTextArea(
                label: 'Descripción',
                controller: _description,
                minLines: 4,
              ),
            ],
          ),
          GarraFormSection(
            title: 'UBICACIÓN Y CONTACTO',
            children: [
              GarraTextField(label: 'Ciudad', controller: _city),
              GarraTextField(label: 'Contacto', controller: _contact),
              GarraTextField(
                label: 'WhatsApp (opcional)',
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          GarraFormActionBar(
            label: 'Enviar a revisión',
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
