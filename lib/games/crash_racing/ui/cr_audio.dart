import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../../core/audio/audio_mix.dart';

/// Race sound effects, reusing the app's existing SFX assets (no new audio). One low-latency player per sound,
/// created lazily; a sound re-triggered while playing restarts. Silent in tests and when sound is off.
class CrAudio {
  CrAudio({required this.enabled});
  final bool enabled;

  static final bool _inTests = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static const Map<String, String> _files = <String, String>{
    'tick': 'sfx/ui/tick.mp3',
    'go': 'sfx/ui/ready.mp3',
    'box': 'games/gate_shooter/sfx/pop.wav',
    'fruit': 'games/gate_shooter/sfx/coin.wav',
    'boost': 'games/gate_shooter/sfx/upgrade.wav',
    'fire': 'games/gate_shooter/sfx/shot.wav',
    'boom': 'games/gate_shooter/sfx/explode.wav',
    'hit': 'games/gate_shooter/sfx/hurt.wav',
    'bump': 'games/bermuda/sfx/t_wall.wav',
    'hop': 'games/bermuda/sfx/t_launch.wav',
    'lap': 'games/gate_shooter/sfx/wave.wav',
    'select': 'games/bermuda/sfx/select.wav',
    'fail': 'games/gate_shooter/sfx/gate_down.wav',
  };

  final Map<String, Future<AudioPlayer>> _players = <String, Future<AudioPlayer>>{};
  final Map<String, int> _last = <String, int>{};

  void play(String name, {double volume = 0.8}) {
    if (_inTests || !enabled) return;
    final String? file = _files[name];
    if (file == null) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_last[name] ?? 0) < 70) return;
    _last[name] = now;
    unawaited(_play(name, file, volume));
  }

  Future<void> _play(String name, String file, double volume) async {
    try {
      final AudioPlayer p = await _players.putIfAbsent(name, () async {
        final AudioPlayer a = AudioPlayer();
        try {
          await a.setPlayerMode(PlayerMode.lowLatency);
          await a.setReleaseMode(ReleaseMode.stop);
        } catch (_) {}
        await NxAudioMix.apply(a);
        return a;
      });
      await p.stop();
      await p.setVolume((volume * NxAudioMix.gain).clamp(0.0, 1.0).toDouble());
      await p.play(AssetSource(file));
    } catch (e) {
      debugPrint('crash sfx $name: $e');
    }
  }

  void dispose() {
    for (final Future<AudioPlayer> f in _players.values) {
      unawaited(f.then((AudioPlayer p) => p.dispose(), onError: (Object _) {}));
    }
    _players.clear();
  }
}
