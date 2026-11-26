import 'dart:math' as math;
import 'dart:ui';

/// World-space particles of Gate Shooter: they live on the road (x, z, height y), scroll with it and are projected
/// every frame, so an explosion stays glued to the asphalt while the squad runs past it.
enum GsPk { fire, smoke, spark, debris, ring, flash, dust, ember }

class GsPart {
  GsPart(this.kind, this.x, this.y, this.z, this.vx, this.vy, this.vz, this.life, this.size, this.color, {this.rot = 0, this.vr = 0, this.w = 1})
      : max = life;
  final GsPk kind;
  double x, y, z, vx, vy, vz;
  double life;
  final double max;
  double size;
  final Color color;
  double rot, vr;
  final double w; // debris aspect
  int bounces = 0;
}

/// Screen-space floating caption (gate result, coin gain, damage).
class GsPop {
  GsPop(this.text, this.x, this.y, this.color, {this.size = 26, this.life = 1.0, this.vy = -70}) : max = life;
  final String text;
  double x, y;
  final Color color;
  final double size;
  double life;
  final double max;
  final double vy;
}

/// Coin flying from a kill to the coin counter.
class GsCoinFly {
  GsCoinFly(this.from, this.to, this.delay, [this.value = 1]) : ctrl = Offset((from.dx + to.dx) / 2 + (from.dx - to.dx) * 0.3, math.min(from.dy, to.dy) - 60);
  final Offset from, to, ctrl;
  final int value;
  double t = 0;
  double delay;
}

class GsParticles {
  GsParticles({this.enabled = true});
  bool enabled;
  final List<GsPart> parts = <GsPart>[];
  final math.Random r = math.Random(11);

  double _rn(double a, double b) => a + r.nextDouble() * (b - a);

  void add(GsPart p) {
    if (!enabled && p.kind != GsPk.flash) return;
    parts.add(p);
    if (parts.length > 700) parts.removeRange(0, parts.length - 700);
  }

  /// Barrel explosion: flash, fireball, sparks, metal shards, smoke column and a ground shock ring.
  void explosion(double x, double z, {double scale = 1, Color debris = const Color(0xFFD8322A)}) {
    add(GsPart(GsPk.flash, x, 1.0, z, 0, 0, 0, 0.18, 3.2 * scale, const Color(0xFFFFF4C8)));
    add(GsPart(GsPk.ring, x, 0.05, z, 0, 0, 0, 0.55, 0.6 * scale, const Color(0xFFFFD27A)));
    final int nf = (16 * scale).round();
    for (int i = 0; i < nf; i++) {
      final double a = r.nextDouble() * math.pi * 2;
      final double sp = _rn(1.5, 5.5) * scale;
      add(GsPart(GsPk.fire, x + _rn(-0.3, 0.3), _rn(0.4, 1.6), z, math.cos(a) * sp, _rn(1.5, 5) * scale, math.sin(a) * sp * 0.6,
          _rn(0.35, 0.75), _rn(0.6, 1.3) * scale, i.isEven ? const Color(0xFFFFB238) : const Color(0xFFFF6A1E)));
    }
    for (int i = 0; i < (18 * scale).round(); i++) {
      final double a = r.nextDouble() * math.pi * 2;
      final double sp = _rn(6, 14);
      add(GsPart(GsPk.spark, x, _rn(0.5, 1.5), z, math.cos(a) * sp, _rn(2, 9), math.sin(a) * sp * 0.7, _rn(0.25, 0.6), 0.09,
          const Color(0xFFFFE08A)));
    }
    for (int i = 0; i < (10 * scale).round(); i++) {
      final double a = r.nextDouble() * math.pi * 2;
      final double sp = _rn(2.5, 7);
      add(GsPart(GsPk.debris, x, _rn(0.6, 1.6), z, math.cos(a) * sp, _rn(5, 11), math.sin(a) * sp * 0.6, _rn(0.9, 1.5), _rn(0.16, 0.34),
          i % 3 == 0 ? const Color(0xFF3A3A40) : debris, rot: r.nextDouble() * 6, vr: _rn(-14, 14), w: _rn(0.5, 1.6)));
    }
    for (int i = 0; i < (9 * scale).round(); i++) {
      add(GsPart(GsPk.smoke, x + _rn(-0.6, 0.6), _rn(0.8, 2.2), z + _rn(-0.4, 0.4), _rn(-0.6, 0.6), _rn(1.2, 2.6), _rn(-0.2, 0.4),
          _rn(1.0, 1.8), _rn(0.7, 1.2) * scale, const Color(0xFF4A3F3A)));
    }
    for (int i = 0; i < 6; i++) {
      add(GsPart(GsPk.ember, x, _rn(0.5, 2), z, _rn(-2, 2), _rn(3, 7), _rn(-1, 1), _rn(1.0, 1.8), 0.06, const Color(0xFFFF9A3A)));
    }
  }

  /// Wooden crate breaking: splinters + planks + dust.
  void smash(double x, double z) {
    add(GsPart(GsPk.flash, x, 1.0, z, 0, 0, 0, 0.12, 1.8, const Color(0xFFFFF1D0)));
    for (int i = 0; i < 14; i++) {
      final double a = r.nextDouble() * math.pi * 2;
      final double sp = _rn(2, 6.5);
      add(GsPart(GsPk.debris, x + _rn(-0.4, 0.4), _rn(0.4, 1.6), z, math.cos(a) * sp, _rn(3.5, 9), math.sin(a) * sp * 0.6, _rn(0.9, 1.5),
          _rn(0.2, 0.42), i.isEven ? const Color(0xFF9C6A38) : const Color(0xFF7A4E27), rot: r.nextDouble() * 6, vr: _rn(-12, 12), w: _rn(2.2, 3.6)));
    }
    for (int i = 0; i < 8; i++) {
      add(GsPart(GsPk.dust, x + _rn(-0.5, 0.5), _rn(0.2, 1), z, _rn(-1.5, 1.5), _rn(0.3, 1.4), _rn(-0.5, 0.5), _rn(0.6, 1.1), _rn(0.5, 0.9),
          const Color(0xFFE4C796)));
    }
  }

  /// Small burst where a bullet lands.
  void impact(double x, double y, double z, Color c) {
    for (int i = 0; i < 4; i++) {
      final double a = r.nextDouble() * math.pi * 2;
      add(GsPart(GsPk.spark, x, y + _rn(-0.2, 0.3), z - 0.3, math.cos(a) * _rn(2, 5), _rn(0, 4), -_rn(1, 4), _rn(0.12, 0.25), 0.06, c));
    }
  }

  /// Enemy or soldier knocked out: dust poof + a few coloured bits.
  void poof(double x, double z, Color c, {double scale = 1}) {
    for (int i = 0; i < 7; i++) {
      add(GsPart(GsPk.dust, x + _rn(-0.3, 0.3), _rn(0.3, 1.2) * scale, z, _rn(-2, 2), _rn(0.5, 2.2), _rn(-1, 1), _rn(0.45, 0.8),
          _rn(0.35, 0.65) * scale, const Color(0xFFF2E6CF)));
    }
    for (int i = 0; i < 6; i++) {
      final double a = r.nextDouble() * math.pi * 2;
      add(GsPart(GsPk.debris, x, _rn(0.6, 1.4) * scale, z, math.cos(a) * _rn(1.5, 4), _rn(3, 7), math.sin(a) * 2, _rn(0.6, 1.0), 0.13 * scale,
          c, rot: r.nextDouble() * 6, vr: _rn(-15, 15)));
    }
  }

  /// Running dust kicked up behind the squad.
  void kick(double x, double z) {
    add(GsPart(GsPk.dust, x + _rn(-0.2, 0.2), 0.1, z - 0.2, _rn(-0.4, 0.4), _rn(0.2, 0.7), -_rn(0.5, 1.5), _rn(0.35, 0.6), _rn(0.18, 0.32),
        const Color(0xFFD9D4CB)));
  }

  void update(double dt, double scroll) {
    for (int i = parts.length - 1; i >= 0; i--) {
      final GsPart p = parts[i];
      p.life -= dt;
      if (p.life <= 0) {
        parts.removeAt(i);
        continue;
      }
      p.z -= scroll;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.z += p.vz * dt;
      p.rot += p.vr * dt;
      switch (p.kind) {
        case GsPk.debris:
        case GsPk.spark:
          p.vy -= 22 * dt;
          if (p.y < 0.02) {
            p.y = 0.02;
            if (p.bounces < 2 && p.vy < -1.5) {
              p.vy = -p.vy * 0.35;
              p.vx *= 0.55;
              p.vz *= 0.55;
              p.vr *= 0.5;
              p.bounces++;
            } else {
              p.vy = 0;
              p.vx *= 0.8;
              p.vz *= 0.8;
              p.vr *= 0.8;
            }
          }
        case GsPk.fire:
          final double d = math.pow(0.05, dt).toDouble();
          p.vx *= d;
          p.vz *= d;
          p.vy = p.vy * d + 1.5 * dt;
          p.size += dt * 1.4;
        case GsPk.smoke:
        case GsPk.dust:
          final double d = math.pow(0.3, dt).toDouble();
          p.vx *= d;
          p.vz *= d;
          p.vy *= d;
          p.size += dt * (p.kind == GsPk.smoke ? 1.3 : 0.9);
        case GsPk.ember:
          p.vy -= 3 * dt;
          p.vx += math.sin(p.life * 9) * dt * 3;
        case GsPk.ring:
          p.size += dt * 9;
        case GsPk.flash:
          break;
      }
    }
  }
}
