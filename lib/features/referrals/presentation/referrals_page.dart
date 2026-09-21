import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../data/referral_models.dart';
import 'providers/referral_provider.dart';

class ReferralsPage extends ConsumerStatefulWidget {
  const ReferralsPage({super.key});

  @override
  ConsumerState<ReferralsPage> createState() => _ReferralsPageState();
}

class _ReferralsPageState extends ConsumerState<ReferralsPage> {
  final _claimController = TextEditingController();
  bool _claiming = false;
  String? _claimFeedback;

  @override
  void dispose() {
    _claimController.dispose();
    super.dispose();
  }

  Future<void> _share(String code) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Únete a Garra Digital con mi código: $code',
      ),
    );
  }

  Future<void> _claim() async {
    final code = _claimController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _claiming = true;
      _claimFeedback = null;
    });
    try {
      final result =
          await ref.read(referralServiceProvider).claim(code);
      ref.invalidate(referralMeProvider);
      setState(() => _claimFeedback = result.message);
    } catch (e) {
      setState(() => _claimFeedback = referralClaimErrorMessage(e));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(referralMeProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Invita cremas')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(referralMeProvider),
        child: me.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => GarraErrorState(
            message: 'No pudimos cargar tus invitaciones.',
            onRetry: () => ref.invalidate(referralMeProvider),
          ),
          data: (data) {
            final campaign = data.activeCampaign;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(GarraSpacing.lg),
              children: [
                GarraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu código',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(GarraColors.gold),
                            ),
                      ),
                      const SizedBox(height: GarraSpacing.sm),
                      SelectableText(
                        data.myCode,
                        style: GarraTypography.numeric(size: 28),
                      ),
                      const SizedBox(height: GarraSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: GarraPrimaryButton(
                              label: 'Compartir',
                              onPressed: () => _share(data.myCode),
                            ),
                          ),
                          const SizedBox(width: GarraSpacing.sm),
                          IconButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: data.myCode),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Código copiado'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy),
                            color: const Color(GarraColors.gold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GarraSpacing.lg),
                GarraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign == null || !campaign.isActive
                            ? 'Sin campaña de recompensa activa'
                            : campaign.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: GarraSpacing.sm),
                      Text(
                        campaign == null || !campaign.isActive
                            ? 'Puedes compartir tu código, pero actualmente no hay campaña de puntos por referidos.'
                            : 'Por cada invitado activado puedes ganar ${campaign.inviterRewardPoints} Puntos Garra'
                                '${campaign.refereeRewardPoints > 0 ? ' (tu invitado gana ${campaign.refereeRewardPoints})' : ''}.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GarraSpacing.lg),
                GarraCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: GarraStat(
                          label: 'Activados',
                          value: '${data.qualifiedCount}',
                        ),
                      ),
                      Expanded(
                        child: GarraStat(
                          label: 'Pendientes',
                          value: '${data.pendingCount}',
                        ),
                      ),
                      Expanded(
                        child: GarraStat(
                          label: 'Pts ganados',
                          value: '${data.pointsEarnedFromReferrals}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GarraSpacing.xl),
                const GarraSectionHeader(
                  title: 'Tengo un código',
                  subtitle: 'Solo para cuentas nuevas dentro del plazo.',
                ),
                const SizedBox(height: GarraSpacing.md),
                TextField(
                  controller: _claimController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código de invitación',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: GarraSpacing.md),
                GarraPrimaryButton(
                  label: _claiming ? 'Registrando…' : 'Registrar código',
                  onPressed: _claiming ? null : _claim,
                ),
                if (_claimFeedback != null) ...[
                  const SizedBox(height: GarraSpacing.md),
                  Text(
                    _claimFeedback!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
