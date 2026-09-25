import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Tunable window into the supporter-chant source.
/// The full file stays intact; playback is limited in the player.
abstract final class GarraIntroAudio {
  static const int introAudioStartMs = 0;
  static const int introAudioDurationMs = 5600;
  static const String assetPath = 'audio/garra_intro_source.mp3';
}

/// Local intro bed. Failures are swallowed by the caller.
abstract class IntroAudio {
  Future<void> start();
  Future<void> stop();
  void dispose();
}

class AssetIntroAudio implements IntroAudio {
  AssetIntroAudio({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Timer? _stopTimer;
  Timer? _fadeTimer;
  var _stopped = false;

  @override
  Future<void> start() async {
    _stopped = false;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(1);
    await _player.play(
      AssetSource(GarraIntroAudio.assetPath),
      position: Duration(milliseconds: GarraIntroAudio.introAudioStartMs),
    );
    final fadeAt = GarraIntroAudio.introAudioDurationMs - 700;
    _fadeTimer = Timer(Duration(milliseconds: fadeAt < 0 ? 0 : fadeAt), () {
      unawaited(_fadeOut());
    });
    _stopTimer = Timer(
      Duration(milliseconds: GarraIntroAudio.introAudioDurationMs),
      () {
        unawaited(stop());
      },
    );
  }

  Future<void> _fadeOut() async {
    for (var step = 4; step >= 0; step--) {
      if (_stopped) return;
      await _player.setVolume(step / 4);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _fadeTimer?.cancel();
    _stopTimer?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _stopTimer?.cancel();
    unawaited(stop());
    _player.dispose();
  }
}
