import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';

const chatAudioMaxDuration = Duration(seconds: 60);
// Enable only after chat audio objects live in storage without a public URL.
const bool chatAudioEnabled = false;

abstract class ChatAudioRecorder {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> dispose();
}

class NativeChatAudioRecorder implements ChatAudioRecorder {
  final AudioRecorder _native = AudioRecorder();
  @override
  Future<bool> hasPermission() => _native.hasPermission();
  @override
  Future<void> start(String path) => _native.start(
    const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
    path: path,
  );
  @override
  Future<String?> stop() => _native.stop();
  @override
  Future<void> dispose() => _native.dispose();
}

/// Keeps a stopped recording locally until both upload and message creation
/// succeed. Retrying always requires a fresh tap; no ambiguous write is retried.
class ChatAudioComposer extends StatefulWidget {
  const ChatAudioComposer({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.media,
    this.recorder,
    this.recordingPath,
    this.onDirtyChanged,
  });

  final Future<void> Function(String assetId, int durationSeconds) onSend;
  final bool enabled;
  final MediaUploadService? media;
  final ChatAudioRecorder? recorder;
  final Future<String> Function()? recordingPath;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<ChatAudioComposer> createState() => _ChatAudioComposerState();
}

class _ChatAudioComposerState extends State<ChatAudioComposer> {
  late final ChatAudioRecorder _recorder =
      widget.recorder ?? NativeChatAudioRecorder();
  late final MediaUploadService _media = widget.media ?? MediaUploadService();
  Timer? _timer;
  DateTime? _started;
  String? _path;
  String? _readyAssetId;
  int _seconds = 0;
  bool _recording = false;
  bool _busy = false;
  final CancelToken _cancel = CancelToken();
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _cancel.cancel('Audio composer closed');
    if (widget.recorder == null) _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || _recording || !widget.enabled || _path != null) return;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted)
          setState(() => _error = 'Permite el micrófono para grabar.');
        return;
      }
      final path = widget.recordingPath != null
          ? await widget.recordingPath!()
          : '${(await getTemporaryDirectory()).path}/garra_audio_${const Uuid().v4()}.m4a';
      await _recorder.start(path);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _started = DateTime.now();
        _seconds = 0;
        _error = null;
      });
      widget.onDirtyChanged?.call(true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_recording) return;
        final elapsed = DateTime.now().difference(_started!).inSeconds;
        if (elapsed >= chatAudioMaxDuration.inSeconds) {
          _stop();
        } else {
          setState(() => _seconds = elapsed);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos iniciar la grabación.');
    }
  }

  Future<void> _stop({bool discard = false}) async {
    if (!_recording) return;
    _timer?.cancel();
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _seconds = DateTime.now().difference(_started!).inSeconds.clamp(1, 60);
        _path = discard ? null : path;
      });
      widget.onDirtyChanged?.call(!discard && path != null);
      if (discard) {
        _readyAssetId = null;
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _recording = false;
          _error = 'No pudimos guardar el audio.';
        });
    }
  }

  Future<void> _send() async {
    final path = _path;
    if (path == null || _busy || !widget.enabled) return;
    if (!allowNetworkAction(context)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var assetId = _readyAssetId;
      if (assetId == null) {
        final result = await _media.uploadChatAudio(
          path: path,
          canStartRemote: () => mounted && allowNetworkAction(context),
          cancelToken: _cancel,
        );
        if (!mounted) return;
        if (!result.isReady) throw StateError('Upload failed');
        assetId = result.assetId;
        _readyAssetId = assetId;
      }
      if (!allowNetworkAction(context)) throw StateError('Offline');
      await widget.onSend(assetId!, _seconds);
      if (mounted) {
        setState(() {
          _path = null;
          _seconds = 0;
          _readyAssetId = null;
        });
        widget.onDirtyChanged?.call(false);
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'No se envió. Conservamos tu audio; toca para reintentar.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled && _path == null && !_recording)
      return const SizedBox.shrink();
    if (_path == null && !_recording) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('chat-audio-record'),
            tooltip: 'Grabar audio',
            onPressed: widget.enabled ? _start : null,
            icon: const Icon(Icons.mic_none_rounded),
          ),
          if (_error != null) Flexible(child: Text(_error!, maxLines: 2)),
        ],
      );
    }
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const Icon(Icons.graphic_eq_rounded, size: 20),
          Text(' ${_seconds}s / 60s'),
          if (_recording) ...[
            IconButton(
              key: const Key('chat-audio-cancel'),
              tooltip: 'Cancelar audio',
              onPressed: () => _stop(discard: true),
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              key: const Key('chat-audio-stop'),
              tooltip: 'Terminar grabación',
              onPressed: _stop,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          ] else ...[
            IconButton(
              key: const Key('chat-audio-discard'),
              tooltip: 'Descartar audio',
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _path = null;
                        _error = null;
                        _readyAssetId = null;
                      });
                      widget.onDirtyChanged?.call(false);
                    },
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              key: const Key('chat-audio-send'),
              tooltip: 'Enviar audio',
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
          if (_error != null) Flexible(child: Text(_error!, maxLines: 2)),
        ],
      ),
    );
  }
}
