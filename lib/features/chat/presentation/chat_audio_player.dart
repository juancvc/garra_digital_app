import 'dart:io';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/dio_client.dart';

abstract class ChatAudioEngine {
  Stream<Duration> get positions;
  Stream<Duration> get durations;
  Stream<void> get completions;
  Future<void> play(String path);
  Future<void> pause();
  Future<void> dispose();
}

class NativeChatAudioEngine implements ChatAudioEngine {
  final AudioPlayer _player = AudioPlayer();
  @override
  Stream<Duration> get positions => _player.onPositionChanged;
  @override
  Stream<Duration> get durations => _player.onDurationChanged;
  @override
  Stream<void> get completions => _player.onPlayerComplete;
  @override
  Future<void> play(String path) => _player.play(DeviceFileSource(path));
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> dispose() => _player.dispose();
}

/// Fetches audio through the authenticated chat endpoint. The media URL is
/// relative; it must never be handed to an unauthenticated player as R2 URL.
class ChatAudioPlayer extends StatefulWidget {
  const ChatAudioPlayer({
    super.key,
    required this.url,
    this.client,
    this.engine,
    this.saveBytes,
  });
  final String url;
  final Dio? client;
  final ChatAudioEngine? engine;
  final Future<String> Function(List<int> bytes)? saveBytes;

  @override
  State<ChatAudioPlayer> createState() => _ChatAudioPlayerState();
}

class _ChatAudioPlayerState extends State<ChatAudioPlayer> {
  late final ChatAudioEngine _player = widget.engine ?? NativeChatAudioEngine();
  String? _localPath;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;
  bool _playing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      _player.positions.listen((value) {
        if (mounted) setState(() => _position = value);
      }),
    );
    _subscriptions.add(
      _player.durations.listen((value) {
        if (mounted) setState(() => _duration = value);
      }),
    );
    _subscriptions.add(
      _player.completions.listen((_) {
        if (mounted)
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
      }),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    if (widget.saveBytes == null && _localPath != null) {
      File(_localPath!).delete().ignore();
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (_playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
        return;
      }
      if (_localPath == null) {
        setState(() {
          _loading = true;
          _error = null;
        });
        final response = await (widget.client ?? DioClient.instance)
            .get<List<int>>(
              widget.url,
              options: Options(
                responseType: ResponseType.bytes,
                receiveTimeout: const Duration(seconds: 30),
              ),
            );
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
          throw StateError('Invalid audio');
        }
        if (widget.saveBytes != null) {
          _localPath = await widget.saveBytes!(bytes);
        } else {
          final dir = await getTemporaryDirectory();
          _localPath = (await File(
            '${dir.path}/garra_play_${const Uuid().v4()}.m4a',
          ).writeAsBytes(bytes)).path;
        }
      }
      await _player.play(_localPath!);
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos reproducir el audio.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('chat-audio-play'),
            tooltip: _playing ? 'Pausar audio' : 'Reproducir audio',
            onPressed: _loading ? null : _toggle,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _playing
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
          ),
          SizedBox(
            width: 130,
            child: LinearProgressIndicator(
              value: _duration.inMilliseconds > 0
                  ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(
                      0,
                      1,
                    )
                  : 0,
            ),
          ),
          Text(' ${_position.inSeconds}s'),
        ],
      ),
      if (_error != null) Text(_error!, style: const TextStyle(fontSize: 12)),
    ],
  );
}
