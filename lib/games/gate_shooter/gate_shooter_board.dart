import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../solo/solo_kit.dart';
import 'gs_art.dart';
import 'gs_audio.dart';
import 'gs_engine.dart';
import 'gs_fx.dart';
import 'gs_meta.dart';
import 'gs_render.dart';

/// دونده‌ی تیرانداز — crowd / gate shooter runner (Count Masters × Gun Rush style).
///
/// Drag to steer the squad, the squad fires on its own, numbered barrels and crates break into coins, every gate
/// pair is a choice (+ soldiers, × soldiers, power, fire rate, health — or a red trap), enemy squads walk in and
/// shoot back, and every third wave ends with a boss. Coins buy permanent upgrades on the start line.
class GateShooterBoard extends SoloBoard {
  const GateShooterBoard({super.key, required super.run});

  /// The engine of the most recently created board (render tests drive scenes through it).
  @visibleForTesting
  static GsEngine? debugEngine;

  @override
  State<GateShooterBoard> createState() => _GateShooterState();
}

class _GateShooterState extends SoloBoardState<GateShooterBoard> {
  late GsMeta meta;
  late GsEngine eng;
  final GsRenderer ren = GsRenderer();
  late final GsParticles parts = GsParticles(enabled: widget.run.launch.fancyEffects && !widget.run.launch.reducedMotion);
  late final GsAudio audio = GsAudio(on: widget.run.launch.soundOn);
  final List<GsPop> pops = <GsPop>[];
  final List<GsCoinFly> flies = <GsCoinFly>[];
  bool paused = false;
  bool _ended = false;
  bool _gameOverSent = false;
  double _overT = 0;
  double bossFlash = 0;
  double _kickT = 0;
  double _coinBump = 0;
  int _lastScore = -1;
  int _hapticMs = 0;
  int _earned = 0;
  bool _immersive = false;
  double _padTop = 0;
  final Stopwatch _sw = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    GsArt.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void reset() {
    meta = GsMeta.load();
    eng = GsEngine(seed: widget.run.seed, meta: meta);
    GateShooterBoard.debugEngine = eng;
    parts.parts.clear();
    pops.clear();
    flies.clear();
    paused = false;
    _ended = false;
    _gameOverSent = false;
    _overT = 0;
    _lastScore = -1;
    _earned = 0;
  }

  @override
  bool get simulating => (widget.run.playing || widget.run.over) && !paused;

  @override
  void dispose() {
    audio.dispose();
    if (_immersive) widget.run.launch.immersive?.value = false;
    super.dispose();
  }

  GsCam get _cam => GsCam(lastSize == Size.zero ? const Size(360, 800) : lastSize, eng.px * 0.32);

  Offset get _coinTarget => Offset((lastSize.width == 0 ? 360 : lastSize.width) - 52, _padTop + 160);

  void _haptic(void Function() f, [int gapMs = 90]) {
    final int now = _sw.elapsedMilliseconds;
    if (now - _hapticMs < gapMs) return;
    _hapticMs = now;
    f();
  }

  void _flyCoins(double x, double z, int n, {double y = 1}) {
    final Offset from = _cam.p(x, z, y);
    final int k = math.min(n, 8);
    for (int i = 0; i < k; i++) {
      final int v = n ~/ k + (i < n % k ? 1 : 0);
      flies.add(GsCoinFly(from + Offset((i - k / 2) * 6.0, -i * 3.0), _coinTarget, i * 0.05, v));
    }
  }

  void _pop(String t, Offset at, Color c, {double size = 28}) => pops.add(GsPop(t, at.dx, at.dy, c, size: size));

  // ------------------------------------------------------------------ input
  void _drag(double dx) {
    if (eng.phase == GsPhase.dying || eng.phase == GsPhase.over || paused) return;
    eng.steer += dx / (_cam.fd * 0.68);
    if (eng.phase == GsPhase.lobby && widget.run.playing) _go();
  }

  void _go() {
    if (eng.phase != GsPhase.lobby || !widget.run.playing) return;
    eng.start();
    HapticFeedback.mediumImpact();
    audio.play('gate_up');
  }

  void _buy(GsStat s) {
    if (eng.phase != GsPhase.lobby) return;
    if (meta.buy(s)) {
      eng.applyMeta(s);
      audio.play('upgrade');
      HapticFeedback.lightImpact();
      _pop(_statName(s), Offset(lastSize.width / 2, lastSize.height * 0.62), const Color(0xFF7CFF9A), size: 30);
      for (final GsSoldier sd in eng.soldiers) {
        parts.add(GsPart(GsPk.ring, sd.x, 0.05, sd.z, 0, 0, 0, 0.5, 0.4, const Color(0xFF7CFFB0)));
      }
      setState(() {});
    } else {
      HapticFeedback.selectionClick();
      _coinBump = 1;
    }
  }

  // ------------------------------------------------------------------ simulation
  @override
  void step(double dt) {
    if (!_immersive && widget.run.playing) {
      _immersive = true;
      widget.run.launch.immersive?.value = true;
    }
    final double before = eng.distance;
    eng.update(eng.phase == GsPhase.dying ? dt * 0.35 : dt);
    final double scroll = eng.distance - before;
    _events();
    parts.update(dt, scroll);
    bossFlash = math.max(0, bossFlash - dt * 8);
    _coinBump = math.max(0, _coinBump - dt * 4);
    // dust kicked by the boots
    if (eng.phase == GsPhase.run && eng.speed > 2) {
      _kickT -= dt;
      if (_kickT <= 0) {
        _kickT = 0.07;
        final GsSoldier s = eng.soldiers[parts.r.nextInt(eng.soldiers.length)];
        parts.kick(s.x, s.z);
      }
    }
    for (int i = pops.length - 1; i >= 0; i--) {
      final GsPop p = pops[i];
      p.life -= dt;
      p.y += p.vy * dt;
      if (p.life <= 0) pops.removeAt(i);
    }
    for (int i = flies.length - 1; i >= 0; i--) {
      final GsCoinFly f = flies[i];
      if (f.delay > 0) {
        f.delay -= dt;
        continue;
      }
      f.t += dt * 1.9;
      if (f.t >= 1) {
        flies.removeAt(i);
        _coinBump = 1;
        audio.play('coin');
      }
    }
    if (eng.score != _lastScore) {
      _lastScore = eng.score;
      widget.run.set(eng.score);
    }
    if (eng.phase == GsPhase.over) {
      if (!_ended) {
        _ended = true;
        _earned = eng.coins;
        meta.coins += eng.coins;
        meta.save();
      }
      _overT += dt;
      if (_overT > 1.6 && !_gameOverSent) {
        _gameOverSent = true;
        widget.run.gameOver();
      }
    }
  }

  void _events() {
    if (eng.events.isEmpty) return;
    final GsCam cam = _cam;
    for (final GsEvent e in eng.events) {
      switch (e.type) {
        case GsEv.shot:
          audio.play('shot', gain: 0.8);
        case GsEv.hit:
          parts.impact(e.x, e.y, e.z, const Color(0xFF9FF6FF));
          audio.play('hit', gain: 0.45);
        case GsEv.gateHit:
          parts.impact(e.x, 1.6, e.z, const Color(0xFFDDF6FF));
        case GsEv.kill:
          parts.poof(e.x, e.z, const Color(0xFFD23A33));
          audio.play('pop');
          if (e.value > 0) _flyCoins(e.x, e.z, 1);
        case GsEv.explode:
          parts.explosion(e.x, e.z, scale: 1.15);
          fx.shake(7);
          audio.play('explode');
          _haptic(HapticFeedback.mediumImpact, 120);
          if (e.value > 0) {
            _flyCoins(e.x, e.z, e.value.round());
            _pop('+${gsFa(e.value.round())}', cam.p(e.x, e.z, 2.6), const Color(0xFFFFD34E), size: 24);
          }
        case GsEv.smash:
          parts.smash(e.x, e.z);
          fx.shake(3.5);
          audio.play('explode', gain: 0.55);
          _haptic(HapticFeedback.lightImpact, 100);
          if (e.value > 0) {
            _flyCoins(e.x, e.z, e.value.round());
            _pop('+${gsFa(e.value.round())}', cam.p(e.x, e.z, 2.4), const Color(0xFFFFD34E), size: 24);
          }
        case GsEv.coin:
          break;
        case GsEv.gateGood:
          audio.play('gate_up');
          _haptic(HapticFeedback.selectionClick, 60);
          _pop(e.text ?? '', cam.p(eng.px, 0, 3.2), const Color(0xFF6FE7FF), size: 38);
          for (final GsSoldier s in eng.soldiers) {
            if (parts.r.nextDouble() < 0.5) parts.add(GsPart(GsPk.ring, s.x, 0.05, s.z, 0, 0, 0, 0.45, 0.35, const Color(0xFF7FE8FF)));
          }
          parts.add(GsPart(GsPk.flash, eng.px, 1.2, 0.3, 0, 0, 0, 0.2, 2.4, const Color(0xFF7FE8FF)));
        case GsEv.gateBad:
          audio.play('gate_down');
          fx.shake(4);
          _haptic(HapticFeedback.mediumImpact, 60);
          _pop(e.text ?? '', cam.p(eng.px, 0, 3.2), const Color(0xFFFF5A6A), size: 38);
          parts.add(GsPart(GsPk.flash, eng.px, 1.2, 0.3, 0, 0, 0, 0.2, 2.4, const Color(0xFFFF4A4A)));
        case GsEv.soldierLost:
          parts.poof(e.x, e.z, const Color(0xFF2F6BE0), scale: 0.8);
          audio.play('pop', gain: 0.8);
        case GsEv.hurt:
          fx.flashScreen(const Color(0xFFFF2A3A), 0.18);
          fx.shake(5);
          audio.play('hurt');
          _haptic(HapticFeedback.heavyImpact, 160);
          if (e.value >= 2) _pop('−${gsFa(e.value.round())}', cam.p(eng.px, 0, 2.8), const Color(0xFFFF6B6B), size: 22);
        case GsEv.enemyShot:
          break;
        case GsEv.bossIntro:
          audio.play('boss');
          fx.shake(10);
          _haptic(HapticFeedback.heavyImpact, 0);
        case GsEv.bossShot:
          bossFlash = 1;
          audio.play('shot', gain: 1.3);
        case GsEv.bossDown:
          for (int i = 0; i < 3; i++) {
            parts.explosion(e.x + (i - 1) * 1.4, e.z + i * 0.4, scale: 1.8, debris: const Color(0xFF7A2A22));
          }
          fx.shake(16);
          fx.flashScreen(const Color(0xFFFFF1C0), 0.5);
          fx.confetti(Offset(lastSize.width / 2, lastSize.height * 0.4), count: 60);
          audio.play('explode');
          audio.play('wave');
          _haptic(HapticFeedback.heavyImpact, 0);
          _flyCoins(e.x, e.z, 12, y: 3);
          _pop('+${gsFa(e.value.round())}', cam.p(e.x, e.z, 6), const Color(0xFFFFD34E), size: 34);
        case GsEv.waveClear:
          audio.play('wave');
          fx.confetti(Offset(lastSize.width / 2, lastSize.height * 0.3), count: 40);
          _haptic(HapticFeedback.mediumImpact, 0);
        case GsEv.dead:
          parts.explosion(eng.px, 0.2, scale: 1.6, debris: const Color(0xFF2F6BE0));
          for (final GsSoldier s in eng.soldiers) {
            parts.poof(s.x, s.z, const Color(0xFF2F6BE0));
          }
          eng.soldiers.clear();
          fx.shake(14);
          fx.flashScreen(const Color(0xFFFF3020), 0.45);
          audio.play('explode');
          audio.play('hurt');
          _haptic(HapticFeedback.heavyImpact, 0);
      }
    }
    eng.events.clear();
  }

  // ------------------------------------------------------------------ painting
  @override
  void paint(Canvas canvas, Size size) {
    ren.paint(canvas, size, eng, parts, clock, bossFlash: bossFlash);
    _paintFlies(canvas);
    _paintPops(canvas);
    _paintBanner(canvas, size);
    if (eng.phase == GsPhase.lobby && widget.run.playing) _paintDragHint(canvas, size);
  }

  void _paintFlies(Canvas c) {
    final ui.Image? coin = GsArt.get('coin');
    for (final GsCoinFly f in flies) {
      if (f.delay > 0) continue;
      final double t = Curves.easeInCubic.transform(f.t.clamp(0, 1));
      final double u = 1 - t;
      final Offset p = f.from * (u * u) + f.ctrl * (2 * u * t) + f.to * (t * t);
      final double r = 11 - 3 * t;
      if (coin != null) {
        c.drawImageRect(coin, Rect.fromLTWH(0, 0, coin.width.toDouble(), coin.height.toDouble()),
            Rect.fromCenter(center: p, width: r * 2, height: r * 2.1), Paint()..filterQuality = FilterQuality.medium);
      } else {
        c.drawCircle(p, r, Paint()..color = const Color(0xFFFFC83A));
      }
    }
  }

  void _paintPops(Canvas c) {
    for (final GsPop p in pops) {
      final double k = (p.life / p.max).clamp(0.0, 1.0);
      final double age = 1 - k;
      final double sc = age < 0.15 ? 0.6 + age / 0.15 * 0.6 : 1.2 - math.min(0.2, (age - 0.15));
      c.save();
      c.translate(p.x, p.y);
      c.scale(sc);
      final TextPainter o = ren.text(p.text, p.size, p.color, stroke: const Color(0xE0101828), strokeW: p.size * 0.2);
      final TextPainter f = ren.text(p.text, p.size, Color.fromRGBO((p.color.r * 255).round(), (p.color.g * 255).round(), (p.color.b * 255).round(), 1));
      final Offset tl = Offset(-f.width / 2, -f.height / 2);
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, math.min(1, k * 2.2)));
      o.paint(c, tl);
      f.paint(c, tl);
      c.restore();
      c.restore();
    }
  }

  void _paintBanner(Canvas c, Size size) {
    if (eng.bannerT <= 0) return;
    final double t = eng.bannerT;
    final double inK = Curves.easeOutBack.transform(((1.9 - t) / 0.35).clamp(0, 1));
    final double outK = (t / 0.35).clamp(0.0, 1.0);
    final double a = math.min(1, outK);
    final Offset at = Offset(size.width / 2, size.height * 0.37);
    final bool boss = eng.banner.contains('غول');
    final Color col = boss ? const Color(0xFFFF6A3D) : const Color(0xFFFFD34E);
    // ribbon
    final Rect rib = Rect.fromCenter(center: at, width: size.width * 0.86 * inK.clamp(0, 1.1), height: 64);
    c.drawRRect(
        RRect.fromRectAndRadius(rib, const Radius.circular(18)),
        Paint()
          ..shader = ui.Gradient.linear(rib.centerLeft, rib.centerRight, <Color>[
            const Color(0x00141A2A),
            const Color(0xD8141A2A).withValues(alpha: 0.85 * a),
            const Color(0x00141A2A),
          ], <double>[0, 0.5, 1]));
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(0.7 + 0.3 * inK);
    final TextPainter o = ren.text(eng.banner, 44, col, stroke: const Color(0xFF2A1405), strokeW: 9);
    final TextPainter f = ren.text(eng.banner, 44, col,
        shadows: <Shadow>[Shadow(color: col.withValues(alpha: 0.9), blurRadius: 18)]);
    c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
    o.paint(c, Offset(-o.width / 2, -o.height / 2));
    f.paint(c, Offset(-f.width / 2, -f.height / 2));
    c.restore();
    c.restore();
  }

  void _paintDragHint(Canvas c, Size size) {
    final double t = clock;
    final double x = size.width / 2 + math.sin(t * 2.6) * size.width * 0.18;
    final double y = size.height * 0.64;
    // track
    final Rect tr = Rect.fromCenter(center: Offset(size.width / 2, y + 26), width: size.width * 0.5, height: 8);
    c.drawRRect(RRect.fromRectAndRadius(tr, const Radius.circular(4)), Paint()..color = const Color(0x66FFFFFF));
    // finger
    c.drawCircle(Offset(x, y + 26), 16, Paint()..color = const Color(0x55FFFFFF));
    c.drawCircle(Offset(x, y + 26), 9, Paint()..color = const Color(0xFFFFFFFF));
    final TextPainter o = ren.text(widget.run.launch.isFa ? 'برای شروع بکش' : 'DRAG TO START', 24, Colors.white,
        stroke: const Color(0xFF1A2233), strokeW: 5);
    final TextPainter f = ren.text(widget.run.launch.isFa ? 'برای شروع بکش' : 'DRAG TO START', 24, Colors.white);
    final double k = 0.85 + 0.15 * math.sin(t * 4).abs();
    c.save();
    c.translate(size.width / 2, y - 12);
    c.scale(k);
    o.paint(c, Offset(-o.width / 2, -o.height / 2));
    f.paint(c, Offset(-f.width / 2, -f.height / 2));
    c.restore();
  }

  // ------------------------------------------------------------------ widgets
  String _statName(GsStat s) => switch (s) {
        GsStat.power => widget.run.launch.isFa ? 'قدرت' : 'Power',
        GsStat.soldiers => widget.run.launch.isFa ? 'سرباز' : 'Soldiers',
        GsStat.bullets => widget.run.launch.isFa ? 'تیر' : 'Bullets',
        GsStat.rate => widget.run.launch.isFa ? 'سرعت' : 'Speed',
      };

  String _tx(String fa, String en) => widget.run.launch.isFa ? fa : en;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    _padTop = pad.top;
    final Widget world = super.build(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(fit: StackFit.expand, children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (DragUpdateDetails d) => _drag(d.delta.dx),
          onTap: _go,
          child: world,
        ),
        AnimatedBuilder(animation: frame, builder: (BuildContext c, _) => _hud(c, pad)),
      ]),
    );
  }

  Widget _hud(BuildContext context, EdgeInsets pad) {
    final bool playing = widget.run.playing || widget.run.over;
    final bool lobby = eng.phase == GsPhase.lobby;
    final bool over = eng.phase == GsPhase.over;
    final double w = MediaQuery.sizeOf(context).width;
    return Stack(children: <Widget>[
      if (playing) ...<Widget>[
        Positioned(
          top: pad.top + 10,
          left: 10,
          child: Row(children: <Widget>[
            _glassButton(Icons.pause_rounded, () {
              if (eng.phase == GsPhase.dying || eng.phase == GsPhase.over) return;
              setState(() => paused = true);
              HapticFeedback.selectionClick();
            }),
            const SizedBox(width: 8),
            _infinityChip(),
          ]),
        ),
        Positioned(
          top: pad.top + 10,
          right: 10,
          child: _glassButton(Icons.close_rounded, () => Navigator.of(context).maybePop()),
        ),
        Positioned(
          top: pad.top + 92,
          left: 10,
          child: _waveChip(math.min(170, w * 0.45)),
        ),
        Positioned(
          top: pad.top + 92,
          right: 10,
          child: _healthChip(math.min(170, w * 0.45)),
        ),
        Positioned(
          top: pad.top + 150,
          left: 0,
          right: 0,
          child: Center(child: _timerChip()),
        ),
        Positioned(top: pad.top + 150, right: 10, child: _coinChip()),
        if (eng.boss != null)
          Positioned(top: pad.top + 196, left: w * 0.15, right: w * 0.15, child: _bossBar()),
      ],
      if (playing && !over)
        Positioned(
          left: 0,
          right: 0,
          bottom: pad.bottom + 14,
          child: _statGrid(lobby),
        ),
      if (over) Positioned(left: 16, right: 16, bottom: pad.bottom + 24, child: _results()),
      if (paused) Positioned.fill(child: _pauseOverlay()),
    ]);
  }

  BoxDecoration _glass([double r = 18]) => BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xD9454B57), Color(0xE62A2F3A)],
        ),
        border: Border.all(color: const Color(0x40FFFFFF)),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 4))],
      );

  TextStyle _t(double size, {Color color = Colors.white, FontWeight w = FontWeight.w800}) => TextStyle(
        fontFamily: 'Lalezar',
        fontSize: size,
        height: 1.15,
        color: color,
        fontWeight: w,
        shadows: const <Shadow>[Shadow(color: Color(0x99000000), offset: Offset(0, 1.5), blurRadius: 2)],
      );

  Widget _glassButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: _glass(14).copyWith(
            gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF2B303A), Color(0xFF14171D)]),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      );

  Widget _infinityChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: <Color>[Color(0xFFC9B8FF), Color(0xFFA894FF)]),
          border: Border.all(color: const Color(0xFF3B2A7A), width: 2),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x553B2A7A), blurRadius: 8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(_tx('بی‌پایان', 'ENDLESS'), textDirection: TextDirection.rtl, style: _t(14, color: const Color(0xFF2A1C66)).copyWith(shadows: <Shadow>[])),
          const SizedBox(width: 6),
          const Text('∞', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2A1C66), height: 1.1)),
        ]),
      );

  Widget _waveChip(double width) {
    final String meters = gsFa(eng.waveMeters.round());
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
      decoration: _glass(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: <Widget>[
        Text(_tx('موج ${gsFa(eng.wave)}   $meters متر', 'WAVE ${eng.wave}   ${eng.waveMeters.round()} m'),
            textDirection: TextDirection.rtl, textAlign: TextAlign.center, style: _t(15)),
        const SizedBox(height: 5),
        _bar(eng.waveProgress, const <Color>[Color(0xFFFFB13D), Color(0xFFFF7A1A)], 6, bg: const Color(0x66FFFFFF)),
      ]),
    );
  }

  Widget _healthChip(double width) {
    final double k = (eng.health / eng.maxHealth).clamp(0.0, 1.0);
    final List<Color> cols = k > 0.5
        ? const <Color>[Color(0xFF7CF27A), Color(0xFF2FBF55)]
        : (k > 0.25 ? const <Color>[Color(0xFFFFD34E), Color(0xFFFF9D2E)] : const <Color>[Color(0xFFFF6B6B), Color(0xFFE0102A)]);
    final double beat = 1 + 0.12 * math.max(0, math.sin(clock * (k < 0.3 ? 10 : 4))) * (k < 0.3 ? 1 : 0.3);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      decoration: _glass(),
      child: Row(children: <Widget>[
        Text(gsFa(eng.health.ceil()), style: _t(16)),
        const SizedBox(width: 8),
        Expanded(child: _bar(k, cols, 10, bg: const Color(0x55000000))),
        const SizedBox(width: 8),
        Transform.scale(
          scale: beat,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: <Color>[Color(0xFFFF6B7A), Color(0xFFE01E3A)]),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 17),
          ),
        ),
      ]),
    );
  }

  Widget _bar(double k, List<Color> cols, double h, {required Color bg}) => Container(
        height: h,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(h)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: k.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(h),
              gradient: LinearGradient(colors: cols),
              boxShadow: <BoxShadow>[BoxShadow(color: cols.last.withValues(alpha: 0.5), blurRadius: 6)],
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: h * 0.35,
                margin: EdgeInsets.symmetric(horizontal: h * 0.4, vertical: h * 0.12),
                decoration: BoxDecoration(color: const Color(0x55FFFFFF), borderRadius: BorderRadius.circular(h)),
              ),
            ),
          ),
        ),
      );

  Widget _timerChip() {
    final int sec = eng.time.floor();
    final String mm = (sec ~/ 60).toString().padLeft(2, '0');
    final String ss = (sec % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: _glass(20),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Text(gsFa('$mm:$ss').replaceAll('٫', ':'), style: _t(18)),
        const SizedBox(width: 8),
        const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
      ]),
    );
  }

  Widget _coinChip() {
    int inFlight = 0;
    for (final GsCoinFly f in flies) {
      inFlight += f.value;
    }
    final int total = eng.phase == GsPhase.lobby || _ended ? meta.coins : meta.coins + eng.coins - inFlight;
    return Transform.scale(
      scale: 1 + 0.18 * _coinBump,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
        decoration: _glass(20),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(gsFa(gsCompact(total)), style: _t(15, color: const Color(0xFFFFE08A))),
          const SizedBox(width: 5),
          _coinIcon(22),
        ]),
      ),
    );
  }

  Widget _coinIcon(double s) {
    final ui.Image? im = GsArt.get('coin');
    if (im == null) {
      return Container(width: s, height: s, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFC83A)));
    }
    return SizedBox(width: s, height: s, child: RawImage(image: im, fit: BoxFit.contain, filterQuality: FilterQuality.medium));
  }

  Widget _bossBar() {
    final GsTarget b = eng.boss!;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: _glass(16).copyWith(border: Border.all(color: const Color(0xAAFF5A3A), width: 1.5)),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Text(_tx('غول موج ${gsFa(eng.wave)}  ·  ${gsFa(b.hp.ceil())}', 'BOSS  ·  ${b.hp.ceil()}'),
            textDirection: TextDirection.rtl, style: _t(14, color: const Color(0xFFFFC2A8))),
        const SizedBox(height: 4),
        _bar(b.hp / b.maxHp, const <Color>[Color(0xFFFF8A3A), Color(0xFFE01E2A)], 10, bg: const Color(0x66000000)),
      ]),
    );
  }

  static const Map<GsStat, (IconData, Color, Color)> _statStyle = <GsStat, (IconData, Color, Color)>{
    GsStat.power: (Icons.shield_outlined, Color(0xFFFF5A6A), Color(0xFFE0203A)),
    GsStat.soldiers: (Icons.groups_rounded, Color(0xFF5AA8FF), Color(0xFF2F6BE0)),
    GsStat.bullets: (Icons.gps_fixed_rounded, Color(0xFFB08CFF), Color(0xFF7A4BE0)),
    GsStat.rate: (Icons.bolt_rounded, Color(0xFFFFD34E), Color(0xFFFF9D2E)),
  };

  String _statValue(GsStat s) => switch (s) {
        GsStat.power => eng.phase == GsPhase.lobby ? gsFa(meta.level(s)) : gsFa((eng.power * 10).round() / 10),
        GsStat.soldiers => gsFa(eng.soldiers.length),
        GsStat.bullets => gsFa(eng.streams),
        GsStat.rate => gsFa(eng.rate.toStringAsFixed(1)),
      };

  Widget _statGrid(bool lobby) {
    Widget chip(GsStat s) {
      final (IconData icon, Color a, Color b) = _statStyle[s]!;
      final bool pulse = eng.pulsed == s && eng.statPulse > 0;
      final bool can = lobby && meta.canBuy(s);
      final Widget body = Container(
        width: 112,
        height: lobby ? 62 : 46,
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
        decoration: _glass(16).copyWith(
          border: Border.all(color: can ? const Color(0xFF7CFF9A) : const Color(0x40FFFFFF), width: can ? 1.8 : 1),
          boxShadow: <BoxShadow>[
            if (can) BoxShadow(color: const Color(0xFF7CFF9A).withValues(alpha: 0.25 + 0.15 * math.sin(clock * 5)), blurRadius: 12),
            const BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Row(children: <Widget>[
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
              Text('${_statValue(s)} ${_statName(s)}', textDirection: TextDirection.rtl, maxLines: 1, overflow: TextOverflow.fade, softWrap: false,
                  style: _t(15)),
              if (lobby)
                meta.maxed(s)
                    ? Text(_tx('حداکثر', 'MAX'), style: _t(12, color: const Color(0xFFB8C2D6)))
                    : Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                        Text(gsFa(gsCompact(meta.cost(s))),
                            style: _t(13, color: can ? const Color(0xFFFFE08A) : const Color(0xFFFF8A8A))),
                        const SizedBox(width: 3),
                        _coinIcon(15),
                      ]),
            ]),
          ),
          const SizedBox(width: 6),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[a, b]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ]),
      );
      return GestureDetector(
        onTap: lobby ? () => _buy(s) : null,
        child: Transform.scale(scale: pulse ? 1 + 0.12 * eng.statPulse : 1, child: body),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      if (lobby)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(_tx('ارتقا بده و بعد بکش تا بدوی', 'Upgrade, then drag to run'), textDirection: TextDirection.rtl, style: _t(14, color: const Color(0xFFFFF3D6))),
        ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[chip(GsStat.power), const SizedBox(width: 8), chip(GsStat.soldiers)]),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[chip(GsStat.bullets), const SizedBox(width: 8), chip(GsStat.rate)]),
    ]);
  }

  Widget _results() {
    final double k = Curves.easeOutBack.transform(((_overT) / 0.5).clamp(0, 1));
    Widget row(String fa, String en, String v, IconData icon, Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: <Widget>[
            Text(v, style: _t(18, color: c)),
            const Spacer(),
            Text(_tx(fa, en), textDirection: TextDirection.rtl, style: _t(16, color: const Color(0xFFDDE4F0))),
            const SizedBox(width: 8),
            Icon(icon, color: c, size: 20),
          ]),
        );
    return Transform.translate(
      offset: Offset(0, 80 * (1 - k)),
      child: Opacity(
        opacity: k.clamp(0, 1),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          decoration: _glass(22).copyWith(border: Border.all(color: const Color(0x66FFD34E), width: 1.4)),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(_tx('گزارش ماموریت', 'MISSION REPORT'), textDirection: TextDirection.rtl, style: _t(20, color: const Color(0xFFFFD34E))),
            const SizedBox(height: 6),
            row('مسافت', 'Distance', '${gsFa(eng.distance.round())} ${_tx('متر', 'm')}', Icons.straighten_rounded, Colors.white),
            row('موج', 'Wave', gsFa(eng.wave), Icons.flag_rounded, const Color(0xFFFFB13D)),
            row('نابودی‌ها', 'Kills', gsFa(eng.kills), Icons.local_fire_department_rounded, const Color(0xFFFF6B6B)),
            if (eng.bossesDown > 0) row('غول‌ها', 'Bosses', gsFa(eng.bossesDown), Icons.whatshot_rounded, const Color(0xFFFF8A3A)),
            row('سکه‌ی این دور', 'Coins earned', '+${gsFa(_earned)}', Icons.monetization_on_rounded, const Color(0xFFFFE08A)),
          ]),
        ),
      ),
    );
  }

  Widget _pauseOverlay() => GestureDetector(
        onTap: () => setState(() => paused = false),
        child: Container(
          color: const Color(0xAA0A0E18),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(_tx('مکث', 'PAUSED'), style: _t(44, color: const Color(0xFFFFD34E))),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(colors: <Color>[Color(0xFF7CF27A), Color(0xFF2FBF55)]),
                boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x662FBF55), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(_tx('ادامه', 'RESUME'), style: _t(22)),
                const SizedBox(width: 6),
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              ]),
            ),
          ]),
        ),
      );
}
