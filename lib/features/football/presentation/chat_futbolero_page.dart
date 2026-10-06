import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_status.dart';
import '../data/football_chat_service.dart';

final footballChatServiceProvider =
    Provider<FootballChatService>((ref) => FootballChatService());

/// SONIC_03: general football chat from Centro Garra (not match Tribuna).
class ChatFutboleroPage extends ConsumerStatefulWidget {
  const ChatFutboleroPage({super.key});

  @override
  ConsumerState<ChatFutboleroPage> createState() => _ChatFutboleroPageState();
}

class _ChatFutboleroPageState extends ConsumerState<ChatFutboleroPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<FootballChatMessage> _items = const [];
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
      _poll = Timer.periodic(const Duration(seconds: 12), (_) {
        if (mounted && !_sending) _load(silent: true);
      });
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (ref.read(connectivityStatusProvider) == NetworkConnectivity.offline) {
      if (!silent) setState(() { _loading = false; _failed = _items.isEmpty; _error = 'Sin conexión'; });
      return;
    }
    if (!silent) setState(() { _loading = true; _failed = false; _error = null; });
    try {
      final page = await ref.read(footballChatServiceProvider).messages();
      if (!mounted) return;
      setState(() { _items = page.items; _failed = false; _error = null; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_items.isEmpty) { _failed = true; _error = 'No pudimos cargar el chat'; }
      });
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await ref.read(footballChatServiceProvider).send(body);
      if (!mounted) return;
      setState(() {
        _items = [..._items, msg];
        _controller.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar. Inténtalo de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Futbolero')),
      body: Column(children: [
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _failed && _items.isEmpty
                  ? ListView(padding: const EdgeInsets.all(24), children: [
                      Text(_error ?? 'Error', style: text.titleMedium),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('Reintentar')),
                    ])
                  : _items.isEmpty
                      ? ListView(padding: const EdgeInsets.all(24), children: [
                          Text('Todavía no hay mensajes', style: text.titleMedium),
                          const SizedBox(height: 8),
                          Text('Sé el primero en arengar en el Chat Futbolero.',
                              style: text.bodyMedium),
                        ])
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final m = _items[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(m.authorName,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(m.body),
                                  isThreeLine: m.body.length > 60,
                                ),
                              );
                            },
                          ),
                        ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: 280,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Escribe tu arenga…',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
