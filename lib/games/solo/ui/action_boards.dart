import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../arcade_kit/arcade_fx.dart';
import '../core/solo_rules_b.dart';
import '../core/solo_rules_c.dart';
import '../solo_kit.dart';
import 'solo_art.dart';

// =====================================================================================
// ENDLESS RUNNER — synthwave highway: perspective neon grid, setting sun, 3D barriers,
// animated runner with lean + speed lines, crash sparks and distance milestones.
// =====================================================================================
class RunnerBoard extends SoloBoard {
  const RunnerBoard({super.key, required super.run});
  @override
  RunnerBoardState createState() => RunnerBoardState();
}

class RunnerBoardState extends SoloBoardState<RunnerBoard> {
  late RunnerWorld world;
  double _laneVisual = 1;
  double _scroll = 0;
  int _milestone = 0;
  bool _crashed = false;

  @override
  void reset() {
    world = RunnerWorld(seed: widget.run.seed);
    _laneVisual = 1;
    _scroll = 0;
    _milestone = 0;
    _crashed = false;
    widget.run.set(0);
  }

  @override
  void step(double dt) {
    world.update(dt);
    _scroll += world.speed * dt;
    _laneVisual = LuxeBoardPainter.lerp(_laneVisual, world.lane.toDouble(), 1 - math.pow(0.0004, dt).toDouble());
    widget.run.set(world.metres);
    final int m = world.metres ~/ 100;
    if (m > _milestone && lastSize != Size.zero) {
      _milestone = m;
      fx.text('${m * 100} m', Offset(lastSize.width / 2, lastSize.height * 0.30), const Color(0xFFFFD36B), size: 30);
      fx.flashScreen(const Color(0xFFFF4FD8), 0.12);
    }
    if (world.crashed && !_crashed) {
      _crashed = true;
      final Offset p = _playerPos(lastSize);
      fx.burst(p, const Color(0xFFFF4F7A), count: 46, speed: 520, life: 0.9, size: 5, gravity: 600);
      fx.burst(p, const Color(0xFFFFE08A), count: 24, speed: 300, life: 0.7, size: 4, kind: ParticleKind.orb);
      fx.burst(p, const Color(0xFF6B5A8C), count: 14, speed: 90, life: 1.2, size: 16, kind: ParticleKind.smoke);
      fx.ring(p, const Color(0xFFFF4FD8), size: 30);
      fx.shake(16);
      fx.flashScreen(const Color(0xFFFF2E63), 0.45);
    }
    if (world.crashed) widget.run.gameOver();
  }

  // ---- projection: d = cells ahead of the player (0 at the player, 6 at spawn).
  double _horizon(Size s) => s.height * 0.36;
  double _playerY(Size s) => s.height - 128;
  double _scale(double d) => 1 / (1 + math.max(-0.2, d) * 0.62);
  double _yAt(Size s, double d) => _horizon(s) + (_playerY(s) - _horizon(s)) * _scale(d);
  double _half(Size s, double d) => s.width * 0.02 + s.width * 0.5 * _scale(d);
  double _laneX(Size s, double d, double lane) => s.width / 2 + (lane - 1) * _half(s, d) * 2 / 3;
  Offset _playerPos(Size s) => Offset(_laneX(s, 0, _laneVisual), _playerY(s));

  @override
  void paint(Canvas canvas, Size size) {
    final double hz = _horizon(size);
    final double py = _playerY(size);
    final double t = clock;

    // Sky, stars, sun, mountains.
    SoloArt.sky(canvas, Rect.fromLTWH(0, 0, size.width, hz + 1),
        const <Color>[Color(0xFF07031A), Color(0xFF1B0B3D), Color(0xFF4A0F5C), Color(0xFFB8236E)], <double>[0, 0.45, 0.8, 1]);
    SoloArt.stars(canvas, Rect.fromLTWH(0, 0, size.width, hz * 0.7), t, count: 60, seed: 11);
    SoloArt.synthSun(canvas, Offset(size.width / 2, hz), size.width * 0.27, const Color(0xFFFFE36B), const Color(0xFFFF2E8C), t);
    SoloArt.mountains(canvas, size, hz, const Color(0xFF180A30), const Color(0xFF2B0E4A), _scroll * 10, 5);
    SoloArt.neonLine(canvas, Offset(0, hz), Offset(size.width, hz), const Color(0xFFFF4FD8), width: 1.2, glow: 10);

    // Ground plane.
    canvas.drawRect(
      Rect.fromLTRB(0, hz, size.width, size.height),
      Paint()..shader = ui.Gradient.linear(Offset(0, hz), Offset(0, size.height), const <Color>[Color(0xFF1A0730), Color(0xFF07020F)]),
    );
    // Grid: radial lines through the vanishing point, horizontal lines scrolling toward us.
    final Paint grid = Paint()
      ..color = const Color(0xFFB04BFF).withValues(alpha: 0.32)
      ..strokeWidth = 1;
    for (int i = -12; i <= 12; i++) {
      final double xb = size.width / 2 + i * size.width * 0.16;
      canvas.drawLine(Offset(size.width / 2 + i * size.width * 0.006, hz), Offset(xb, size.height), grid);
    }
    const double spacing = 0.7;
    final double phase = _scroll % spacing;
    for (int k = 0; k < 22; k++) {
      final double d = k * spacing - phase - 0.25;
      final double y = _yAt(size, d);
      if (y > size.height) continue;
      final double a = (1 - (d / 14)).clamp(0.0, 1.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          Paint()
            ..color = const Color(0xFFB04BFF).withValues(alpha: 0.12 + 0.35 * a * a)
            ..strokeWidth = 0.6 + 1.4 * a);
    }

    // Road surface with edge rails.
    final double farD = 40;
    final Path road = Path()
      ..moveTo(size.width / 2 - _half(size, farD), _yAt(size, farD))
      ..lineTo(size.width / 2 + _half(size, farD), _yAt(size, farD))
      ..lineTo(size.width / 2 + _half(size, -0.2) * 1.05, size.height)
      ..lineTo(size.width / 2 - _half(size, -0.2) * 1.05, size.height)
      ..close();
    canvas.drawPath(road,
        Paint()..shader = ui.Gradient.linear(Offset(0, hz), Offset(0, size.height), const <Color>[Color(0xFF150A22), Color(0xFF0B0712)]));
    // Sun reflection on the road.
    canvas.save();
    canvas.clipPath(road);
    SoloArt.paintBloom(canvas, Offset(size.width / 2, hz + 30), size.width * 0.5, const Color(0xFFFF2E8C), 0.18);
    canvas.restore();
    for (final int side in <int>[-1, 1]) {
      SoloArt.neonLine(canvas, Offset(size.width / 2 + side * _half(size, farD), _yAt(size, farD)),
          Offset(size.width / 2 + side * _half(size, -0.2) * 1.05, size.height), const Color(0xFFFF4FD8), width: 2.4, glow: 12);
    }
    // Lane dashes.
    for (int k = 0; k < 26; k++) {
      final double d0 = k * 0.55 - (_scroll % 0.55) - 0.2;
      final double d1 = d0 + 0.26;
      if (d0 > 14) break;
      for (final double lane in <double>[0.5, 1.5]) {
        final Offset a = Offset(_laneX(size, d0, lane), _yAt(size, d0));
        final Offset b = Offset(_laneX(size, d1, lane), _yAt(size, d1));
        canvas.drawLine(a, b,
            Paint()
              ..color = const Color(0xFF5CF2FF).withValues(alpha: 0.85 * _scale(d0))
              ..strokeWidth = 4 * _scale(d0)
              ..strokeCap = StrokeCap.round);
      }
    }

    // Obstacles, far first.
    final List<RunnerObstacle> obs = List<RunnerObstacle>.of(world.obstacles)..sort((RunnerObstacle a, RunnerObstacle b) => b.distance.compareTo(a.distance));
    for (final RunnerObstacle o in obs) {
      if (o.distance < -0.15) continue;
      final double s = _scale(o.distance);
      final double y = _yAt(size, o.distance);
      final double x = _laneX(size, o.distance, o.lane.toDouble());
      final double w = _half(size, o.distance) * 2 / 3 * 0.82;
      final double h = 58 * o.height * s * (size.height / 800);
      final double depth = 14 * s;
      final double fade = ((6 - o.distance) / 1.2).clamp(0.0, 1.0);
      final bool tall = o.height > 1.2;
      // Glow pool on the road.
      SoloArt.paintBloom(canvas, Offset(x, y), w * 0.9, tall ? const Color(0xFFFF2E63) : const Color(0xFFFFA23A), 0.22 * fade);
      final Rect front = Rect.fromLTWH(x - w / 2, y - h, w, h);
      // Top face.
      final Path top = Path()
        ..moveTo(front.left, front.top)
        ..lineTo(front.right, front.top)
        ..lineTo(front.right - depth * 0.5, front.top - depth)
        ..lineTo(front.left + depth * 0.5, front.top - depth)
        ..close();
      canvas.saveLayer(front.inflate(depth + 30), Paint()..color = Color.fromRGBO(0, 0, 0, fade));
      if (tall) {
        // Laser gate: metal frame with a pulsing energy panel.
        final RRect panel = RRect.fromRectAndRadius(front, Radius.circular(3 * s));
        canvas.drawRRect(panel,
            Paint()
              ..shader = ui.Gradient.linear(front.topCenter, front.bottomCenter,
                  <Color>[const Color(0xFFFF2E63).withValues(alpha: 0.55), const Color(0xFF7A0830).withValues(alpha: 0.75)]));
        for (int i = 0; i < 5; i++) {
          final double ly = front.top + front.height * ((i + 0.5) / 5 + 0.04 * math.sin(t * 9 + i));
          SoloArt.neonLine(canvas, Offset(front.left + 3 * s, ly), Offset(front.right - 3 * s, ly), const Color(0xFFFF5C8A),
              width: 1.6 * s, glow: 8 * s);
        }
        final Paint frame = Paint()..color = const Color(0xFF2A2433);
        canvas.drawRect(Rect.fromLTWH(front.left - 5 * s, front.top - 4 * s, 7 * s, h + 4 * s), frame);
        canvas.drawRect(Rect.fromLTWH(front.right - 2 * s, front.top - 4 * s, 7 * s, h + 4 * s), frame);
        canvas.drawRect(Rect.fromLTWH(front.left - 5 * s, front.top - 6 * s, w + 10 * s, 6 * s), frame);
        canvas.drawCircle(Offset(front.left - 1.5 * s, front.top - 3 * s), 2.4 * s, Paint()..color = const Color(0xFFFF2E63));
        canvas.drawCircle(Offset(front.right + 1.5 * s, front.top - 3 * s), 2.4 * s, Paint()..color = const Color(0xFFFF2E63));
      } else {
        canvas.drawPath(top, Paint()..color = const Color(0xFFFFC66B));
        SoloArt.hazardStripes(canvas, RRect.fromRectAndRadius(front, Radius.circular(3 * s)), const Color(0xFFFF9A2E),
            const Color(0xFF1C1014), band: 9 * s);
        canvas.drawRect(Rect.fromLTWH(front.left, front.bottom - h * 0.18, w, h * 0.18), Paint()..color = const Color(0x88000000));
        // Warning beacons.
        final double blink = (math.sin(t * 10 + o.lane) > 0) ? 1 : 0.35;
        for (final double fx0 in <double>[0.18, 0.82]) {
          final Offset b = Offset(front.left + w * fx0, front.top - depth * 0.5 - 3 * s);
          SoloArt.paintBloom(canvas, b, 10 * s, const Color(0xFFFFB13B), 0.7 * blink);
          canvas.drawCircle(b, 2.6 * s, Paint()..color = const Color(0xFFFFF1C2));
        }
      }
      canvas.restore();
    }

    // Speed lines once the run gets fast.
    final double sp = ((world.speed - 2.4) / 2.8).clamp(0.0, 1.0);
    if (sp > 0) {
      final math.Random r = math.Random((clock * 30).floor());
      for (int i = 0; i < 14; i++) {
        final double ang = r.nextDouble() * math.pi * 2;
        final double r0 = size.width * (0.45 + r.nextDouble() * 0.3);
        final Offset c = Offset(size.width / 2, hz);
        final Offset a = c + Offset(math.cos(ang), math.sin(ang).abs() * 1.2) * r0;
        final Offset b = c + Offset(math.cos(ang), math.sin(ang).abs() * 1.2) * (r0 + 60 + r.nextDouble() * 80);
        canvas.drawLine(a, b, Paint()
          ..color = Colors.white.withValues(alpha: 0.18 * sp)
          ..strokeWidth = 1.4);
      }
    }

    _paintRunner(canvas, size, py);

    SoloArt.bigLabel(canvas, '${world.metres} m', Offset(size.width / 2, hz * 0.42), size: 34,
        color: const Color(0xFFFFF3D6), glow: const Color(0xFFFF4FD8));
    paintVignette(canvas, size, 0.5);
  }

  void _paintRunner(Canvas canvas, Size size, double py) {
    if (world.crashed) return;
    final double x = _laneX(size, 0, _laneVisual);
    final double lean = (world.lane - _laneVisual).clamp(-1.0, 1.0) * 0.32;
    final double cyc = clock * 15;
    final double bob = math.sin(cyc * 2).abs() * 5;
    const Color suit = Color(0xFF1E2440);
    const Color neon = Color(0xFF5CF2FF);

    paintShadow(canvas, Offset(x, py + 6), 54, 14, 0.55);
    SoloArt.paintBloom(canvas, Offset(x, py), 46, neon, 0.28);
    canvas.save();
    canvas.translate(x, py - bob);
    canvas.rotate(lean);
    // Legs (seen from behind: alternating lift).
    for (final int side in <int>[-1, 1]) {
      final double lift = math.max(0, math.sin(cyc + (side > 0 ? math.pi : 0)));
      final Offset hip = Offset(side * 7.0, -38);
      final Offset foot = Offset(side * 9.0, -4 - lift * 16);
      canvas.drawLine(hip, foot, Paint()
        ..color = suit
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round);
      canvas.drawLine(hip + const Offset(0, 6), foot, Paint()
        ..color = neon.withValues(alpha: 0.7)
        ..strokeWidth = 1.6);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: foot + const Offset(0, 2), width: 12, height: 7), const Radius.circular(3)),
          Paint()..color = const Color(0xFFFF4FD8));
    }
    // Arms swing.
    for (final int side in <int>[-1, 1]) {
      final double sw = math.sin(cyc + (side > 0 ? 0 : math.pi)) * 9;
      canvas.drawLine(Offset(side * 13.0, -66), Offset(side * 17.0, -46 + sw), Paint()
        ..color = suit
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round);
    }
    // Torso with glowing spine + backpack.
    final RRect torso = RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -55), width: 30, height: 36), const Radius.circular(11));
    canvas.drawRRect(torso,
        Paint()..shader = ui.Gradient.linear(const Offset(-15, -70), const Offset(15, -38), const <Color>[Color(0xFF39406B), Color(0xFF151A2E)]));
    final RRect pack = RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -55), width: 18, height: 22), const Radius.circular(5));
    canvas.drawRRect(pack, Paint()..color = const Color(0xFF0E1222));
    SoloArt.neonPath(canvas, Path()..addRRect(pack), neon, width: 1.4, glow: 6);
    final double thrust = 0.6 + 0.4 * math.sin(clock * 40);
    SoloArt.paintBloom(canvas, const Offset(0, -40), 16 * thrust, neon, 0.6);
    // Helmet.
    paintSphere(canvas, const Offset(0, -82), 11, const Color(0xFF2B3360), shadow: false, gloss: 0.8);
    canvas.drawArc(Rect.fromCircle(center: const Offset(0, -82), radius: 11), math.pi * 0.05, math.pi * 0.9, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFFFF4FD8));
    canvas.restore();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (DragEndDetails d) {
            final double v = d.primaryVelocity ?? 0;
            if (v.abs() > 80) setState(() => world.sidestep(v < 0 ? -1 : 1));
          },
          child: super.build(context),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 26,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
            SoloPad(icon: Icons.chevron_left_rounded, onTap: () => setState(() => world.sidestep(-1)), size: 66, accent: const Color(0xFFFF4FD8)),
            SoloPad(icon: Icons.chevron_right_rounded, onTap: () => setState(() => world.sidestep(1)), size: 66, accent: const Color(0xFFFF4FD8)),
          ]),
        ),
      ]);
}

// =====================================================================================
// FRUIT NINJA — lantern-lit dojo planks, six hand-painted fruits that split into halves
// with juice splashes and stains, a fizzing bomb, and a tapered glowing blade trail.
// =====================================================================================
class FruitBoard extends SoloBoard {
  const FruitBoard({super.key, required super.run});
  @override
  FruitBoardState createState() => FruitBoardState();
}

class _Half {
  _Half(this.x, this.y, this.vx, this.vy, this.r, this.type, this.angle, this.side) : spin = side * 3.2;
  double x, y, vx, vy;
  final double r;
  final int type;
  double angle;
  final int side;
  final double spin;
  double life = 2.2;
}

class _Splat {
  _Splat(this.at, this.color, this.r, this.seed);
  final Offset at;
  final Color color;
  final double r;
  final int seed;
  double life = 3.5;
}

class FruitBoardState extends SoloBoardState<FruitBoard> {
  late FruitWorld world;
  final List<(Offset, double)> _trail = <(Offset, double)>[];
  final Expando<int> _type = Expando<int>();
  final Set<FruitSlice> _handled = <FruitSlice>{};
  final List<_Half> _halves = <_Half>[];
  final List<_Splat> _splats = <_Splat>[];
  final math.Random _rng = math.Random(5);
  int _swipeCuts = 0;
  bool _boom = false;

  // skin, flesh, seed / detail
  static const List<List<Color>> _fruit = <List<Color>>[
    <Color>[Color(0xFF2E8B3A), Color(0xFFFF3B4E), Color(0xFF1A0E0E)], // watermelon
    <Color>[Color(0xFFFF8A1F), Color(0xFFFFB347), Color(0xFFFFE2A8)], // orange
    <Color>[Color(0xFFD8203A), Color(0xFFFFF1C9), Color(0xFF6B3A1A)], // apple
    <Color>[Color(0xFF8A6A3A), Color(0xFF7BD84A), Color(0xFF151515)], // kiwi
    <Color>[Color(0xFF7A2C8F), Color(0xFFFFD08A), Color(0xFF5B2D16)], // plum
    <Color>[Color(0xFFFFE04A), Color(0xFFFFF6B0), Color(0xFFFFFFFF)], // lemon
  ];

  @override
  void reset() {
    world = FruitWorld(seed: widget.run.seed);
    _trail.clear();
    _handled.clear();
    _halves.clear();
    _splats.clear();
    _boom = false;
    widget.run.set(0);
  }

  int _typeOf(FruitSlice f) => _type[f] ??= _rng.nextInt(_fruit.length);

  @override
  void step(double dt) {
    world.update(dt);
    widget.run.set(world.sliced * 10);
    if (world.exploded) widget.run.gameOver();
  }

  void _advanceDecor(double dt) {
    for (final _Half h in _halves) {
      h.vy += 1500 * dt;
      h.x += h.vx * dt;
      h.y += h.vy * dt;
      h.angle += h.spin * dt;
      h.life -= dt;
    }
    _halves.removeWhere((_Half h) => h.life <= 0 || h.y > lastSize.height + 80);
    for (final _Splat s in _splats) {
      s.life -= dt;
    }
    _splats.removeWhere((_Splat s) => s.life <= 0);
  }

  void _slice(Offset p, Size s) {
    final double nx = p.dx / s.width;
    final double ny = p.dy / s.height;
    _trail.add((p, clock));
    if (_trail.length > 40) _trail.removeAt(0);
    final List<FruitSlice> before = List<FruitSlice>.of(world.items);
    world.sliceAt(nx, ny);
    double cutAngle = 0;
    if (_trail.length >= 2) {
      final Offset d = _trail.last.$1 - _trail[_trail.length - 2].$1;
      cutAngle = math.atan2(d.dy, d.dx);
    }
    for (final FruitSlice f in before) {
      if (f.sliced && !_handled.contains(f)) {
        _handled.add(f);
        _onCut(f, s, cutAngle);
      }
    }
    if (world.exploded && !_boom) {
      _boom = true;
      FruitSlice? bomb;
      double best = 1e9;
      for (final FruitSlice f in world.items) {
        if (!f.bomb) continue;
        final double d = (f.x - nx) * (f.x - nx) + (f.y - ny) * (f.y - ny);
        if (d < best) {
          best = d;
          bomb = f;
        }
      }
      final Offset at = bomb == null ? p : Offset(bomb.x * s.width, bomb.y * s.height);
      fx.burst(at, const Color(0xFFFFE08A), count: 60, speed: 700, life: 0.9, size: 6);
      fx.burst(at, const Color(0xFFFF6A2E), count: 30, speed: 380, life: 1.0, size: 10, kind: ParticleKind.orb);
      fx.burst(at, const Color(0xFF3A3340), count: 20, speed: 140, life: 1.6, size: 22, kind: ParticleKind.smoke);
      fx.ring(at, Colors.white, size: 40, life: 0.6);
      fx.shake(24);
      fx.flashScreen(Colors.white, 0.85);
      widget.run.gameOver();
    }
    setState(() {});
  }

  void _onCut(FruitSlice f, Size s, double angle) {
    final int type = _typeOf(f);
    final Offset at = Offset(f.x * s.width, f.y * s.height);
    final double r = f.radius * s.width;
    final Offset n = Offset(-math.sin(angle), math.cos(angle));
    for (final int side in <int>[-1, 1]) {
      _halves.add(_Half(at.dx + n.dx * side * 4, at.dy + n.dy * side * 4, f.vx * s.width * 0.6 + n.dx * side * 120,
          f.vy * s.height * 0.5 + n.dy * side * 120 - 60, r, type, angle, side));
    }
    final Color juice = _fruit[type][1];
    fx.burst(at, juice, count: 22, speed: 420, life: 0.6, size: 5, gravity: 900);
    fx.burst(at, Colors.white, count: 8, speed: 520, life: 0.25, size: 3);
    _splats.add(_Splat(at, juice, r * 1.6, _rng.nextInt(1 << 20)));
    if (_splats.length > 14) _splats.removeAt(0);
    _swipeCuts++;
    fx.text('+10', at - Offset(0, r + 8), const Color(0xFFFFF1C9), size: 18);
    if (_swipeCuts >= 3) {
      fx.text('COMBO ×$_swipeCuts', Offset(s.width / 2, s.height * 0.32), const Color(0xFFFFC23B), size: 30);
      fx.shake(4);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _advanceDecor(1 / 60);
    _paintDojo(canvas, size);
    for (final _Splat s in _splats) {
      _paintSplat(canvas, s);
    }
    for (final FruitSlice f in world.items) {
      if (f.sliced) continue;
      final Offset at = Offset(f.x * size.width, f.y * size.height);
      final double r = f.radius * size.width;
      if (f.bomb) {
        _paintBomb(canvas, at, r * 1.05, f.rotation);
      } else {
        _paintFruit(canvas, at, r, _typeOf(f), f.rotation);
      }
    }
    for (final _Half h in _halves) {
      _paintHalf(canvas, h);
    }
    _paintBlade(canvas);
    SoloArt.bigLabel(canvas, '${world.sliced}', Offset(size.width / 2, size.height * 0.16), size: 44,
        color: const Color(0xFFFFF1C9), glow: const Color(0xFFFF8A1F));
    LuxeBoardPainter.text(canvas, 'SLICED', Offset(size.width / 2, size.height * 0.16 + 32),
        color: const Color(0xFFE9C79A), size: 12, weight: FontWeight.w700);
    paintVignette(canvas, size, 0.65);
  }

  void _paintDojo(Canvas canvas, Size size) {
    const int planks = 6;
    final double pw = size.width / planks;
    for (int i = 0; i < planks; i++) {
      final Rect r = Rect.fromLTWH(i * pw, 0, pw + 1, size.height);
      final double tint = (i * 37 % 7) / 7 * 0.05;
      canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(r.topLeft, r.topRight, <Color>[
            SoloArt.tone(const Color(0xFF4A2C1A), tint),
            SoloArt.tone(const Color(0xFF5E3820), tint),
            SoloArt.tone(const Color(0xFF3E2414), tint),
          ], <double>[0, 0.55, 1]),
      );
      final math.Random g = math.Random(i * 13 + 1);
      final Paint grain = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      for (int k = 0; k < 9; k++) {
        final double gx = r.left + 6 + g.nextDouble() * (pw - 12);
        final Path p = Path()..moveTo(gx, 0);
        for (double y = 0; y <= size.height; y += 40) {
          p.lineTo(gx + math.sin(y * 0.012 + k + i) * 5, y);
        }
        grain.color = const Color(0xFF26140A).withValues(alpha: 0.18 + g.nextDouble() * 0.2);
        canvas.drawPath(p, grain);
      }
      if (i % 2 == 0) {
        final Offset knot = Offset(r.left + pw * (0.3 + g.nextDouble() * 0.4), size.height * (0.2 + g.nextDouble() * 0.6));
        canvas.drawOval(Rect.fromCenter(center: knot, width: 10, height: 22), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0x55220F05));
      }
      canvas.drawLine(Offset(r.left, 0), Offset(r.left, size.height), Paint()
        ..color = const Color(0xCC1A0C04)
        ..strokeWidth = 2.2);
    }
    // Warm lantern light from above.
    SoloArt.paintBloom(canvas, Offset(size.width * 0.5, -size.height * 0.05), size.height * 0.75, const Color(0xFFFFA64A), 0.22);
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), const <Color>[Color(0x00000000), Color(0x99100604)]));
  }

  void _paintSplat(Canvas canvas, _Splat s) {
    final double a = (s.life / 3.5).clamp(0.0, 1.0) * 0.55;
    final math.Random r = math.Random(s.seed);
    final Paint p = Paint()..color = s.color.withValues(alpha: a);
    canvas.drawCircle(s.at, s.r * 0.55, p);
    for (int i = 0; i < 9; i++) {
      final double ang = r.nextDouble() * math.pi * 2;
      final double d = s.r * (0.4 + r.nextDouble() * 0.9);
      canvas.drawCircle(s.at + Offset(math.cos(ang), math.sin(ang)) * d, s.r * (0.06 + r.nextDouble() * 0.16), p);
    }
  }

  void _paintFruit(Canvas canvas, Offset c, double r, int type, double rot) {
    final List<Color> col = _fruit[type];
    paintShadow(canvas, c + Offset(r * 0.25, r * 1.15), r * 1.6, r * 0.45, 0.35);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    final double rx = type == 5 ? r * 1.15 : r;
    final double ry = type == 5 ? r * 0.85 : (type == 3 ? r * 0.92 : r);
    final Rect oval = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    canvas.drawOval(oval, Paint()
      ..shader = ui.Gradient.radial(Offset(-rx * 0.35, -ry * 0.4), r * 1.6,
          <Color>[SoloArt.tone(col[0], 0.22), col[0], SoloArt.tone(col[0], -0.25)], <double>[0, 0.5, 1]));
    switch (type) {
      case 0: // watermelon stripes
        canvas.save();
        canvas.clipPath(Path()..addOval(oval));
        final Paint stripe = Paint()
          ..color = const Color(0xFF14531E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16;
        for (int i = -3; i <= 3; i++) {
          final Path p = Path()..moveTo(i * r * 0.32, -r);
          for (double y = -r; y <= r; y += r * 0.25) {
            p.lineTo(i * r * 0.32 + math.sin(y / r * 6 + i) * r * 0.05 + y * i * 0.08, y);
          }
          canvas.drawPath(p, stripe);
        }
        canvas.restore();
      case 1: // orange peel dimples
        final math.Random d = math.Random(3);
        for (int i = 0; i < 26; i++) {
          final double a = d.nextDouble() * math.pi * 2;
          final double rr = math.sqrt(d.nextDouble()) * r * 0.85;
          canvas.drawCircle(Offset(math.cos(a), math.sin(a)) * rr, r * 0.035, Paint()..color = const Color(0x33A84A00));
        }
        canvas.drawCircle(Offset(0, -r * 0.82), r * 0.08, Paint()..color = const Color(0xFF5B7A1E));
      case 2: // apple stem + leaf
        canvas.drawLine(Offset(0, -r * 0.75), Offset(r * 0.08, -r * 1.2), Paint()
          ..color = col[2]
          ..strokeWidth = r * 0.1
          ..strokeCap = StrokeCap.round);
        final Path leaf = Path()
          ..moveTo(r * 0.08, -r * 1.05)
          ..quadraticBezierTo(r * 0.5, -r * 1.35, r * 0.65, -r * 1.0)
          ..quadraticBezierTo(r * 0.35, -r * 0.88, r * 0.08, -r * 1.05);
        canvas.drawPath(leaf, Paint()..color = const Color(0xFF4CAF3A));
        canvas.drawOval(Rect.fromCenter(center: Offset(r * 0.3, r * 0.1), width: r * 0.5, height: r * 0.9),
            Paint()..color = const Color(0x22FFE08A));
      case 3: // kiwi fuzz
        final math.Random d = math.Random(9);
        final Paint fuzz = Paint()
          ..color = const Color(0x553A2810)
          ..strokeWidth = 1;
        for (int i = 0; i < 40; i++) {
          final double a = d.nextDouble() * math.pi * 2;
          final double rr = d.nextDouble() * r * 0.9;
          final Offset p = Offset(math.cos(a) * rr, math.sin(a) * rr * 0.92);
          canvas.drawLine(p, p + Offset(1.5, 2), fuzz);
        }
      case 4: // plum bloom
        canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * 0.6), -1.2, 1.4, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0x55FFFFFF));
        canvas.drawLine(Offset(0, -r), Offset(-r * 0.05, -r * 1.25), Paint()
          ..color = col[2]
          ..strokeWidth = r * 0.08);
      case 5: // lemon tips
        canvas.drawOval(Rect.fromCenter(center: Offset(rx * 0.98, 0), width: r * 0.3, height: r * 0.24), Paint()..color = SoloArt.tone(col[0], -0.1));
        canvas.drawOval(Rect.fromCenter(center: Offset(-rx * 0.98, 0), width: r * 0.24, height: r * 0.2), Paint()..color = SoloArt.tone(col[0], -0.1));
    }
    // Specular highlight.
    canvas.drawOval(Rect.fromCenter(center: Offset(-rx * 0.35, -ry * 0.45), width: rx * 0.7, height: ry * 0.38),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, -ry * 0.65), Offset(0, -ry * 0.25), const <Color>[Color(0xAAFFFFFF), Color(0x00FFFFFF)]));
    canvas.restore();
  }

  void _paintHalf(Canvas canvas, _Half h) {
    final List<Color> col = _fruit[h.type];
    final double a = (h.life / 0.6).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(h.x, h.y);
    canvas.rotate(h.angle);
    canvas.clipRect(Rect.fromLTRB(-h.r * 1.5, h.side < 0 ? -h.r * 1.5 : 0, h.r * 1.5, h.side < 0 ? 0 : h.r * 1.5));
    final Paint skin = Paint()..color = col[0].withValues(alpha: a);
    canvas.drawCircle(Offset.zero, h.r, skin);
    canvas.drawCircle(Offset.zero, h.r * 0.88, Paint()..color = (h.type == 0 ? const Color(0xFFE9F5C9) : col[1]).withValues(alpha: a));
    canvas.drawCircle(Offset.zero, h.r * (h.type == 0 ? 0.8 : 0.84), Paint()
      ..shader = ui.Gradient.radial(Offset.zero, h.r, <Color>[SoloArt.tone(col[1], 0.12).withValues(alpha: a), col[1].withValues(alpha: a)]));
    // Seeds / segments.
    if (h.type == 1 || h.type == 5) {
      for (int i = 0; i < 8; i++) {
        final double ang = i * math.pi / 4;
        canvas.drawLine(Offset.zero, Offset(math.cos(ang), math.sin(ang)) * h.r * 0.8, Paint()
          ..color = col[2].withValues(alpha: 0.7 * a)
          ..strokeWidth = 1.2);
      }
    } else {
      for (int i = 0; i < 7; i++) {
        final double ang = i * 0.9 + 0.3;
        final double d = h.r * (h.type == 3 ? 0.35 : 0.5);
        canvas.drawOval(Rect.fromCenter(center: Offset(math.cos(ang), math.sin(ang).abs() * h.side) * d, width: h.r * 0.09, height: h.r * 0.16),
            Paint()..color = col[2].withValues(alpha: a));
      }
      if (h.type == 3) canvas.drawCircle(Offset.zero, h.r * 0.18, Paint()..color = const Color(0xFFF2F7D0).withValues(alpha: a));
    }
    canvas.restore();
  }

  void _paintBomb(Canvas canvas, Offset c, double r, double rot) {
    final double pulse = 0.5 + 0.5 * math.sin(clock * 14);
    SoloArt.paintBloom(canvas, c, r * 2.4, const Color(0xFFFF2E2E), 0.25 + 0.25 * pulse);
    paintSphere(canvas, c, r, const Color(0xFF26222C), gloss: 0.9, rim: const Color(0xFFFF3B3B).withValues(alpha: 0.4 + 0.5 * pulse));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot * 0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -r * 0.95), width: r * 0.55, height: r * 0.3), Radius.circular(r * 0.06)),
        Paint()..color = const Color(0xFF6B6672));
    final Path fuse = Path()
      ..moveTo(0, -r * 1.08)
      ..quadraticBezierTo(r * 0.35, -r * 1.5, r * 0.15, -r * 1.75);
    canvas.drawPath(fuse, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..color = const Color(0xFFC9A46A));
    final Offset tip = Offset(r * 0.15, -r * 1.75);
    SoloArt.paintBloom(canvas, tip, r * 0.9, const Color(0xFFFFC24A), 0.9);
    final math.Random sr = math.Random((clock * 24).floor());
    for (int i = 0; i < 6; i++) {
      final double a = sr.nextDouble() * math.pi * 2;
      canvas.drawLine(tip, tip + Offset(math.cos(a), math.sin(a)) * r * (0.3 + sr.nextDouble() * 0.4), Paint()
        ..color = const Color(0xFFFFF0A8)
        ..strokeWidth = 1.4);
    }
    canvas.restore();
    LuxeBoardPainter.text(canvas, '✕', c, color: const Color(0xFFFF4A4A).withValues(alpha: 0.6 + 0.4 * pulse), size: r * 0.8);
  }

  void _paintBlade(Canvas canvas) {
    _trail.removeWhere(((Offset, double) p) => clock - p.$2 > 0.16);
    if (_trail.length < 2) return;
    final int n = _trail.length;
    for (int i = 1; i < n; i++) {
      final double k = i / (n - 1);
      final Offset a = _trail[i - 1].$1;
      final Offset b = _trail[i].$1;
      canvas.drawLine(a, b, Paint()
        ..color = const Color(0xFF7FE9FF).withValues(alpha: 0.35 * k)
        ..strokeWidth = 4 + 16 * k
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawLine(a, b, Paint()
        ..color = Colors.white.withValues(alpha: 0.95 * k)
        ..strokeWidth = 1 + 6 * k
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (BuildContext c, BoxConstraints box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails d) {
            _swipeCuts = 0;
            _slice(d.localPosition, box.biggest);
          },
          onPanUpdate: (DragUpdateDetails d) => _slice(d.localPosition, box.biggest),
          onPanEnd: (_) => _swipeCuts = 0,
          child: super.build(context),
        );
      });
}

// =====================================================================================
// HELIX JUMP — a real rotating 3D tower: shaded pillar, thick glossy platforms with the
// gap that actually turns with your drag, glass "safe" rings, a squashing ball with trail.
// =====================================================================================
class HelixBoard extends SoloBoard {
  const HelixBoard({super.key, required super.run});
  @override
  HelixBoardState createState() => HelixBoardState();
}

class HelixBoardState extends SoloBoardState<HelixBoard> {
  late HelixWorld world;
  double _tilt = 0;
  final List<double> _ballTrail = <double>[];
  double _prevDepth = 0;
  int _lastRing = 0;
  bool _dead = false;

  static const double _gapHalf = 0.42;

  @override
  void reset() {
    world = HelixWorld(seed: widget.run.seed);
    _tilt = 0;
    _ballTrail.clear();
    _prevDepth = 0;
    _lastRing = 0;
    _dead = false;
    widget.run.set(0);
  }

  @override
  void step(double dt) {
    _prevDepth = world.depth;
    world.update(dt, tilt: _tilt);
    _tilt *= 0.9;
    widget.run.set(world.ring * 5);
    if (world.ring > _lastRing) {
      if (lastSize != Size.zero && world.rings[_lastRing] == HelixRing.red) {
        fx.burst(Offset(lastSize.width / 2, _ballY(lastSize) + 10), const Color(0xFFFFE36B), count: 10, speed: 200, life: 0.4, size: 3);
      }
      _lastRing = world.ring;
    }
    if (world.dead && !_dead) {
      _dead = true;
      final Offset b = Offset(lastSize.width / 2, _ballY(lastSize));
      fx.burst(b, const Color(0xFFFF3B5C), count: 40, speed: 420, life: 0.8, size: 5, gravity: 500);
      fx.burst(b, Colors.white, count: 14, speed: 220, life: 0.5, size: 6, kind: ParticleKind.orb);
      fx.shake(14);
      fx.flashScreen(const Color(0xFFFF2E4E), 0.4);
    }
    if (world.dead || world.finished) widget.run.gameOver();
  }

  double _ballY(Size s) => s.height * 0.34;

  Color _platformColour(int ring) => SoloArt.hue(190 + (ring ~/ 12) * 47.0, s: 0.75, l: 0.55);

  @override
  void paint(Canvas canvas, Size size) {
    final double t = clock;
    final double bgHue = 250 + (world.depth / world.ringCount) * 140;
    SoloArt.sky(canvas, Offset.zero & size, <Color>[
      SoloArt.hue(bgHue, s: 0.55, l: 0.16),
      SoloArt.hue(bgHue + 30, s: 0.6, l: 0.09),
      const Color(0xFF04030A),
    ], <double>[0, 0.6, 1]);
    // Rising dust motes.
    final math.Random r = math.Random(4);
    for (int i = 0; i < 40; i++) {
      final double x = r.nextDouble() * size.width;
      final double y = (r.nextDouble() * size.height - world.depth * 40 * (0.4 + r.nextDouble())) % size.height;
      canvas.drawCircle(Offset(x, y < 0 ? y + size.height : y), 0.8 + r.nextDouble() * 1.6,
          Paint()..color = Colors.white.withValues(alpha: 0.08 + r.nextDouble() * 0.12));
    }

    final double cx = size.width / 2;
    final double rx = math.min(size.width * 0.40, 190);
    const double squash = 0.34;
    final double pr = rx * 0.22;
    final double spacing = size.height * 0.105;
    final double th = spacing * 0.22;
    final double ballY = _ballY(size);
    final double rMid = (pr + rx) / 2;
    double ringY(int i) => ballY - rMid * squash + (i + 0.15 - world.depth) * spacing + 8;

    SoloArt.paintBloom(canvas, Offset(cx, size.height * 0.45), size.width * 0.8, SoloArt.hue(bgHue), 0.12);

    final int first = math.max(0, world.ring - 4);
    final int last = math.min(world.ringCount - 1, world.ring + 9);
    // Pillar base below the deepest visible ring.
    _pillar(canvas, cx, pr, ringY(last), size.height + 20);
    for (int i = last; i >= first; i--) {
      final double y = ringY(i);
      if (y < -spacing || y > size.height + spacing) continue;
      final bool red = world.rings[i] == HelixRing.red;
      final double gapCentre = (i * 1.7) % (math.pi * 2);
      final double gapScreen = math.pi / 2 + (gapCentre - world.spin);
      final double passed = (world.depth - i - 0.3).clamp(0.0, 1.0);
      if (red) {
        _ringSolid(canvas, cx, y, rx, pr, squash, th, gapScreen, const Color(0xFFE8264A), 1 - passed * 0.7, glow: true);
      } else {
        final Color c = _platformColour(i);
        _ringSolid(canvas, cx, y, rx, pr, squash, th * 0.55, null, c.withValues(alpha: 1), 0.35 * (1 - passed * 0.8));
      }
      // Pillar segment above this ring (occludes the ring's back half).
      _pillar(canvas, cx, pr, y - spacing, y);
    }

    // Ball + trail.
    final double vy = (world.depth - _prevDepth) * 60;
    _ballTrail.insert(0, vy);
    if (_ballTrail.length > 8) _ballTrail.removeLast();
    if (!world.dead) {
      for (int i = 1; i < _ballTrail.length; i++) {
        final double off = _ballTrail.take(i).fold(0.0, (double a, double b) => a + b) * spacing / 60;
        canvas.drawCircle(Offset(cx, ballY - off), 13 * (1 - i / 9), Paint()..color = const Color(0xFFFFE36B).withValues(alpha: 0.22 * (1 - i / 8)));
      }
      final double sq = (vy.abs() * 0.04).clamp(0.0, 0.22);
      paintShadow(canvas, Offset(cx, ballY + 14), 26, 7, 0.4);
      canvas.save();
      canvas.translate(cx, ballY);
      canvas.scale(1 - sq * 0.5, 1 + sq);
      paintSphere(canvas, Offset.zero, 13, const Color(0xFFFFD23B), shadow: false, rim: Colors.white);
      canvas.restore();
      SoloArt.paintBloom(canvas, Offset(cx, ballY), 34, const Color(0xFFFFD23B), 0.25);
    }

    // Progress bar.
    final Rect bar = Rect.fromLTWH(size.width * 0.18, size.height * 0.08, size.width * 0.64, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(4)), Paint()..color = const Color(0x33FFFFFF));
    final double prog = (world.depth / (world.ringCount - 1)).clamp(0.0, 1.0);
    final Rect fill = Rect.fromLTWH(bar.left, bar.top, bar.width * prog, bar.height);
    canvas.drawRRect(RRect.fromRectAndRadius(fill, const Radius.circular(4)),
        Paint()..shader = ui.Gradient.linear(bar.centerLeft, bar.centerRight, const <Color>[Color(0xFFFFD23B), Color(0xFFFF4FD8)]));
    SoloArt.paintBloom(canvas, fill.centerRight, 14, const Color(0xFFFF4FD8), 0.6 + 0.3 * math.sin(t * 6));
    SoloArt.bigLabel(canvas, '${world.ring}', Offset(size.width / 2, size.height * 0.15), size: 32,
        color: Colors.white, glow: SoloArt.hue(bgHue));
    paintVignette(canvas, size, 0.6);
  }

  void _pillar(Canvas canvas, double cx, double pr, double top, double bottom) {
    if (bottom <= top) return;
    final Rect r = Rect.fromLTRB(cx - pr, top, cx + pr, bottom);
    canvas.drawRect(r, Paint()
      ..shader = ui.Gradient.linear(r.centerLeft, r.centerRight,
          const <Color>[Color(0xFF8E96B8), Color(0xFFE9EDFF), Color(0xFFA8B0D0), Color(0xFF4A5070)], <double>[0, 0.3, 0.6, 1]));
  }

  Path _sector(double cx, double y, double rx, double pr, double squash, double a0, double a1) {
    final Path p = Path();
    const int n = 40;
    for (int k = 0; k <= n; k++) {
      final double a = a0 + (a1 - a0) * k / n;
      final Offset o = Offset(cx + rx * math.cos(a), y + rx * squash * math.sin(a));
      if (k == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    for (int k = n; k >= 0; k--) {
      final double a = a0 + (a1 - a0) * k / n;
      p.lineTo(cx + pr * math.cos(a), y + pr * squash * math.sin(a));
    }
    p.close();
    return p;
  }

  void _ringSolid(Canvas canvas, double cx, double y, double rx, double pr, double squash, double th, double? gap, Color c, double alpha,
      {bool glow = false}) {
    if (alpha <= 0.02) return;
    final double a0 = gap == null ? 0 : gap + _gapHalf;
    final double a1 = gap == null ? math.pi * 2 : gap + math.pi * 2 - _gapHalf;
    final Path top = _sector(cx, y, rx, pr, squash, a0, a1);
    final Path side = top.shift(Offset(0, th));
    canvas.saveLayer(top.getBounds().inflate(th + 20), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    if (glow) SoloArt.paintBloom(canvas, Offset(cx, y), rx * 1.1, c, 0.18);
    canvas.drawPath(side, Paint()..color = SoloArt.tone(c, -0.22));
    for (double k = 1; k < th; k += 2) {
      canvas.drawPath(top.shift(Offset(0, k)), Paint()..color = SoloArt.tone(c, -0.16));
    }
    canvas.drawPath(top, Paint()
      ..shader = ui.Gradient.linear(Offset(cx - rx, y - rx * squash), Offset(cx + rx, y + rx * squash),
          <Color>[SoloArt.tone(c, 0.2), c, SoloArt.tone(c, -0.08)], <double>[0.0, 0.5, 1.0]));
    // Rim highlight on the front edge.
    canvas.drawPath(top, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.35));
    canvas.restore();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (BuildContext c, BoxConstraints box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (DragUpdateDetails d) => _tilt = (d.delta.dx / box.maxWidth) * 6,
          onTap: () {
            setState(world.jump);
            fx.ring(Offset(box.maxWidth / 2, _ballY(box.biggest) + 12), const Color(0xFFFFE36B), size: 14);
          },
          child: super.build(context),
        );
      });
}

// =====================================================================================
// BUBBLE SHOOTER — glossy candy bubbles with shape glyphs, riveted ceiling, a turning
// cannon with a live landing ghost, animated shots and colour-matched pop bursts.
// =====================================================================================
class BubbleBoard extends SoloBoard {
  const BubbleBoard({super.key, required super.run});
  @override
  BubbleBoardState createState() => BubbleBoardState();
}

class BubbleBoardState extends SoloBoardState<BubbleBoard> {
  late BubbleWorld world;
  double _aim = 0;
  double _cool = 0;
  (int, int)? _shotCell;
  int _shotColour = 0;
  double _shotT = 0;
  Offset _shotFrom = Offset.zero;

  static const List<Color> _colours = <Color>[
    Color(0xFF2FD4FF), // cyan
    Color(0xFFFFC93B), // gold
    Color(0xFF58E36B), // lime
    Color(0xFFA26BFF), // violet
    Color(0xFFFF5470), // coral
  ];

  @override
  void reset() {
    world = BubbleWorld(seed: widget.run.seed)..pickColour();
    _aim = 0;
    _shotCell = null;
    widget.run.set(0);
  }

  @override
  void step(double dt) {
    if (_cool > 0) _cool -= dt;
    if (_shotCell != null) {
      _shotT += dt * 5.5;
      if (_shotT >= 1) _land();
    }
  }

  // Layout helpers.
  double _cell(Size s) => math.min(s.width / (world.cols + 1.2), (s.height * 0.62) / 11);
  double _left(Size s) => s.width / 2 - (world.cols * _cell(s)) / 2;
  double _top(Size s) => s.height * 0.12;
  Offset _cellCentre(Size s, int row, int col) {
    final double cell = _cell(s);
    return Offset(_left(s) + col * cell + (row.isOdd ? cell / 2 : 0) + cell / 2, _top(s) + cell * 0.5 + row * cell * 0.88);
  }

  Offset _gun(Size s) => Offset(s.width / 2, s.height - 112);

  int get _aimedCol => (world.cols / 2 + math.sin(_aim) * world.cols * 0.75).round().clamp(0, world.cols - 1);

  (int, int)? _target() {
    final int a = _aimedCol;
    final List<int> order = <int>[a];
    for (int d = 1; d < world.cols; d++) {
      if (a - d >= 0) order.add(a - d);
      if (a + d < world.cols) order.add(a + d);
    }
    for (final int col in order) {
      final (int, int)? c = world.landingCell(col);
      if (c != null) return c;
    }
    return null;
  }

  void _aimAt(Offset p, Size s) {
    final Offset d = p - _gun(s);
    if (d.dy > -10) return;
    _aim = math.atan2(d.dx, -d.dy).clamp(-1.25, 1.25);
  }

  void _fire() {
    if (_cool > 0 || _shotCell != null || lastSize == Size.zero || world.cleared) return;
    final (int, int)? t = _target();
    if (t == null) return;
    _cool = 0.25;
    _shotCell = t;
    _shotColour = world.nextColour;
    _shotT = 0;
    _shotFrom = _gun(lastSize);
    fx.burst(_shotFrom + Offset(math.sin(_aim), -math.cos(_aim)) * 34, _colours[_shotColour % 5], count: 8, speed: 180, life: 0.3, size: 3,
        spread: 0.8, direction: -math.pi / 2 + _aim);
    setState(() {});
  }

  void _land() {
    final (int, int) cell = _shotCell!;
    _shotCell = null;
    final List<List<int>> before = <List<int>>[for (final List<int> r in world.grid) List<int>.of(r)];
    world.aim = _aim;
    final int popped = world.fire();
    final Size s = lastSize;
    if (popped > 0) {
      for (int r = 0; r < world.rows; r++) {
        for (int c = 0; c < world.cols; c++) {
          if (before[r][c] >= 0 && world.grid[r][c] < 0) {
            final Offset at = _cellCentre(s, r, c);
            final Color col = _colours[before[r][c] % 5];
            fx.burst(at, col, count: 10, speed: 260, life: 0.55, size: 4, gravity: 500);
            fx.burst(at, Colors.white, count: 3, speed: 120, life: 0.3, size: 5, kind: ParticleKind.orb);
            fx.ring(at, col, size: _cell(s) * 0.3, life: 0.35);
          }
        }
      }
      // The shot bubble itself popped at the landing cell.
      final Offset at = _cellCentre(s, cell.$1, cell.$2);
      fx.text('+${popped * 12}', at, const Color(0xFFFFF3C2), size: 20 + math.min(14, popped.toDouble()));
      fx.shake(math.min(10, 2.0 + popped));
      if (popped >= 6) fx.flashScreen(_colours[_shotColour % 5], 0.18);
    } else {
      fx.ring(_cellCentre(s, cell.$1, cell.$2), Colors.white, size: _cell(s) * 0.3, life: 0.25);
    }
    world.pickColour();
    widget.run.set(world.popped * 12);
    if (world.cleared) {
      fx.confetti(Offset(s.width / 2, s.height * 0.4), count: 80);
      widget.run.gameOver();
    }
    setState(() {});
  }

  void _paintBubble(Canvas canvas, Offset c, double r, int colour, {double alpha = 1}) {
    final Color col = _colours[colour % 5];
    if (alpha < 1) {
      canvas.saveLayer(Rect.fromCircle(center: c, radius: r * 2), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    paintSphere(canvas, c, r, col, shadow: false, rim: SoloArt.tone(col, 0.25));
    // Shape glyph (readable without colour).
    final Paint g = Paint()..color = Colors.white.withValues(alpha: 0.38);
    final double k = r * 0.32;
    final Offset o = c + Offset(r * 0.08, r * 0.12);
    switch (colour % 5) {
      case 0:
        canvas.drawCircle(o, k * 0.8, g);
      case 1:
        canvas.drawPath(Path()
          ..moveTo(o.dx, o.dy - k)
          ..lineTo(o.dx + k, o.dy)
          ..lineTo(o.dx, o.dy + k)
          ..lineTo(o.dx - k, o.dy)
          ..close(), g);
      case 2:
        canvas.drawPath(Path()
          ..moveTo(o.dx, o.dy - k)
          ..lineTo(o.dx + k, o.dy + k * 0.8)
          ..lineTo(o.dx - k, o.dy + k * 0.8)
          ..close(), g);
      case 3:
        final Path star = Path();
        for (int i = 0; i < 10; i++) {
          final double a = -math.pi / 2 + i * math.pi / 5;
          final double rr = i.isEven ? k * 1.05 : k * 0.45;
          final Offset p = o + Offset(math.cos(a), math.sin(a)) * rr;
          if (i == 0) {
            star.moveTo(p.dx, p.dy);
          } else {
            star.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(star..close(), g);
      default:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: k * 1.5, height: k * 1.5), Radius.circular(k * 0.3)), g);
    }
    if (alpha < 1) canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = clock;
    // Deep-sea backdrop with light shafts and rising micro bubbles.
    SoloArt.sky(canvas, Offset.zero & size, const <Color>[Color(0xFF0B2A4A), Color(0xFF071A33), Color(0xFF030A16)], <double>[0, 0.5, 1]);
    for (int i = 0; i < 4; i++) {
      final double x = size.width * (0.15 + i * 0.25) + math.sin(t * 0.3 + i) * 20;
      final Path shaft = Path()
        ..moveTo(x - 20, 0)
        ..lineTo(x + 30, 0)
        ..lineTo(x + 110, size.height)
        ..lineTo(x - 10, size.height)
        ..close();
      canvas.drawPath(shaft, Paint()
        ..shader = ui.Gradient.linear(Offset(x, 0), Offset(x, size.height), const <Color>[Color(0x1F7FE9FF), Color(0x007FE9FF)]));
    }
    final math.Random r = math.Random(2);
    for (int i = 0; i < 26; i++) {
      final double x = r.nextDouble() * size.width + math.sin(t + i) * 6;
      final double y = (r.nextDouble() * size.height - t * (20 + r.nextDouble() * 30)) % size.height;
      canvas.drawCircle(Offset(x, y < 0 ? y + size.height : y), 1 + r.nextDouble() * 2.5, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.15));
    }

    final double cell = _cell(size);
    final double br = cell * 0.47;
    final double left = _left(size);
    final double top = _top(size);
    final double right = left + world.cols * cell + cell / 2;
    // Play well: glass panel, side rails, riveted ceiling, danger line.
    final Rect well = Rect.fromLTRB(left - 8, top - 6, right + 8, size.height - 150);
    canvas.drawRRect(RRect.fromRectAndRadius(well, const Radius.circular(18)), Paint()..color = const Color(0x40061226));
    canvas.drawRRect(RRect.fromRectAndRadius(well, const Radius.circular(18)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x557FE9FF));
    final Rect ceil = Rect.fromLTRB(left - 12, top - 20, right + 12, top - 2);
    canvas.drawRRect(RRect.fromRectAndRadius(ceil, const Radius.circular(6)), Paint()
      ..shader = ui.Gradient.linear(ceil.topCenter, ceil.bottomCenter, const <Color>[Color(0xFFB9C6DA), Color(0xFF4A5874), Color(0xFF26314A)], <double>[0.0, 0.5, 1.0]));
    for (double x = ceil.left + 12; x < ceil.right - 6; x += 22) {
      paintSphere(canvas, Offset(x, ceil.center.dy), 2.6, const Color(0xFF8E9BB4), shadow: false);
    }
    final double danger = _top(size) + cell * 0.5 + (world.rows - 1) * cell * 0.88 + br;
    for (double x = left; x < right; x += 14) {
      canvas.drawLine(Offset(x, danger), Offset(x + 7, danger), Paint()
        ..color = const Color(0xFFFF5470).withValues(alpha: 0.4 + 0.2 * math.sin(t * 4))
        ..strokeWidth = 2);
    }

    // Bubbles.
    for (int row = 0; row < world.rows; row++) {
      for (int col = 0; col < world.cols; col++) {
        final int v = world.grid[row][col];
        if (v < 0) continue;
        final Offset c = _cellCentre(size, row, col);
        final double wob = math.sin(t * 2 + row * 0.7 + col) * 0.6;
        _paintBubble(canvas, c + Offset(0, wob), br, v);
      }
    }

    final Offset gun = _gun(size);
    final (int, int)? target = _shotCell == null ? _target() : null;
    // Aim guide to the landing ghost.
    if (target != null && !world.cleared) {
      final Offset to = _cellCentre(size, target.$1, target.$2);
      final Offset dir = to - gun;
      final double len = dir.distance;
      final Offset u = dir / len;
      final double phase = (t * 60) % 16;
      for (double d = 40 + phase; d < len - br; d += 16) {
        final double k = 1 - d / len;
        canvas.drawCircle(gun + u * d, 2.6 * (0.5 + k * 0.5), Paint()..color = _colours[world.nextColour % 5].withValues(alpha: 0.35 + 0.5 * k));
      }
      canvas.drawCircle(to, br, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.5 + 0.3 * math.sin(t * 8)));
      _paintBubble(canvas, to, br, world.nextColour, alpha: 0.22);
    }

    // Flying shot.
    if (_shotCell != null) {
      final Offset to = _cellCentre(size, _shotCell!.$1, _shotCell!.$2);
      final double k = Curves.easeIn.transform(_shotT.clamp(0.0, 1.0));
      final Offset p = Offset.lerp(_shotFrom, to, k)!;
      paintTrail(canvas, <Offset>[for (int i = 0; i < 6; i++) Offset.lerp(_shotFrom, to, math.max(0, k - (5 - i) * 0.05))!],
          _colours[_shotColour % 5], br * 1.4);
      _paintBubble(canvas, p, br, _shotColour);
    }

    // Cannon.
    paintShadow(canvas, gun + const Offset(0, 30), 96, 20, 0.5);
    canvas.save();
    canvas.translate(gun.dx, gun.dy);
    canvas.rotate(_aim);
    final RRect barrel = RRect.fromRectAndRadius(Rect.fromLTWH(-13, -54, 26, 50), const Radius.circular(8));
    canvas.drawRRect(barrel, Paint()
      ..shader = ui.Gradient.linear(const Offset(-13, 0), const Offset(13, 0), const <Color>[Color(0xFF3A4766), Color(0xFFC9D6F0), Color(0xFF2A3450)], <double>[0.0, 0.5, 1.0]));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-15, -58, 30, 8), const Radius.circular(3)),
        Paint()..color = _colours[world.nextColour % 5]);
    canvas.restore();
    final Rect base = Rect.fromCircle(center: gun, radius: 30);
    canvas.drawCircle(gun, 30, Paint()..shader = ui.Gradient.radial(gun - const Offset(8, 10), 40, const <Color>[Color(0xFF6E7FA6), Color(0xFF1A2236)]));
    for (int i = 0; i < 12; i++) {
      final double a = i * math.pi / 6 + t * 0.4;
      canvas.drawCircle(gun + Offset(math.cos(a), math.sin(a)) * 26, 2, Paint()..color = const Color(0xFF9FB0D2));
    }
    canvas.drawArc(base.deflate(3), 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x997FE9FF));
    if (_shotCell == null) _paintBubble(canvas, gun, br * 0.95, world.nextColour);

    SoloArt.bigLabel(canvas, '${world.remaining}', Offset(size.width / 2, top - 46), size: 22, color: Colors.white, glow: const Color(0xFF2FD4FF));
    paintVignette(canvas, size, 0.5);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (BuildContext c, BoxConstraints box) {
        return Stack(fit: StackFit.expand, children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (DragStartDetails d) => setState(() => _aimAt(d.localPosition, box.biggest)),
            onPanUpdate: (DragUpdateDetails d) => setState(() => _aimAt(d.localPosition, box.biggest)),
            onPanEnd: (_) => _fire(),
            onTapUp: (TapUpDetails d) {
              _aimAt(d.localPosition, box.biggest);
              _fire();
            },
            child: super.build(context),
          ),
          Positioned(
            right: 20,
            bottom: 30,
            child: SoloPad(icon: Icons.gps_fixed_rounded, onTap: _fire, size: 76, accent: const Color(0xFF2FD4FF)),
          ),
        ]);
      });
}

// =====================================================================================
// GEO DASH — neon geometry: pulsing parallax tiles, tiled glowing floor, a spinning cube
// with a square trail, glowing spikes and buzzing saw blades, shard explosion on death.
// =====================================================================================
class DashBoard extends SoloBoard {
  const DashBoard({super.key, required super.run});
  @override
  DashBoardState createState() => DashBoardState();
}

class DashBoardState extends SoloBoardState<DashBoard> {
  late DashWorld world;
  bool _holding = false;
  double _scroll = 0;
  double _rot = 0;
  bool _wasGround = true;
  bool _dead = false;
  final List<Offset> _trail = <Offset>[];

  static const double _playerX = 0.22;

  @override
  void reset() {
    world = DashWorld(seed: widget.run.seed);
    _holding = false;
    _scroll = 0;
    _rot = 0;
    _dead = false;
    _trail.clear();
    widget.run.set(0);
  }

  double _ground(Size s) => s.height * 0.70;
  double _ceil(Size s) => s.height * 0.24;
  Offset _player(Size s) => Offset(_playerX * s.width, _ground(s) - world.y * (_ground(s) - _ceil(s)) - 16);

  @override
  void step(double dt) {
    world.update(dt, holding: _holding);
    final Size s = lastSize;
    _scroll += world.speed * dt * 2.2 * (s.width == 0 ? 400 : s.width);
    if (world.onGround) {
      final double target = (_rot / (math.pi / 2)).roundToDouble() * (math.pi / 2);
      _rot = LuxeBoardPainter.lerp(_rot, target, 1 - math.pow(0.0001, dt).toDouble());
      if (!_wasGround && s != Size.zero) {
        fx.burst(_player(s) + const Offset(0, 16), const Color(0xFFB8F05A), count: 8, speed: 140, life: 0.3, size: 3,
            spread: math.pi * 0.8, direction: -math.pi / 2);
      }
    } else {
      _rot += dt * (_holding ? 4.5 : 7.5);
    }
    _wasGround = world.onGround;
    if (s != Size.zero) {
      _trail.insert(0, _player(s));
      if (_trail.length > 10) _trail.removeLast();
    }
    widget.run.set(world.metres);
    if (world.dead && !_dead) {
      _dead = true;
      final Offset p = _player(s);
      fx.burst(p, const Color(0xFFB8F05A), count: 26, speed: 420, life: 1.0, size: 9, kind: ParticleKind.shard, gravity: 700);
      fx.burst(p, Colors.white, count: 20, speed: 520, life: 0.5, size: 4);
      fx.ring(p, const Color(0xFFB8F05A), size: 20, life: 0.5);
      fx.shake(16);
      fx.flashScreen(Colors.white, 0.5);
    }
    if (world.dead) widget.run.gameOver();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = clock;
    final double ground = _ground(size);
    final double ceil = _ceil(size);
    final double h = ground - ceil;
    final double beat = math.pow(math.max(0, math.sin(t * math.pi * 2.2)), 6).toDouble();
    final double hue = 200 + world.distance * 1.2;
    final Color main = SoloArt.hue(hue, s: 0.8, l: 0.5);

    SoloArt.sky(canvas, Offset.zero & size, <Color>[SoloArt.hue(hue, s: 0.7, l: 0.22), SoloArt.hue(hue + 40, s: 0.7, l: 0.08)]);
    // Parallax square silhouettes.
    for (int layer = 0; layer < 2; layer++) {
      final double sp = layer == 0 ? 0.15 : 0.35;
      final double sz = layer == 0 ? 70 : 46;
      final math.Random r = math.Random(layer + 3);
      for (int i = 0; i < 14; i++) {
        final double x = ((r.nextDouble() * size.width * 1.6 - _scroll * sp) % (size.width * 1.6) + size.width * 1.6) % (size.width * 1.6) - 80;
        final double y = ceil + r.nextDouble() * h * 0.9;
        final double s0 = sz * (0.5 + r.nextDouble()) * (1 + beat * 0.06);
        final Rect q = Rect.fromCenter(center: Offset(x, y), width: s0, height: s0);
        canvas.drawRect(q, Paint()..color = Colors.white.withValues(alpha: layer == 0 ? 0.035 : 0.05));
        canvas.drawRect(q, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.07 + beat * 0.06));
      }
    }
    SoloArt.paintBloom(canvas, Offset(size.width * 0.7, ceil + h * 0.4), size.width * 0.6, main, 0.12 + beat * 0.1);

    // Floor and ceiling made of tiles.
    _tiles(canvas, Rect.fromLTRB(0, ground, size.width, size.height), main, true);
    _tiles(canvas, Rect.fromLTRB(0, 0, size.width, ceil), main, false);
    SoloArt.neonLine(canvas, Offset(0, ground), Offset(size.width, ground), Colors.white, width: 2, glow: 10 + beat * 8);
    SoloArt.neonLine(canvas, Offset(0, ceil), Offset(size.width, ceil), Colors.white, width: 1.4, glow: 8, alpha: 0.7);

    // Hazards.
    for (final DashHazard z in world.hazards) {
      final double x = z.x * size.width;
      if (z.flying) {
        final double y = ground - z.height * h;
        _saw(canvas, Offset(x, y), 17, t);
      } else {
        final double sh = z.height * h;
        for (final double dx in <double>[0]) {
          final Path spike = Path()
            ..moveTo(x - 18 + dx, ground)
            ..lineTo(x + dx, ground - sh)
            ..lineTo(x + 18 + dx, ground)
            ..close();
          canvas.drawPath(spike, Paint()
            ..shader = ui.Gradient.linear(Offset(x, ground - sh), Offset(x, ground), const <Color>[Color(0xFF3A3A48), Color(0xFF0C0C12)]));
          SoloArt.neonPath(canvas, spike, const Color(0xFFFF4A6A), width: 1.6, glow: 8);
          SoloArt.paintBloom(canvas, Offset(x, ground - sh), 12, const Color(0xFFFF4A6A), 0.5);
        }
      }
    }

    // Trail + cube.
    if (!world.dead) {
      for (int i = _trail.length - 1; i >= 1; i--) {
        final double k = 1 - i / _trail.length;
        final Offset p = _trail[i] - Offset(i * 7.0, 0);
        canvas.drawRect(Rect.fromCenter(center: p, width: 18 * k, height: 18 * k), Paint()..color = const Color(0xFFB8F05A).withValues(alpha: 0.35 * k));
      }
      final Offset p = _player(size);
      paintShadow(canvas, Offset(p.dx, ground + 3), 30 * (1 - world.y * 0.6), 6, 0.45);
      SoloArt.paintBloom(canvas, p, 36, const Color(0xFFB8F05A), 0.35);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(_rot);
      const Rect outer = Rect.fromLTWH(-16, -16, 32, 32);
      canvas.drawRect(outer, Paint()
        ..shader = ui.Gradient.linear(outer.topLeft, outer.bottomRight, const <Color>[Color(0xFFE6FF9A), Color(0xFF7AC21E)]));
      canvas.drawRect(outer, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF16220A));
      canvas.drawRect(const Rect.fromLTWH(-9, -9, 18, 18), Paint()..color = const Color(0xFF00E5FF));
      canvas.drawRect(const Rect.fromLTWH(-9, -9, 18, 18), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF16220A));
      canvas.drawRect(const Rect.fromLTWH(-5, -4, 3, 4), Paint()..color = const Color(0xFF16220A));
      canvas.drawRect(const Rect.fromLTWH(2, -4, 3, 4), Paint()..color = const Color(0xFF16220A));
      canvas.drawRect(const Rect.fromLTWH(-5, 3, 10, 2), Paint()..color = const Color(0xFF16220A));
      canvas.restore();
    }

    SoloArt.bigLabel(canvas, '${world.metres} m', Offset(size.width / 2, ceil - 46), size: 30, color: Colors.white, glow: main);
    paintVignette(canvas, size, 0.45);
  }

  void _tiles(Canvas canvas, Rect area, Color main, bool floor) {
    canvas.drawRect(area, Paint()
      ..shader = ui.Gradient.linear(area.topCenter, area.bottomCenter,
          floor ? <Color>[SoloArt.tone(main, -0.1), SoloArt.tone(main, -0.38)] : <Color>[SoloArt.tone(main, -0.38), SoloArt.tone(main, -0.12)]));
    const double ts = 44;
    final double off = _scroll % ts;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.black.withValues(alpha: 0.35);
    final Paint hi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.12);
    for (double x = -off; x < area.right; x += ts) {
      for (double y = floor ? area.top : area.bottom - ts; floor ? y < area.bottom : y > area.top - ts; y += floor ? ts : -ts) {
        final Rect q = Rect.fromLTWH(x + 3, y + 3, ts - 6, ts - 6);
        canvas.drawRect(q, line);
        canvas.drawLine(q.topLeft, q.topRight, hi);
      }
    }
  }

  void _saw(Canvas canvas, Offset c, double r, double t) {
    SoloArt.paintBloom(canvas, c, r * 2.2, const Color(0xFFFF4A6A), 0.3);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-t * 9);
    final Path teeth = Path();
    const int n = 12;
    for (int i = 0; i < n * 2; i++) {
      final double a = i * math.pi / n;
      final double rr = i.isEven ? r : r * 0.74;
      final Offset p = Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        teeth.moveTo(p.dx, p.dy);
      } else {
        teeth.lineTo(p.dx, p.dy);
      }
    }
    teeth.close();
    canvas.drawPath(teeth, Paint()..shader = ui.Gradient.radial(Offset.zero, r, const <Color>[Color(0xFFE8ECF5), Color(0xFF8790A6)]));
    canvas.drawCircle(Offset.zero, r * 0.45, Paint()..color = const Color(0xFFFF4A6A));
    canvas.drawCircle(Offset.zero, r * 0.18, Paint()..color = const Color(0xFF1A1A22));
    for (int i = 0; i < 3; i++) {
      final double a = i * math.pi * 2 / 3;
      canvas.drawLine(Offset.zero, Offset(math.cos(a), math.sin(a)) * r * 0.42, Paint()
        ..color = const Color(0xFF1A1A22)
        ..strokeWidth = 2);
    }
    canvas.restore();
  }

  void _press() {
    _holding = true;
    if (world.onGround && lastSize != Size.zero) {
      fx.ring(_player(lastSize) + const Offset(0, 16), const Color(0xFFB8F05A), size: 12, life: 0.3);
    }
    world.leap();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _press(),
          onTapUp: (_) => _holding = false,
          onTapCancel: () => _holding = false,
          child: super.build(context),
        ),
        Positioned(
          right: 20,
          bottom: 30,
          child: SoloPad(
            icon: Icons.arrow_upward_rounded,
            size: 80,
            accent: const Color(0xFFB8F05A),
            onTap: () {},
            onHold: _press,
            onRelease: () => _holding = false,
          ),
        ),
      ]);
}

// =====================================================================================
// TRAFFIC RACER — night highway: speckled asphalt, street lamps casting light pools,
// guard rails with reflectors, detailed top-down cars with lights, headlight beams,
// near-miss callouts and a crash with sparks and smoke.
// =====================================================================================
class TrafficBoard extends SoloBoard {
  const TrafficBoard({super.key, required super.run});
  @override
  TrafficBoardState createState() => TrafficBoardState();
}

class TrafficBoardState extends SoloBoardState<TrafficBoard> {
  late TrafficWorld world;
  double _laneX = 1;
  double _scroll = 0;
  bool _crashed = false;
  final Expando<int> _paint = Expando<int>();
  final Set<TrafficCar> _passed = <TrafficCar>{};
  final math.Random _rng = math.Random(8);

  static const List<Color> _carColours = <Color>[
    Color(0xFFE23B4E),
    Color(0xFF2F7DFF),
    Color(0xFFF2F2F5),
    Color(0xFFFFC21F),
    Color(0xFF1FBF8F),
    Color(0xFF2A2D38),
    Color(0xFFB04BFF),
  ];

  @override
  void reset() {
    world = TrafficWorld(seed: widget.run.seed);
    _laneX = 1;
    _scroll = 0;
    _crashed = false;
    _passed.clear();
    widget.run.set(0);
  }

  double _carY(Size s, double y) => s.height * (0.80 - (y - 0.13) * 0.85);
  double _roadL(Size s) => s.width * 0.11;
  double _roadR(Size s) => s.width * 0.89;
  double _laneW(Size s) => (_roadR(s) - _roadL(s)) / 3;
  double _laneCentre(Size s, double lane) => _roadL(s) + _laneW(s) * (lane + 0.5);

  @override
  void step(double dt) {
    world.update(dt);
    final Size s = lastSize;
    _scroll += world.speed * 1.5 * dt * (s.height == 0 ? 800 : s.height) * 1.5;
    _laneX = LuxeBoardPainter.lerp(_laneX, world.lane.toDouble(), 1 - math.pow(0.0005, dt).toDouble());
    for (final TrafficCar c in world.cars) {
      if (c.passed && !_passed.contains(c)) {
        _passed.add(c);
        if ((c.lane - world.lane).abs() == 1 && s != Size.zero) {
          fx.text('NEAR MISS', Offset(_laneCentre(s, c.lane.toDouble()), s.height * 0.66), const Color(0xFF5CF2FF), size: 16);
        }
      }
    }
    _passed.removeWhere((TrafficCar c) => !world.cars.contains(c));
    widget.run.set(world.metres);
    if (world.crashed && !_crashed) {
      _crashed = true;
      final Offset p = Offset(_laneCentre(s, _laneX), s.height * 0.80 - 40);
      fx.burst(p, const Color(0xFFFFD36B), count: 50, speed: 560, life: 0.8, size: 4, gravity: 300);
      fx.burst(p, const Color(0xFFFF6A2E), count: 18, speed: 240, life: 0.7, size: 9, kind: ParticleKind.orb);
      fx.burst(p, const Color(0xFF4A4A55), count: 16, speed: 80, life: 1.6, size: 20, kind: ParticleKind.smoke, gravity: -60);
      fx.burst(p, const Color(0xFFBFD8FF), count: 14, speed: 360, life: 0.9, size: 6, kind: ParticleKind.shard, gravity: 500);
      fx.shake(20);
      fx.flashScreen(const Color(0xFFFF3B3B), 0.45);
    }
    if (world.crashed) widget.run.gameOver();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double l = _roadL(size);
    final double r = _roadR(size);
    final double lw = _laneW(size);
    // Verge.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0B1410));
    final math.Random g = math.Random(1);
    final double vOff = _scroll % 240;
    for (int i = 0; i < 60; i++) {
      final double x = g.nextBool() ? g.nextDouble() * l : r + g.nextDouble() * (size.width - r);
      final double y = (g.nextDouble() * (size.height + 240) + vOff) % (size.height + 240) - 120;
      canvas.drawCircle(Offset(x, y), 2 + g.nextDouble() * 5, Paint()..color = const Color(0xFF16301F).withValues(alpha: 0.9));
    }
    // Asphalt with speckle texture.
    final Rect road = Rect.fromLTRB(l, 0, r, size.height);
    canvas.drawRect(road, Paint()
      ..shader = ui.Gradient.linear(road.centerLeft, road.centerRight, const <Color>[Color(0xFF15161B), Color(0xFF22232A), Color(0xFF15161B)], <double>[0.0, 0.5, 1.0]));
    final math.Random sp = math.Random(4);
    const double tile = 260;
    final double off = _scroll % tile;
    final Paint speck = Paint();
    for (int i = 0; i < 140; i++) {
      final double x = l + sp.nextDouble() * (r - l);
      final double y0 = sp.nextDouble() * tile;
      speck.color = Colors.white.withValues(alpha: 0.03 + sp.nextDouble() * 0.05);
      for (double y = y0 + off - tile; y < size.height; y += tile) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1.6, 1.6), speck);
      }
    }
    // Tyre wear lines.
    for (int lane = 0; lane < 3; lane++) {
      for (final double f in <double>[0.3, 0.7]) {
        final double x = l + lw * (lane + f);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..strokeWidth = 7);
      }
    }
    // Edge lines + lane dashes.
    for (final double x in <double>[l + 6, r - 6]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()
        ..color = const Color(0xFFE8E2C8)
        ..strokeWidth = 3);
    }
    final double dOff = _scroll % 90;
    for (int k = -1; k < size.height / 90 + 1; k++) {
      final double y = k * 90 + dOff;
      for (int i = 1; i < 3; i++) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(l + lw * i, y), width: 4, height: 44), const Radius.circular(2)),
            Paint()..color = const Color(0xFFF2EEDD).withValues(alpha: 0.85));
      }
    }
    // Guard rails with reflectors.
    for (final double x in <double>[l - 6, r + 2]) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 4, size.height), Paint()
        ..shader = ui.Gradient.linear(Offset(x, 0), Offset(x + 4, 0), const <Color>[Color(0xFF6C7488), Color(0xFFD5DBEA), Color(0xFF5A6276)], <double>[0.0, 0.5, 1.0]));
      final double rOff = _scroll % 60;
      for (double y = rOff - 60; y < size.height; y += 60) {
        canvas.drawRect(Rect.fromLTWH(x - 1, y, 6, 6), Paint()..color = const Color(0xFFFFB13B));
        SoloArt.paintBloom(canvas, Offset(x + 2, y + 3), 7, const Color(0xFFFFB13B), 0.35);
      }
    }
    // Street lamps: light pools on the road + lamp heads.
    final double lampGap = size.height * 0.55;
    final double lOff = _scroll % lampGap;
    for (double y = lOff - lampGap; y < size.height + lampGap; y += lampGap) {
      for (final int side in <int>[-1, 1]) {
        final double yy = y + (side > 0 ? lampGap / 2 : 0);
        final Offset head = Offset(side < 0 ? l + 18 : r - 18, yy);
        canvas.drawCircle(head + Offset(side * -lw * 0.4, 0), lw * 1.1, Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(head + Offset(side * -lw * 0.4, 0), lw * 1.1,
              const <Color>[Color(0x33FFD9A0), Color(0x00FFD9A0)]));
        canvas.drawLine(Offset(side < 0 ? l - 14 : r + 14, yy), head, Paint()
          ..color = const Color(0xFF3A3F4E)
          ..strokeWidth = 4);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: head, width: 14, height: 8), const Radius.circular(3)),
            Paint()..color = const Color(0xFFFFF3D6));
        SoloArt.paintBloom(canvas, head, 16, const Color(0xFFFFD9A0), 0.6);
      }
    }

    // Traffic.
    final double carW = lw * 0.56;
    for (final TrafficCar c in world.cars) {
      final double y = _carY(size, c.y);
      if (y < -120 || y > size.height + 120) continue;
      final int colour = _paint[c] ??= _rng.nextInt(_carColours.length);
      _car(canvas, Offset(_laneCentre(size, c.lane.toDouble()), y), carW, carW * 1.95, _carColours[colour], player: false, seed: colour);
    }

    // Player.
    if (!world.crashed) {
      final Offset p = Offset(_laneCentre(size, _laneX), size.height * 0.80);
      final double tilt = (world.lane - _laneX).clamp(-1.0, 1.0) * 0.22;
      // Headlight beams.
      final Path beam = Path()
        ..moveTo(p.dx - carW * 0.3, p.dy - carW)
        ..lineTo(p.dx - carW * 1.1, p.dy - carW * 5)
        ..lineTo(p.dx + carW * 1.1, p.dy - carW * 5)
        ..lineTo(p.dx + carW * 0.3, p.dy - carW)
        ..close();
      canvas.drawPath(beam, Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(Offset(p.dx, p.dy - carW), Offset(p.dx, p.dy - carW * 5), const <Color>[Color(0x55FFF6D8), Color(0x00FFF6D8)]));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(tilt);
      _car(canvas, Offset.zero, carW * 1.04, carW * 2.05, const Color(0xFF00D2FF), player: true, seed: 0);
      // Exhaust flames.
      final double fl = 0.6 + 0.4 * math.sin(clock * 50);
      for (final double dx in <double>[-carW * 0.22, carW * 0.22]) {
        SoloArt.paintBloom(canvas, Offset(dx, carW * 1.08 + 6 * fl), 10 * fl, const Color(0xFF5CC8FF), 0.8);
      }
      canvas.restore();
    }

    SoloArt.bigLabel(canvas, '${world.metres}', Offset(size.width / 2, 66), size: 32, color: Colors.white, glow: const Color(0xFF00D2FF));
    // Speed gauge arc.
    final double kmh = world.speed * 90;
    final Offset gc = Offset(size.width / 2, 120);
    canvas.drawArc(Rect.fromCircle(center: gc, radius: 26), math.pi * 0.8, math.pi * 1.4, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x33FFFFFF));
    canvas.drawArc(Rect.fromCircle(center: gc, radius: 26), math.pi * 0.8, math.pi * 1.4 * (kmh / 216).clamp(0.0, 1.0), false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.sweep(gc, const <Color>[Color(0xFF00D2FF), Color(0xFFFF3B6B)]));
    LuxeBoardPainter.text(canvas, '${kmh.round()}', gc, color: Colors.white, size: 13);
    LuxeBoardPainter.text(canvas, 'km/h', gc + const Offset(0, 16), color: const Color(0xFF9FB3CC), size: 9, weight: FontWeight.w600);
    paintVignette(canvas, size, 0.55);
  }

  void _car(Canvas canvas, Offset c, double w, double h, Color body, {required bool player, required int seed}) {
    final Rect r = Rect.fromCenter(center: c, width: w, height: h);
    // Shadow.
    canvas.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(4, 8)).inflate(2), Radius.circular(w * 0.3)), Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // Wheels.
    final Paint tyre = Paint()..color = const Color(0xFF0A0A0C);
    for (final double fy in <double>[0.2, 0.78]) {
      for (final double fx0 in <double>[-0.02, 0.86]) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left + w * fx0 - w * 0.06, r.top + h * fy - h * 0.08, w * 0.22, h * 0.16),
            const Radius.circular(3)), tyre);
      }
    }
    // Body: tapered nose + tail.
    final Path b = Path()
      ..moveTo(r.left + w * 0.18, r.top)
      ..quadraticBezierTo(c.dx, r.top - h * 0.03, r.right - w * 0.18, r.top)
      ..quadraticBezierTo(r.right, r.top + h * 0.04, r.right, r.top + h * 0.2)
      ..lineTo(r.right - w * 0.02, r.bottom - h * 0.12)
      ..quadraticBezierTo(r.right - w * 0.04, r.bottom, r.right - w * 0.2, r.bottom)
      ..lineTo(r.left + w * 0.2, r.bottom)
      ..quadraticBezierTo(r.left + w * 0.04, r.bottom, r.left + w * 0.02, r.bottom - h * 0.12)
      ..lineTo(r.left, r.top + h * 0.2)
      ..quadraticBezierTo(r.left, r.top + h * 0.04, r.left + w * 0.18, r.top)
      ..close();
    canvas.drawPath(b, Paint()
      ..shader = ui.Gradient.linear(r.centerLeft, r.centerRight,
          <Color>[SoloArt.tone(body, -0.22), SoloArt.tone(body, 0.12), body, SoloArt.tone(body, -0.25)], <double>[0, 0.35, 0.65, 1]));
    // Hood crease lines.
    canvas.drawLine(Offset(c.dx - w * 0.18, r.top + h * 0.05), Offset(c.dx - w * 0.14, r.top + h * 0.24), Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..strokeWidth = 1);
    canvas.drawLine(Offset(c.dx + w * 0.18, r.top + h * 0.05), Offset(c.dx + w * 0.14, r.top + h * 0.24), Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..strokeWidth = 1);
    // Windshield, roof, rear window.
    final Path glass = Path()
      ..moveTo(r.left + w * 0.14, r.top + h * 0.30)
      ..quadraticBezierTo(c.dx, r.top + h * 0.22, r.right - w * 0.14, r.top + h * 0.30)
      ..lineTo(r.right - w * 0.2, r.top + h * 0.42)
      ..lineTo(r.left + w * 0.2, r.top + h * 0.42)
      ..close();
    canvas.drawPath(glass, Paint()
      ..shader = ui.Gradient.linear(Offset(c.dx, r.top + h * 0.22), Offset(c.dx, r.top + h * 0.42), const <Color>[Color(0xFF9FC3E8), Color(0xFF1A2638)]));
    canvas.drawLine(Offset(r.left + w * 0.3, r.top + h * 0.3), Offset(r.left + w * 0.42, r.top + h * 0.38), Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5);
    final Rect roof = Rect.fromLTRB(r.left + w * 0.2, r.top + h * 0.42, r.right - w * 0.2, r.top + h * 0.7);
    canvas.drawRRect(RRect.fromRectAndRadius(roof, Radius.circular(w * 0.1)), Paint()
      ..shader = ui.Gradient.linear(roof.centerLeft, roof.centerRight, <Color>[SoloArt.tone(body, -0.1), SoloArt.tone(body, 0.06), SoloArt.tone(body, -0.14)], <double>[0.0, 0.5, 1.0]));
    final Path rear = Path()
      ..moveTo(r.left + w * 0.2, r.top + h * 0.7)
      ..lineTo(r.right - w * 0.2, r.top + h * 0.7)
      ..lineTo(r.right - w * 0.16, r.top + h * 0.8)
      ..quadraticBezierTo(c.dx, r.top + h * 0.84, r.left + w * 0.16, r.top + h * 0.8)
      ..close();
    canvas.drawPath(rear, Paint()..color = const Color(0xFF16202E));
    // Mirrors.
    for (final int side in <int>[-1, 1]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + side * w * 0.53, r.top + h * 0.34), width: w * 0.14, height: h * 0.05),
          Paint()..color = SoloArt.tone(body, -0.15));
    }
    if (player) {
      // Racing stripes.
      for (final double dx in <double>[-w * 0.07, w * 0.07]) {
        canvas.drawRect(Rect.fromCenter(center: Offset(c.dx + dx, r.top + h * 0.14), width: w * 0.06, height: h * 0.2), Paint()..color = Colors.white);
        canvas.drawRect(Rect.fromCenter(center: Offset(c.dx + dx, r.top + h * 0.56), width: w * 0.06, height: h * 0.24),
            Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
      // Spoiler.
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(r.left + w * 0.04, r.bottom - h * 0.07, r.right - w * 0.04, r.bottom - h * 0.01),
          const Radius.circular(2)), Paint()..color = const Color(0xFF0E1A26));
    }
    // Lights: headlights at the front (top), tail lights at the back (bottom).
    for (final int side in <int>[-1, 1]) {
      final Offset hl = Offset(c.dx + side * w * 0.3, r.top + h * 0.03);
      canvas.drawOval(Rect.fromCenter(center: hl, width: w * 0.2, height: h * 0.035), Paint()..color = const Color(0xFFFFF6D8));
      if (player) SoloArt.paintBloom(canvas, hl, w * 0.3, const Color(0xFFFFF6D8), 0.7);
      final Offset tl = Offset(c.dx + side * w * 0.3, r.bottom - h * 0.03);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: tl, width: w * 0.24, height: h * 0.03), const Radius.circular(2)),
          Paint()..color = const Color(0xFFFF2E3E));
      SoloArt.paintBloom(canvas, tl, w * (player ? 0.28 : 0.4), const Color(0xFFFF2E3E), player ? 0.45 : 0.6);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (DragEndDetails d) {
            if (d.primaryVelocity != null) setState(() => world.steer(d.primaryVelocity! < 0 ? -1 : 1));
          },
          child: super.build(context),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 26,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
            SoloPad(icon: Icons.chevron_left_rounded, onTap: () => setState(() => world.steer(-1)), size: 66, accent: const Color(0xFF00D2FF)),
            SoloPad(icon: Icons.chevron_right_rounded, onTap: () => setState(() => world.steer(1)), size: 66, accent: const Color(0xFF00D2FF)),
          ]),
        ),
      ]);
}
