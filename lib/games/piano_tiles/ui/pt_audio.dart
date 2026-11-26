import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../../core/audio/audio_mix.dart';
import '../../../core/audio/sfx_service.dart';
import '../core/pt_songs.dart';

/// Low-latency piano: one small round-robin pool of [PlayerMode.lowLatency] players (Android SoundPool)
/// per synthesised note sample, preloaded for the song being played so a tap sounds instantly.
/// Respects the app's sound switch / volume and ducks under a live voice call like every other game sound.
class PtAudio {
  PtAudio({required this.enabled});

  final bool enabled;
  static const int _voices = 3;
  final Map<String, _Pool> _pools = <String, _Pool>{};
  bool _disposed = false;

  static final bool _inTests = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  bool get _on => enabled && !_inTests && !_disposed && NxSfx.instance.enabled && NxSfx.instance.volume > 0;

  static String noteAsset(int midi) => 'games/piano_tiles/notes/n${midi.clamp(kPtLowNote, kPtHighNote)}.wav';

  /// Loads the samples [song] needs (plus the game sfx); safe to call again for another song.
  Future<void> preload(PtSong song) async {
    if (!_on) return;
    final List<String> want = <String>[
      for (final int p in ptPitches(song)) noteAsset(p),
      'games/piano_tiles/miss.wav',
      'games/piano_tiles/star.wav',
      'games/piano_tiles/win.wav',
    ];
    // Free samples of other songs so the SoundPool stays small.
    for (final String k in _pools.keys.toList()) {
      if (!want.contains(k)) unawaited(_pools.remove(k)!.dispose());
    }
    for (final String a in want) {
      _pools.putIfAbsent(a, () => _Pool(a, a.contains('/notes/') ? _voices : 1));
    }
    await Future.wait(_pools.values.map((_Pool p) => p.ready));
  }

  void note(int midi, {double gain = 1}) => _play(noteAsset(midi), gain);
  void miss() => _play('games/piano_tiles/miss.wav', 0.9);
  void star() => _play('games/piano_tiles/star.wav', 0.7);
  void win() => _play('games/piano_tiles/win.wav', 0.8);

  void _play(String asset, double gain) {
    if (!_on) return;
    final _Pool p = _pools.putIfAbsent(asset, () => _Pool(asset, asset.contains('/notes/') ? _voices : 1));
    unawaited(p.play((NxSfx.instance.volume * gain * NxAudioMix.gain).clamp(0.0, 1.0).toDouble()));
  }

  Future<void> dispose() async {
    _disposed = true;
    final List<_Pool> all = _pools.values.toList();
    _pools.clear();
    for (final _Pool p in all) {
      await p.dispose();
    }
  }
}

class _Pool {
  _Pool(this.asset, int voices) {
    ready = _init(voices);
  }

  final String asset;
  final List<AudioPlayer> _players = <AudioPlayer>[];
  late final Future<void> ready;
  int _next = 0;

  Future<void> _init(int voices) async {
    for (int i = 0; i < voices; i++) {
      try {
        final AudioPlayer a = AudioPlayer();
        await a.setPlayerMode(PlayerMode.lowLatency);
        await a.setReleaseMode(ReleaseMode.stop);
        await NxAudioMix.apply(a);
        await a.setSource(AssetSource(asset));
        _players.add(a);
      } catch (e) {
        debugPrint('piano tiles audio $asset: $e');
      }
    }
  }

  Future<void> play(double vol) async {
    await ready;
    if (_players.isEmpty) return;
    final AudioPlayer p = _players[_next];
    _next = (_next + 1) % _players.length;
    try {
      // Fire all three without waiting between them: platform-channel messages stay ordered, and not
      // awaiting each round trip keeps tap-to-sound latency at one SoundPool call.
      final Future<void> a = p.stop();
      final Future<void> b = (p.volume - vol).abs() > 0.01 ? p.setVolume(vol) : Future<void>.value();
      final Future<void> c = p.resume();
      await Future.wait(<Future<void>>[a, b, c]);
    } catch (e) {
      debugPrint('piano tiles play $asset: $e');
    }
  }

  Future<void> dispose() async {
    await ready;
    for (final AudioPlayer p in _players) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
