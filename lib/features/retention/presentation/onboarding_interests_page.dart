import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../data/retention_models.dart';
import '../data/retention_service.dart';

/// Short interest onboarding (3–4 steps). Skip allowed.
class OnboardingInterestsPage extends StatefulWidget {
  const OnboardingInterestsPage({super.key});

  @override
  State<OnboardingInterestsPage> createState() => _OnboardingInterestsPageState();
}

class _OnboardingInterestsPageState extends State<OnboardingInterestsPage> {
  final _service = RetentionService();
  final _city = TextEditingController();
  final _selected = <String>{};
  int _step = 0;
  bool _busy = false;

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool skip}) async {
    setState(() => _busy = true);
    try {
      await _service.updateInterests(
        city: skip ? null : (_city.text.trim().isEmpty ? null : _city.text.trim()),
        region: skip ? null : (_city.text.trim().isEmpty ? null : _city.text.trim()),
        interests: skip ? const [] : _selected.toList(),
        onboardingCompleted: true,
      );
      if (!mounted) return;
      context.go('/comunidad');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.go('/comunidad');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Tu Garra'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _finish(skip: true),
            child: const Text('Omitir'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_step + 1) / 3,
              color: const Color(GarraColors.gold),
              backgroundColor: const Color(0xFF2A2A2A),
            ),
            const SizedBox(height: GarraSpacing.xl),
            Expanded(child: _buildStep()),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_step < 2) {
                        setState(() => _step++);
                      } else {
                        _finish(skip: false);
                      }
                    },
              child: Text(_step < 2 ? 'Continuar' : 'Empezar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Desde dónde sigues a la crema?',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: GarraSpacing.md),
            TextField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'Ciudad / región',
                hintText: 'Ej. Lima',
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Qué te interesa en Garra?',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Elige hasta 4. Puedes cambiarlo después.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: GarraSpacing.lg),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kFanInterestOptions.map((opt) {
                final selected = _selected.contains(opt.$1);
                return FilterChip(
                  label: Text(opt.$2),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        if (_selected.length < 4) _selected.add(opt.$1);
                      } else {
                        _selected.remove(opt.$1);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Listo para explorar',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: GarraSpacing.md),
            const GarraCard(
              child: Text(
                'Te sugeriremos comunidades y momentos según lo que elegiste. '
                'Siempre puedes omitir o editar tus intereses.',
              ),
            ),
            const SizedBox(height: GarraSpacing.md),
            TextButton(
              onPressed: () => context.push('/clans'),
              child: const Text('Ver Comunidades Cremas'),
            ),
          ],
        );
    }
  }
}
