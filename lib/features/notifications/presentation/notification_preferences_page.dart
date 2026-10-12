import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/garra_spacing.dart';
import '../data/notification_preferences_service.dart';

final notificationPreferencesServiceProvider =
    Provider<NotificationPreferencesService>((ref) => NotificationPreferencesService());

/// PRODUCT-08C: notification preferences. Today: "Respuestas en chats" (direct replies in Comunidad Crema and
/// match chats). Off = no notification and no push for chat replies (server contract).
class NotificationPreferencesPage extends ConsumerStatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  ConsumerState<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends ConsumerState<NotificationPreferencesPage> {
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  bool _chatReplies = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final pref = await ref.read(notificationPreferencesServiceProvider).load();
      if (!mounted) return;
      setState(() {
        _chatReplies = pref.socialChatRepliesEnabled;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    if (_saving) return;
    final previous = _chatReplies;
    setState(() {
      _chatReplies = value; // optimistic, reverted below if the server does not confirm
      _saving = true;
    });
    try {
      final saved = await ref.read(notificationPreferencesServiceProvider).setChatReplies(value);
      if (!mounted) return;
      setState(() {
        _chatReplies = saved.socialChatRepliesEnabled;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chatReplies = previous;
        _saving = false;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          key: ValueKey('pref_chat_replies_error'),
          content: Text('No pudimos guardar el cambio. Intenta otra vez.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias de notificaciones')),
      body: _body(scheme),
    );
  }

  Widget _body(ColorScheme scheme) {
    if (_loading) {
      return const Center(
        key: ValueKey('pref_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_failed) {
      return Center(
        key: const ValueKey('pref_error'),
        child: Padding(
          padding: const EdgeInsets.all(GarraSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No pudimos cargar tus preferencias.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurface),
              ),
              const SizedBox(height: GarraSpacing.md),
              FilledButton(
                key: const ValueKey('pref_retry'),
                onPressed: _load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      children: [
        SwitchListTile(
          key: const ValueKey('pref_chat_replies'),
          value: _chatReplies,
          onChanged: _saving ? null : _toggle,
          title: Text('Respuestas en chats', style: TextStyle(color: scheme.onSurface)),
          subtitle: Text(
            'Avísame cuando alguien responda a mis mensajes en Comunidad Crema o en el chat de un partido.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          secondary: _saving
              ? const SizedBox(
                  key: ValueKey('pref_chat_replies_saving'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.reply_outlined, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
