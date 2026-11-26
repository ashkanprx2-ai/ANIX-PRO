import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/cr_race.dart';
import '../core/cr_track.dart';
import 'cr_art.dart';
import 'cr_audio.dart';
import 'cr_render.dart';
import 'cr_text.dart';

/// One race: the simulation, its renderer, sound and the player's controls. Driven by [CrFlameGame].
class CrSession {
  CrSession({
    required String trackId,
    required this.character,
    required this.art,
    required this.audio,
    required this.fa,
    required this.haptics,
    double botSkill = 0.92,
    int seed = 1,
    this.autopilot = false,
  })  : track = CrTrack.build(trackId),
        _seed = seed,
        _botSkill = botSkill {
    race = CrRace(track: track, playerCharacter: character, seed: _seed, botSkill: _botSkill);
    race.autopilotPlayer = autopilot;
    renderer = CrRenderer(race, art);
  }

  final CrTrack track;
  final int character;
  final CrArt art;
  final CrAudio audio;
  final bool fa;
  final bool haptics;
  final bool autopilot;
  final int _seed;
  final double _botSkill;
  late CrRace race;
  late CrRenderer renderer;

  // controls (set by the widget)
  bool left = false, right = false, drift = false;
  double tilt = 0;
  bool _turbo = false, _item = false;
  void tapTurbo() => _turbo = true;
  void tapItem() => _item = true;

  /// 3, 2, 1, 0 (= GO!), -1 hidden.
  final ValueNotifier<int> countdown = ValueNotifier<int>(3);
  final ValueNotifier<String> banner = ValueNotifier<String>('');
  final ValueNotifier<bool> finished = ValueNotifier<bool>(false);

  /// Ready for the HUD to show the turbo window on the DRIFT button.
  final ValueNotifier<bool> turboWindow = ValueNotifier<bool>(false);

  double _acc = 0;
  double _bannerT = 0;
  double _goT = 0;
  double _endT = -1;
  int _lastCount = 4;
  bool ended = false;
  double padTop = 0, padLeft = 0, padRight = 0;

  static const double _stepDt = 1 / 60;

  void tick(double dt) {
    if (dt > 0.1) dt = 0.1;
    final CrRacer p = race.player;
    double steer = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    if (steer == 0 && tilt.abs() > 0.08) steer = (tilt * 1.6).clamp(-1.0, 1.0);
    race.input(steer: steer, drift: drift, turbo: _turbo, useItem: _item);
    _turbo = false;
    _item = false;
    _acc += dt;
    int steps = 0;
    while (_acc >= _stepDt && steps < 6) {
      race.step(_stepDt);
      _acc -= _stepDt;
      steps++;
    }
    if (steps == 6) _acc = 0;
    _consumeEvents();
    renderer.update(dt);

    // countdown
    if (race.countdown > 0) {
      final int c = race.countdown.ceil().clamp(1, 3);
      if (c != _lastCount && race.countdown <= 3) {
        _lastCount = c;
        countdown.value = c;
        audio.play('tick');
        if (haptics) HapticFeedback.selectionClick();
      }
    } else if (_lastCount > 0) {
      _lastCount = 0;
      countdown.value = 0;
      _goT = 0.9;
      audio.play('go');
      if (haptics) HapticFeedback.mediumImpact();
    } else if (_goT > 0) {
      _goT -= dt;
      if (_goT <= 0) countdown.value = -1;
    }
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) banner.value = '';
    }
    turboWindow.value = p.drifting && p.driftMeter >= 0.68 && p.driftStage < 3;

    // end of race: the player crossed the line → autopilot, then close the field
    if (p.finished && !ended) {
      race.autopilotPlayer = true;
      _endT = _endT < 0 ? 3.0 : _endT - dt;
      if (_endT <= 0) {
        race.simulateToEnd();
        ended = true;
        finished.value = true;
      }
    } else if (!ended && race.time > 60 * 8) {
      // safety net: an 8-minute race closes with everyone's projected times
      race.simulateToEnd();
      ended = true;
      finished.value = true;
    }
  }

  void _say(String fa, String en, [double t = 1.3]) {
    banner.value = this.fa ? fa : en;
    _bannerT = t;
  }

  void _consumeEvents() {
    final List<int> ev = race.events;
    for (int i = 0; i + 1 < ev.length; i += 2) {
      final int e = ev[i];
      final int who = ev[i + 1];
      final bool me = who == 0;
      switch (e) {
        case CrEv.boost1:
        case CrEv.boost2:
        case CrEv.boost3:
          if (me) {
            audio.play('boost', volume: 0.5 + 0.15 * (e - CrEv.boost1));
            renderer.burst(e == CrEv.boost1 ? 0xFF5AB8FF : (e == CrEv.boost2 ? 0xFFFF9A1E : 0xFFFF3B2F), 10);
            if (e == CrEv.boost3) _say('توربو قرمز!', 'MAX TURBO!', 0.9);
            if (haptics) HapticFeedback.lightImpact();
          }
        case CrEv.driftFail:
          if (me) audio.play('fail', volume: 0.4);
        case CrEv.jumpBoost:
          if (me) {
            audio.play('boost', volume: 0.6);
            _say('پرش طلایی!', 'HANG TIME!', 0.9);
          }
        case CrEv.hop:
          if (me) audio.play('hop', volume: 0.35);
        case CrEv.box:
          if (me) audio.play('box');
        case CrEv.itemReady:
          if (me) audio.play('select', volume: 0.6);
        case CrEv.fruit:
          if (me) {
            audio.play('fruit', volume: 0.5);
            if (race.player.fruit == 10) _say('۱۰ انبه‌ستاره! سرعت بیشتر', '10 STAR-MANGOS! TOP SPEED UP', 1.4);
          }
        case CrEv.hit:
          if (me) {
            audio.play('hit');
            renderer.shake = 1;
            if (haptics) HapticFeedback.heavyImpact();
          }
        case CrEv.shieldPop:
          if (me) audio.play('box', volume: 0.6);
        case CrEv.fire:
          if (me) audio.play('fire', volume: 0.6);
        case CrEv.explode:
          renderer.boom(race.lastBoomZ, race.lastBoomX);
          final double d = (race.lastBoomZ - race.player.z).abs();
          if (d < 9000) audio.play('boom', volume: d < 3000 ? 0.8 : 0.4);
        case CrEv.bump:
          audio.play('bump', volume: 0.35);
        case CrEv.lap:
          if (me) {
            audio.play('lap');
            if (race.player.lap == CrTrack.laps) {
              _say('دور آخر!', 'FINAL LAP!', 1.6);
            } else {
              _say('دور ${CrText.digits('${race.player.lap}', true)}', 'LAP ${race.player.lap}', 1.2);
            }
          }
        case CrEv.finish:
          if (me) _say('پایان!', 'FINISH!', 2.5);
      }
    }
    ev.clear();
  }

  void dispose() {
    renderer.dispose();
    countdown.dispose();
    banner.dispose();
    finished.dispose();
    turboWindow.dispose();
  }
}

/// The race scene on the Flame engine: Flame's loop calls [update] each frame (the session advances the
/// fixed-step simulation) and [render] draws the road, sprites and HUD on one canvas.
class CrFlameGame extends FlameGame {
  CrFlameGame(this.session);
  final CrSession session;
  int frames = 0;

  @override
  ui.Color backgroundColor() => const ui.Color(0xFF66C3F2);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    session.renderer.layout(size.x, size.y);
  }

  @override
  void update(double dt) {
    if (dt > 0) {
      session.tick(dt);
      frames++;
    }
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    session.renderer.render(canvas);
    session.renderer.hud(canvas,
        padTop: session.padTop, padLeft: session.padLeft, padRight: session.padRight, fa: session.fa);
    super.render(canvas);
  }
}
