import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final myNotificationsProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  return ref.watch(notificationServiceProvider).getMyNotifications();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myNotificationsProvider);

    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationServiceProvider).markAllRead();
              ref.invalidate(myNotificationsProvider);
            },
            child: const Text('Marcar leídas'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(GarraSpacing.lg),
          child: Column(
            children: [
              GarraSkeleton(height: 72),
              SizedBox(height: GarraSpacing.md),
              GarraSkeleton(height: 72),
              SizedBox(height: GarraSpacing.md),
              GarraSkeleton(height: 72),
            ],
          ),
        ),
        error: (error, stackTrace) => GarraErrorState(
          onRetry: () => ref.invalidate(myNotificationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const GarraEmptyState(
              title: 'Sin notificaciones',
              message: 'Cuando haya novedades de la hinchada, aparecerán aquí.',
            );
          }
          return RefreshIndicator(
            color: const Color(GarraColors.gold),
            onRefresh: () async => ref.invalidate(myNotificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: GarraSpacing.sm),
              itemBuilder: (context, index) {
                final item = items[index];
                final when = DateFormat('d MMM · HH:mm').format(
                  item.createdAt.toLocal(),
                );
                return GarraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: item.read
                                        ? FontWeight.w600
                                        : FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (!item.read)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(GarraColors.gold),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: GarraSpacing.xs),
                      Text(
                        item.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: GarraSpacing.sm),
                      Text(
                        when,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
