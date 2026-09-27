import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/network/garra_error.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/notification_service.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/push_router.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final myNotificationsProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  return ref.watch(notificationServiceProvider).getMyNotifications();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const _router = PushRouter();

  /// The Home bell badge comes from GET /home (`notifications.unreadCount`):
  /// reload it together with the list after a successful read.
  static void _refreshUnread(ProviderContainer container) {
    container.invalidate(myNotificationsProvider);
    container.invalidate(homeProvider);
  }

  Future<void> _markAllRead(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await container.read(notificationServiceProvider).markAllRead();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(garraActionErrorMessage(e))),
      );
      return;
    }
    _refreshUnread(container);
  }

  /// Opening an item marks it read (PATCH /notifications/{id}/read) without
  /// delaying navigation.
  void _open(BuildContext context, NotificationItem item, String? route) {
    final container = ProviderScope.containerOf(context, listen: false);
    if (!item.read) {
      container
          .read(notificationServiceProvider)
          .markRead(item.id)
          .then((_) => _refreshUnread(container), onError: (_) {});
    }
    if (route != null) context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myNotificationsProvider);

    return Scaffold(
      backgroundColor: context.garraColors.background,
      appBar: AppBar(
        title: const Text('Actividad'),
        actions: [
          TextButton(
            key: const ValueKey('notifications_mark_all'),
            onPressed: () => _markAllRead(context),
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
                final route = _router.resolveRoute(
                  authenticated: true,
                  type: item.type,
                  referenceType: item.referenceType,
                  referenceId: item.referenceId,
                );
                final tappable = route != '/notifications';
                return GarraCard(
                  key: ValueKey('notification_item_${item.id}'),
                  onTap: tappable || !item.read
                      ? () => _open(context, item, tappable ? route : null)
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _iconFor(item.type, item.referenceType),
                            color: const Color(GarraColors.gold),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
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

  static IconData _iconFor(String? type, String? referenceType) {
    final t = (type ?? '').toUpperCase();
    final r = (referenceType ?? '').toUpperCase();
    if (r.contains('FAN') || t.contains('FOLLOW') || t.contains('SOCIAL')) {
      return Icons.person_add_alt_1_outlined;
    }
    if (r.contains('POST') || t.contains('MENTION') || t.contains('COMMENT')) {
      return Icons.chat_bubble_outline;
    }
    if (t.contains('SOLIDAR') || r.contains('SOLIDAR')) {
      return Icons.volunteer_activism_outlined;
    }
    if (t.contains('MARKET') || r.contains('LISTING') || r.contains('STORE')) {
      return Icons.shopping_bag_outlined;
    }
    if (t.contains('BUSINESS') || r.contains('CREMA') || r.contains('POINT')) {
      return Icons.storefront_outlined;
    }
    if (t.contains('CLAN') || t.contains('COMMUNITY')) {
      return Icons.groups_outlined;
    }
    return Icons.notifications_outlined;
  }
}
