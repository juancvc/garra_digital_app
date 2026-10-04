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

/// Activity center. First page + cursor "load more" (the backend already
/// paginates); a failed next page never removes what is on screen.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _router = PushRouter();
  static const _pageSize = 30;

  final _scroll = ScrollController();
  List<NotificationItem> _items = const [];
  String? _nextCursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _error = false;
  bool _loadingMore = false;
  bool _moreFailed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// The Home bell badge comes from GET /home (`notifications.unreadCount`).
  /// Home keeps what it shows while it reloads, so this is cheap and safe.
  void _refreshBadge() {
    if (!mounted) return;
    ProviderScope.containerOf(context, listen: false).invalidate(homeProvider);
  }

  Future<void> _loadFirst({bool refresh = false}) async {
    final generation = ++_generation;
    if (!refresh) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final page = await ref
          .read(notificationServiceProvider)
          .getNotificationsPage(size: _pageSize);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasNext;
        _loading = false;
        _error = false;
        _loadingMore = false;
        _moreFailed = false;
      });
      _scheduleFillCheck();
    } catch (e) {
      if (!mounted || generation != _generation) return;
      if (refresh && _items.isNotEmpty) {
        // A failed refresh keeps the notifications that are already visible.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(garraActionErrorMessage(e))),
        );
        return;
      }
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _onScroll() {
    // After a failure the user decides ("Reintentar"); scrolling never re-fires.
    if (!_scroll.hasClients || _moreFailed) return;
    if (_scroll.position.extentAfter < 600) _loadMore();
  }

  void _scheduleFillCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_hasMore && !_moreFailed && _scroll.position.extentAfter < 600) {
        _loadMore();
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor == null) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final page = await ref
          .read(notificationServiceProvider)
          .getNotificationsPage(cursor: _nextCursor, size: _pageSize);
      if (!mounted || generation != _generation) return;
      final seen = {for (final item in _items) item.id};
      setState(() {
        _items = [
          ..._items,
          ...page.items.where((item) => seen.add(item.id)),
        ];
        _nextCursor = page.nextCursor;
        _hasMore = page.hasNext;
        _loadingMore = false;
      });
      _scheduleFillCheck();
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  /// Re-reads page 1 and only updates the read flags of rows already shown
  /// (chat notifications are cleared server-side when the chat is read).
  Future<void> _reconcileReadState() async {
    final generation = _generation;
    try {
      final page = await ref
          .read(notificationServiceProvider)
          .getNotificationsPage(size: _pageSize);
      if (!mounted || generation != _generation) return;
      final fresh = {for (final item in page.items) item.id: item};
      setState(() {
        _items = [
          for (final item in _items)
            (fresh[item.id]?.read == true && !item.read)
                ? item.asRead()
                : item,
        ];
      });
    } catch (_) {
      // Keep what is on screen.
    }
  }

  Future<void> _markAllRead() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationServiceProvider).markAllRead();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(garraActionErrorMessage(e))),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _items = [for (final item in _items) item.asRead()]);
    _refreshBadge();
  }

  /// Opening an item marks it read (PATCH /notifications/{id}/read) without
  /// delaying navigation; the row turns read only after the server accepted.
  void _open(ActivityItem activity, String? route) {
    final item = activity.latest;
    if (!activity.isChatGroup && !item.read) {
      ref.read(notificationServiceProvider).markRead(item.id).then((_) {
        if (!mounted) return;
        setState(() {
          _items = [for (final it in _items) it.id == item.id ? it.asRead() : it];
        });
        _refreshBadge();
      }, onError: (_) {});
    }
    if (route != null) {
      context.push(route).then((_) {
        _refreshBadge();
        if (activity.isChatGroup) _reconcileReadState();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.garraColors.background,
      appBar: AppBar(
        title: const Text('Actividad'),
        actions: [
          TextButton(
            key: const ValueKey('notifications_mark_all'),
            onPressed: _markAllRead,
            child: const Text('Marcar le\u00eddas'),
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
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
      );
    }
    if (_error) {
      return GarraErrorState(onRetry: _loadFirst);
    }
    if (_items.isEmpty) {
      return const GarraEmptyState(
        title: 'Todo tranquilo por ahora.',
        message:
            'Cuando haya novedades de la hinchada, aparecer\u00e1n aqu\u00ed.',
      );
    }
    final activity = groupActivityItems(_items);
    final showFooter = _loadingMore || _moreFailed;
    return RefreshIndicator(
      color: const Color(GarraColors.gold),
      onRefresh: () => _loadFirst(refresh: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(GarraSpacing.lg),
        itemCount: activity.length + (showFooter ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: GarraSpacing.sm),
        itemBuilder: (context, index) {
          if (index >= activity.length) return _footer();
          return _row(context, activity[index]);
        },
      ),
    );
  }

  Widget _footer() {
    if (_moreFailed) {
      return Padding(
        key: const ValueKey('notifications_more_error'),
        padding: const EdgeInsets.symmetric(vertical: GarraSpacing.md),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: GarraSpacing.sm,
          children: [
            const Text('No pudimos cargar m\u00e1s actividad.'),
            TextButton(onPressed: _loadMore, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    return const Padding(
      key: ValueKey('notifications_loading_more'),
      padding: EdgeInsets.symmetric(vertical: GarraSpacing.md),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ActivityItem group) {
    final item = group.latest;
    final when = DateFormat('d MMM \u00b7 HH:mm').format(
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
      onTap: tappable || !group.read
          ? () => _open(group, tappable ? route : null)
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
                  group.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight:
                            group.read ? FontWeight.w600 : FontWeight.w800,
                      ),
                ),
              ),
              if (!group.read)
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
            group.isChatGroup && group.count > 1
                ? 'Abre la conversaci\u00f3n para leerlos'
                : item.message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: GarraSpacing.sm),
          Text(when, style: Theme.of(context).textTheme.labelSmall),
        ],
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