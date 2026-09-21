import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_radius.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_typography.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/reward_models.dart';
import 'providers/reward_provider.dart';
import 'redemption_success_page.dart';

class RewardDetailPage extends ConsumerStatefulWidget {
  const RewardDetailPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<RewardDetailPage> createState() => _RewardDetailPageState();
}

class _RewardDetailPageState extends ConsumerState<RewardDetailPage> {
  bool _redeeming = false;

  Future<void> _confirmRedeem(RewardOffer offer, int balance) async {
    final after = balance - offer.pointsCost;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(GarraColors.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GarraRadius.xl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(GarraSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirmar canje',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: GarraSpacing.md),
              Text(offer.title, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: GarraSpacing.lg),
              _row(ctx, 'Saldo actual', '$balance Puntos Garra'),
              _row(ctx, 'Costo', '${offer.pointsCost} Puntos Garra'),
              _row(ctx, 'Saldo después', '$after Puntos Garra'),
              const SizedBox(height: GarraSpacing.xl),
              GarraPrimaryButton(
                label: 'Confirmar canje',
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: GarraSpacing.sm),
              GarraSecondaryButton(
                label: 'Cancelar',
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _doRedeem(offer);
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: GarraTypography.numeric(size: 14)),
        ],
      ),
    );
  }

  Future<void> _doRedeem(RewardOffer offer) async {
    setState(() => _redeeming = true);
    try {
      final redemption =
          await ref.read(rewardServiceProvider).redeem(offer.slug);
      ref.invalidate(rewardDetailProvider(widget.slug));
      ref.invalidate(rewardCatalogProvider);
      ref.invalidate(myRewardsProvider);
      ref.invalidate(homeProvider);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RedemptionSuccessPage(redemption: redemption),
        ),
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.response!.data['error'])?.toString()
          : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'No pudimos completar el canje.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos completar el canje.')),
        );
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(rewardDetailProvider(widget.slug));
    final home = ref.watch(homeProvider);
    final balance = home.maybeWhen(data: (h) => h.fan.points, orElse: () => 0);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Beneficio')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => GarraErrorState(
          message: 'No pudimos cargar este beneficio.',
          onRetry: () => ref.invalidate(rewardDetailProvider(widget.slug)),
        ),
        data: (offer) {
          final missing = offer.pointsCost - balance;
          final insufficient = balance < offer.pointsCost;
          return ListView(
            padding: const EdgeInsets.all(GarraSpacing.lg),
            children: [
              if (offer.imageUrl != null && offer.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(GarraRadius.lg),
                  child: CachedNetworkImage(
                    imageUrl: offer.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              if (offer.imageUrl != null) const SizedBox(height: GarraSpacing.lg),
              Text(
                offer.sponsored
                    ? 'Patrocinado por ${offer.providerName ?? offer.providerLabel}'
                    : offer.providerLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(GarraColors.gold),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: GarraSpacing.sm),
              Text(offer.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: GarraSpacing.md),
              Text(offer.description, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: GarraSpacing.xl),
              GarraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${offer.pointsCost} Puntos Garra',
                      style: GarraTypography.numeric(size: 24),
                    ),
                    const SizedBox(height: GarraSpacing.sm),
                    Text(
                      'Tu saldo: ${NumberFormat('#,###').format(balance)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: GarraSpacing.xs),
                    Text(
                      'Límite: ${offer.maxRedemptionsPerFan} por hincha'
                      '${offer.myRedemptionCount > 0 ? ' · Ya canjeaste ${offer.myRedemptionCount}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!offer.available || offer.ineligibilityReason != null) ...[
                      const SizedBox(height: GarraSpacing.sm),
                      Text(
                        offer.ineligibilityReason ?? 'No disponible',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ],
                ),
              ),
              if (offer.terms != null && offer.terms!.trim().isNotEmpty) ...[
                const SizedBox(height: GarraSpacing.lg),
                GarraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Términos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: GarraSpacing.sm),
                      Text(
                        offer.terms!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: GarraSpacing.xl),
              if (insufficient)
                GarraCard(
                  child: Text(
                    'Te faltan $missing Puntos Garra',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(GarraColors.gold),
                        ),
                  ),
                )
              else
                GarraPrimaryButton(
                  label: _redeeming
                      ? 'Canjeando…'
                      : 'Canjear por ${offer.pointsCost} Puntos Garra',
                  onPressed: (!offer.canRedeem || _redeeming)
                      ? null
                      : () => _confirmRedeem(offer, balance),
                ),
              const SizedBox(height: GarraSpacing.md),
              GarraSecondaryButton(
                label: 'Ver mis canjes',
                onPressed: () => context.push('/rewards/me'),
              ),
            ],
          );
        },
      ),
    );
  }
}
