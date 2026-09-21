import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/clan_models.dart';
import 'providers/clans_provider.dart';

/// Create a community (backend: clan) with user-facing labels.
class CreateCommunityPage extends ConsumerStatefulWidget {
  const CreateCommunityPage({super.key});

  @override
  ConsumerState<CreateCommunityPage> createState() =>
      _CreateCommunityPageState();
}

class _CreateCommunityPageState extends ConsumerState<CreateCommunityPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String _visibility = 'PUBLIC';
  String _joinPolicy = 'OPEN';
  bool _slugEdited = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  String _slugify(String name) {
    final normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (normalized.length < 3) return normalized;
    return normalized.length > 64 ? normalized.substring(0, 64) : normalized;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final clan = await ref.read(clanServiceProvider).createClan(
            CreateClanRequest(
              name: _nameCtrl.text.trim(),
              slug: _slugCtrl.text.trim(),
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              city: _cityCtrl.text.trim().isEmpty
                  ? null
                  : _cityCtrl.text.trim(),
              countryCode: 'PE',
              visibility: _visibility,
              joinPolicy: _joinPolicy,
            ),
          );
      ref.invalidate(myClansProvider);
      ref.invalidate(clanDiscoveryProvider(const ClanDiscoveryQuery()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comunidad creada')),
      );
      context.go('/clans/${clan.slug}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos crear la comunidad. Revisa los datos.'),
        ),
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
        title: const Text('Crear comunidad'),
        backgroundColor: const Color(GarraColors.charcoal),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(GarraSpacing.lg),
          children: [
            Text(
              'Dale un nombre a tu gente',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(GarraColors.cream),
                  ),
            ),
            const SizedBox(height: GarraSpacing.lg),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                if (!_slugEdited) {
                  _slugCtrl.text = _slugify(value);
                }
              },
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'El nombre es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: GarraSpacing.md),
            TextFormField(
              controller: _slugCtrl,
              decoration: const InputDecoration(
                labelText: 'Identificador (URL)',
                helperText: 'Solo minúsculas, números y guiones',
              ),
              onChanged: (_) => _slugEdited = true,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.length < 3) return 'Mínimo 3 caracteres';
                if (!RegExp(r'^[a-z0-9-]+$').hasMatch(s)) {
                  return 'Solo a-z, 0-9 y guiones';
                }
                return null;
              },
            ),
            const SizedBox(height: GarraSpacing.md),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 3,
            ),
            const SizedBox(height: GarraSpacing.md),
            TextFormField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: 'Ciudad',
                hintText: 'Lima, Arequipa…',
              ),
            ),
            const SizedBox(height: GarraSpacing.xs),
            Text(
              'País: Perú',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: GarraSpacing.xxl),
            Text(
              'Visibilidad',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: GarraSpacing.sm),
            _OptionTile(
              selected: _visibility == 'PUBLIC',
              title: 'Pública',
              subtitle: 'Cualquiera puede encontrar esta comunidad.',
              onTap: () => setState(() => _visibility = 'PUBLIC'),
            ),
            _OptionTile(
              selected: _visibility == 'MEMBERS_ONLY',
              title: 'Solo miembros',
              subtitle: 'Aparece, pero el contenido es para miembros.',
              onTap: () => setState(() => _visibility = 'MEMBERS_ONLY'),
            ),
            _OptionTile(
              selected: _visibility == 'PRIVATE',
              title: 'Privada',
              subtitle: 'Solo miembros e invitados pueden verla.',
              onTap: () => setState(() => _visibility = 'PRIVATE'),
            ),
            const SizedBox(height: GarraSpacing.xxl),
            Text(
              'Ingreso',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: GarraSpacing.sm),
            _OptionTile(
              selected: _joinPolicy == 'OPEN',
              title: 'Abierta',
              subtitle: 'Cualquiera puede unirse al instante.',
              onTap: () => setState(() => _joinPolicy = 'OPEN'),
            ),
            _OptionTile(
              selected: _joinPolicy == 'REQUEST',
              title: 'Solicitud',
              subtitle: 'Los nuevos piden ingreso y un admin aprueba.',
              onTap: () => setState(() => _joinPolicy = 'REQUEST'),
            ),
            _OptionTile(
              selected: _joinPolicy == 'INVITE_ONLY',
              title: 'Solo invitación',
              subtitle: 'Los nuevos miembros necesitan una invitación.',
              onTap: () => setState(() => _joinPolicy = 'INVITE_ONLY'),
            ),
            const SizedBox(height: GarraSpacing.xxl),
            GarraPrimaryButton(
              label: _submitting ? 'Creando…' : 'Crear comunidad',
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: GarraSpacing.section),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
      child: Material(
        color: selected
            ? const Color(GarraColors.garnetDeep)
            : const Color(GarraColors.surface),
        borderRadius: BorderRadius.circular(GarraRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GarraRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(GarraSpacing.md),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: const Color(GarraColors.gold),
                ),
                const SizedBox(width: GarraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: const Color(GarraColors.cream),
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
