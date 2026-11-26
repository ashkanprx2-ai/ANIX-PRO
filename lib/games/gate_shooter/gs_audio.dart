import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../core/audio/audio_mix.dart';
import '../../core/audio/sfx_service.dart';

/// Gate Shooter sound effects (assets/games/gate_shooter/sfx/*.wav, synthesized for the game).
///
/// Small round-robin pools on low-latency players, NxAudioMix so a live voice call is never interrupted,
/// the app's Sound-effects switch/volume and the launch's soundOn flag respected, and a per-sound minimum gap so
/// a squad of 60 rifles never floods the mixer.
class GsAudio {
  GsAudio({required this.on});

  final bool on;

  static const Map<String, (int voices, int gapMs, double vol)> sounds = <String, (int, int, double)>{
    'shot': (4, 70, 0.32),
    'hit': (3, 55, 0.4),
    'explode': (3, 90, 0.95),
    'coin': (3, 70, 0.5),
    'gate_up': (2, 150, 0.8),
    'gate_down': (2, 150, 0.8),
    'hurt': (2, 160, 0.7),
    'pop': (3, 60, 0.45),
    'upgrade': (2, 80, 0.7),
    'boss': (1, 800, 1.0),
    'wave': (1, 600, 0.8),
  };

  static final bool _inTests = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  final Map<String, List<Future<AudioPlayer>>> _pools = <String, List<Future<AudioPlayer>>>{};
  final Map<String, int> _cursor = <String, int>{};
  final Map<String, int> _last = <String, int>{};
  final Stopwatch _clock = Stopwatch()..start();
  bool _disposed = false;

  bool get _active => on && !_inTests && !_disposed && NxSfx.instance.enabled && NxSfx.instance.volume > 0;

  void play(String name, {double gain = 1}) {
    if (!_active) return;
    final (int, int, double)? spec = sounds[name];
    if (spec == null) return;
    final int now = _clock.elapsedMilliseconds;
    if (now - (_last[name] ?? -100000) < spec.$2) return;
    _last[name] = now;
    final List<Future<AudioPlayer>> pool = _pools.putIfAbsent(name, () => <Future<AudioPlayer>>[]);
    final int i = _cursor[name] ?? 0;
    _cursor[name] = (i + 1) % spec.$1;
    if (pool.length <= i) pool.add(_open());
    final double vol = (spec.$3 * gain * NxSfx.instance.volume * NxAudioMix.gain).clamp(0.0, 1.0).toDouble();
    unawaited(_play(pool[i], name, vol));
  }

  Future<AudioPlayer> _open() async {
    final AudioPlayer a = AudioPlayer();
    try {
      await a.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {}
    try {
      await a.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
    await NxAudioMix.apply(a);
    return a;
  }

  Future<void> _play(Future<AudioPlayer> f, String name, double vol) async {
    try {
      final AudioPlayer p = await f;
      if (_disposed) return;
      await p.stop();
      await p.setVolume(vol);
      await p.play(AssetSource('games/gate_shooter/sfx/$name.wav'));
    } catch (e) {
      debugPrint('gate_shooter sfx $name: $e');
    }
  }

  void dispose() {
    _disposed = true;
    for (final List<Future<AudioPlayer>> pool in _pools.values) {
      for (final Future<AudioPlayer> f in pool) {
        unawaited(f.then((AudioPlayer p) => p.dispose()).catchError((Object _) {}));
      }
    }
    _pools.clear();
  }
}
